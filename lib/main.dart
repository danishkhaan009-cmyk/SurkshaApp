import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'package:floating_bottom_navigation_bar/floating_bottom_navigation_bar.dart';
import 'index.dart';
import '/services/location_tracking_service.dart';
import '/services/child_mode_service.dart';
import '/services/rules_enforcement_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // Run FlutterFlow theme initialization and Supabase in parallel for faster startup
  await Future.wait([
    FlutterFlowTheme.initialize(),
    Supabase.initialize(
      url: 'https://myxdypywnifdsaorlhsy.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce, // Modern standard for better persistence
        autoRefreshToken: true,        // Automatically keeps the session alive
      ),
    ),
  ]);

  // Initialize location tracking service (will restore if it was active before)
  try {
    await LocationTrackingService().initialize();
    print('✅ Location tracking service initialized');
  } catch (e) {
    print('⚠️ Location tracking initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;

  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);

    // Initialize background monitoring if in child mode
    _initializeBackgroundServices();
  }

  Future<void> _initializeBackgroundServices() async {
    try {
      final isChildMode = await ChildModeService.isChildModeActive();
      final deviceId = await ChildModeService.getChildDeviceId();

      if (isChildMode && deviceId != null && deviceId.isNotEmpty) {
        print('✅ Child device detected: $deviceId - Resuming background monitoring');
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted) {
            await RulesEnforcementService.initialize(context);
            print('✅ Rules enforcement initialized after app restart');
          }
        });
      } else {
        print('📱 Parent device or no child mode active');
      }
    } catch (e) {
      print('⚠️ Failed to initialize background services: $e');
    }
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'without-database',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

class NavBarPage extends StatefulWidget {
  const NavBarPage({
    super.key,
    this.initialPage,
    this.page,
    this.disableResizeToAvoidBottomInset = false,
  });

  final String? initialPage;
  final Widget? page;
  final bool disableResizeToAvoidBottomInset;

  @override
  _NavBarPageState createState() => _NavBarPageState();
}

class _NavBarPageState extends State<NavBarPage> {
  String _currentPageName = 'Parent_Dashboard';
  late Widget? _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'Parent_Dashboard': const ParentDashboardWidget(),
      'Alert': const AlertWidget(),
      'Subscription': const SubscriptionWidget(),
      'Settings': const SettingsWidget(),
      'Self_mode': const SelfModeWidget(),
    };
    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

    return Scaffold(
      body: _currentPage ?? tabs[_currentPageName]!,
      extendBody: true,
      bottomNavigationBar: FloatingNavbar(
        currentIndex: currentIndex == 4 ? 0 : currentIndex,
        onTap: (i) => safeSetState(() {
          _currentPage = null;
          // If we are in Self_mode, Home click (i=0) should stay in Self_mode
          if (_currentPageName == 'Self_mode' && i == 0) {
            _currentPageName = 'Self_mode';
          } else {
            _currentPageName = tabs.keys.toList()[i];
          }
        }),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF00B242),
        unselectedItemColor: FlutterFlowTheme.of(context).secondaryText,
        selectedBackgroundColor: const Color(0xFFE5EEE5),
        borderRadius: 8.0,
        itemBorderRadius: 8.0,
        margin: const EdgeInsetsDirectional.fromSTEB(10.0, 10.0, 10.0, 10.0),
        padding: const EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 5.0),
        width: double.infinity,
        elevation: 0.0,
        items: [
          FloatingNavbarItem(
            customWidget: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home_outlined,
                  color: (currentIndex == 0 || currentIndex == 4) ? const Color(0xFF00B242) : FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                Text(
                  'Home',
                  style: TextStyle(
                    color: (currentIndex == 0 || currentIndex == 4) ? const Color(0xFF00B242) : FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
          FloatingNavbarItem(
            customWidget: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: currentIndex == 1 ? const Color(0xFF00B242) : FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                Text(
                  'Alert',
                  style: TextStyle(
                    color: currentIndex == 1 ? const Color(0xFF00B242) : FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
          FloatingNavbarItem(
            customWidget: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.currency_rupee,
                  color: currentIndex == 2 ? const Color(0xFF00B242) : FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                Text(
                  'Subscription',
                  style: TextStyle(
                    color: currentIndex == 2 ? const Color(0xFF00B242) : FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
          FloatingNavbarItem(
            customWidget: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.settings_outlined,
                  color: currentIndex == 3 ? const Color(0xFF00B242) : FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: currentIndex == 3 ? const Color(0xFF00B242) : FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
