import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'package:floating_bottom_navigation_bar/floating_bottom_navigation_bar.dart';
import 'index.dart';
import '/services/location_tracking_service.dart';
import '/services/child_mode_service.dart';
import '/services/url_blocking_service.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // Configure Google Fonts - wrap in try-catch to handle AssetManifest errors
  try {
    // Disable google_fonts network fetching, use bundled fonts only
    GoogleFonts.config.allowRuntimeFetching = false;
    // GoogleFonts.config.allowRuntimeFetching = true;
  } catch (e) {
    print('⚠️ Google Fonts config failed: $e');
  }

  // Run FlutterFlow theme initialization first so the app can start even if Supabase fails.
  await FlutterFlowTheme.initialize();

  // Initialize Supabase but don't let an init failure abort app startup.
  try {
    await Supabase.initialize(
      url: 'https://myxdypywnifdsaorlhsy.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
    print('✅ Supabase initialized');
  } catch (e, st) {
    // Log init failure but continue startup; app can still run with degraded functionality.
    print('⚠️ Supabase initialization failed: $e\n$st');
  }

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

  // New: whether AssetManifest.json is available (controls GoogleFonts usage)
  bool _assetManifestExists = true;

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

    // Check for AssetManifest.json so GoogleFonts doesn't crash when it's missing
    _checkAssetManifest();
  }

  Future<void> _initializeBackgroundServices() async {
    try {
      final isChildMode = await ChildModeService.isChildModeActive();
      final deviceId = await ChildModeService.getChildDeviceId();
      print("isChildMode Active:  $isChildMode");
      if (isChildMode && deviceId != null && deviceId.isNotEmpty) {
        print(
            '✅ Child device detected: $deviceId - Resuming background monitoring');

        // Initialize URL blocking service
        await UrlBlockingService().initialize(deviceId);
        print('✅ URL Blocking Service initialized on app start');

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

  Future<void> _checkAssetManifest() async {
    try {
      await rootBundle.loadString('AssetManifest.json');
      // If load succeeds we keep using GoogleFonts
      safeSetState(() => _assetManifestExists = true);
    } catch (e) {
      // AssetManifest.json missing — disable GoogleFonts usage (fallback to default)
      print('⚠️ AssetManifest.json not found — disabling GoogleFonts: $e');
      safeSetState(() => _assetManifestExists = false);
    }
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  TextTheme _safeTextTheme(BuildContext context) {
    if (!_assetManifestExists) {
      // If manifest missing, avoid GoogleFonts which can throw when AssetManifest.json is absent.
      return Theme.of(context).textTheme;
    }
    try {
      return GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    } catch (_) {
      // In rare cases (platform/font loading issues) fall back to default theme
      return Theme.of(context).textTheme;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'surksha app',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
        textTheme: _safeTextTheme(context),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
        textTheme: _safeTextTheme(context),
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
    };
    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

    return Scaffold(
      body: _currentPage ?? tabs[_currentPageName]!,
      extendBody: true,
      bottomNavigationBar: FloatingNavbar(
        currentIndex: currentIndex,
        onTap: (i) => safeSetState(() {
          _currentPage = null;
          _currentPageName = tabs.keys.toList()[i];
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
                  color: currentIndex == 0
                      ? const Color(0xFF00B242)
                      : FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                Text(
                  'Home',
                  style: TextStyle(
                    color: currentIndex == 0
                        ? const Color(0xFF00B242)
                        : FlutterFlowTheme.of(context).secondaryText,
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
                  color: currentIndex == 1
                      ? const Color(0xFF00B242)
                      : FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                Text(
                  'Alert',
                  style: TextStyle(
                    color: currentIndex == 1
                        ? const Color(0xFF00B242)
                        : FlutterFlowTheme.of(context).secondaryText,
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
                  color: currentIndex == 2
                      ? const Color(0xFF00B242)
                      : FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                Text(
                  'Subscription',
                  style: TextStyle(
                    color: currentIndex == 2
                        ? const Color(0xFF00B242)
                        : FlutterFlowTheme.of(context).secondaryText,
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
                  color: currentIndex == 3
                      ? const Color(0xFF00B242)
                      : FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: currentIndex == 3
                        ? const Color(0xFF00B242)
                        : FlutterFlowTheme.of(context).secondaryText,
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
