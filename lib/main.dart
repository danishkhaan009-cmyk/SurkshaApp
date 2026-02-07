import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:without_database/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'package:floating_bottom_navigation_bar/floating_bottom_navigation_bar.dart';
import 'package:without_database/services/screen_recording_service.dart';
import 'index.dart';
import 'package:without_database/services/location_tracking_service.dart';
import 'package:without_database/services/child_mode_service.dart';
import 'package:without_database/services/url_blocking_service.dart';
import 'package:without_database/services/google_drive_token_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // Configure Google Fonts - wrap in try-catch to handle AssetManifest errors
  try {
    // Enable google_fonts network fetching to download fonts at runtime
    // See: https://docs.flutter.dev/development/data-and-backend/networking#platform-notes
    GoogleFonts.config.allowRuntimeFetching = true;
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

  // Periodic timer to refresh Google Drive token from Supabase (child device)
  Timer? _driveTokenRefreshTimer;

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
          '✅ Child device detected: $deviceId - Resuming background monitoring',
        );

        // Initialize URL blocking service
        await UrlBlockingService().initialize(deviceId);
        print('✅ URL Blocking Service initialized on app start');

        // Initialize screen recording service
        await _initializeScreenRecordingService(deviceId);

        // Request screen recording permission and enable auto-recording
        await _setupAutoRecording();

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

  Future<void> _setupAutoRecording() async {
    try {
      print('🎥 Setting up auto-recording...');

      // Check if screen recording permission is already granted
      final hasPermission =
          await ScreenRecordingService.hasScreenRecordingPermission();

      if (!hasPermission) {
        print(
            '📱 Screen recording permission not granted - will request on first use');

        // Schedule permission request after app is fully loaded
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(seconds: 2));

          // Show dialog explaining the permission
          if (mounted) {
            final shouldRequest = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('📹 Screen Recording Permission'),
                  content: const Text(
                    'This app needs permission to record your screen for parental monitoring.\n\n'
                    'Recording will start automatically when you unlock your device.\n\n'
                    'Videos are securely uploaded to your parent\'s account.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Later'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Grant Permission'),
                    ),
                  ],
                );
              },
            );

            if (shouldRequest == true) {
              print('📱 Requesting screen recording permission...');
              await ScreenRecordingService.requestScreenRecordingPermission();

              // Wait for user to grant permission
              await Future.delayed(const Duration(seconds: 2));

              // Check if permission was granted
              final permissionGranted =
                  await ScreenRecordingService.hasScreenRecordingPermission();
              if (permissionGranted) {
                print('✅ Screen recording permission granted');
                await _enableAutoRecording();
              } else {
                print('⚠️ Screen recording permission not granted');
              }
            }
          }
        });

        return;
      }

      print('✅ Screen recording permission already granted');
      await _enableAutoRecording();
    } catch (e) {
      print('❌ Error setting up auto-recording: $e');
    }
  }

  Future<void> _enableAutoRecording() async {
    try {
      // Enable auto-recording on device unlock
      await ScreenRecordingService.setAutoRecording(
        enabled: true,
        trigger: 'unlock', // Options: 'unlock', 'usage', 'both', 'none'
      );

      print('✅ Auto-recording enabled with trigger: unlock');
    } catch (e) {
      print('❌ Error enabling auto-recording: $e');
    }
  }

  Future<void> _initializeScreenRecordingService(String deviceId) async {
    try {
      const platform = MethodChannel('parental_control/permissions');

      const supabaseUrl = 'https://myxdypywnifdsaorlhsy.supabase.co';
      const supabaseKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15eGR5cHl3bmlmZHNhb3JsaHN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMjQ1MDUsImV4cCI6MjA4MDcwMDUwNX0.biZRTsavn04B3NIfNPPlIwDuabArdR-CFdohYEWSdz8';

      // Set up method call handler to listen for permission granted callback
      platform.setMethodCallHandler((call) async {
        if (call.method == 'onScreenRecordPermissionGranted') {
          final granted = call.arguments == true;
          print('🖥️ Screen record permission callback: granted=$granted');
          if (granted) {
            // Permission granted - sync screen recording settings from parent
            print(
                '🖥️ Permission granted - syncing screen recording settings...');
            await Future.delayed(const Duration(milliseconds: 500));

            try {
              await platform.invokeMethod('syncScreenRecordSettings');
            } catch (e) {
              print('⚠️ syncScreenRecordSettings failed: $e');
            }
            print('✅ Screen recording service ready');
          }
        } else if (call.method == 'onGoogleDriveConnected') {
          // Handle Google Drive connection callback
          final email = call.arguments;
          if (email != null) {
            print('✅ Google Drive connected automatically: $email');
          }
        }
        return null;
      });

      // Initialize ScreenRecordService (screen capture via MediaProjection)
      await platform.invokeMethod('initScreenRecordService', {
        'deviceId': deviceId,
        'supabaseUrl': supabaseUrl,
        'supabaseKey': supabaseKey,
      });
      print('🖥️ ScreenRecordService initialized for device: $deviceId');

      // Clean up any orphan recording files from previous sessions
      try {
        await platform.invokeMethod('cleanupOrphanRecordings');
        print('🧹 Orphan recording files cleanup completed');
      } catch (e) {
        print('⚠️ Orphan cleanup failed: $e');
      }

      // Sync screen recording settings from Supabase (check if parent enabled it)
      try {
        await platform.invokeMethod('syncScreenRecordSettings');
        print('🖥️ Screen recording settings synced from Supabase');
      } catch (e) {
        print('⚠️ Screen recording settings sync failed: $e');
      }

      // Auto-request MediaProjection permission if screen recording is enabled but permission not granted
      try {
        final hasPermission =
            await platform.invokeMethod('hasScreenRecordingPermission') ??
                false;
        final isEnabled =
            await platform.invokeMethod('isScreenRecordingEnabled') ?? false;
        print(
            '🖥️ Screen recording: enabled=$isEnabled, hasPermission=$hasPermission');
        if (!hasPermission) {
          print(
              '🖥️ Requesting MediaProjection permission for screen recording...');
          await platform.invokeMethod('requestScreenRecordingPermission');
        }
      } catch (e) {
        print('⚠️ Screen recording permission check/request failed: $e');
      }

      // Auto-connect Google Drive if not already connected (for video uploads)
      await _ensureGoogleDriveConnected(platform, deviceId);

      print(
        '✅ All recording services initialized for child device',
      );
    } catch (e) {
      print('⚠️ Failed to initialize recording services: $e');
    }
  }

  /// Automatically connects Google Drive using parent's token from Supabase
  /// Falls back to prompting for login if no parent token is available
  /// This ensures recordings can be uploaded to the cloud
  Future<void> _ensureGoogleDriveConnected(
    MethodChannel platform,
    String deviceId,
  ) async {
    try {
      // Check if Google Drive is already connected locally
      final isConnected =
          await platform.invokeMethod('isGoogleDriveConnected') ?? false;

      print('☁️ Google Drive connection status: $isConnected');

      // Always fetch the latest token from Supabase (parent may have refreshed)
      // This ensures we always have the freshest token available
      print('☁️ Fetching latest Google Drive token from Supabase...');

      final tokenData = await GoogleDriveTokenService.fetchTokenForDevice(
        deviceId,
      );

      if (tokenData != null &&
          tokenData['token'] != null &&
          (tokenData['token'] as String).isNotEmpty) {
        final email = tokenData['email'];
        final token = tokenData['token']!;

        print('✅ Got Google Drive token from Supabase for email: $email');
        print(
            '☁️ Initializing/refreshing Google Drive with parent\'s credentials...');

        // Pass token to native side to initialize GoogleDriveUploader
        await platform.invokeMethod('initGoogleDriveWithToken', {
          'email': email ?? '',
          'token': token,
        });

        print('✅ Google Drive initialized with parent\'s token');
      } else if (!isConnected) {
        // No parent token available and not connected locally
        print(
          '☁️ No parent token found - prompting for Google Drive login...',
        );
        await platform.invokeMethod('requestGoogleDrivePermission');
        print('☁️ Google Drive connection prompt displayed');
      } else {
        print('✅ Google Drive already connected locally (no Supabase token)');
      }

      // Set up periodic token refresh from Supabase (every 30 minutes)
      _startPeriodicTokenRefresh(platform, deviceId);
    } catch (e) {
      print('⚠️ Failed to check/request Google Drive connection: $e');
    }
  }

  /// Periodically refresh the Google Drive token from Supabase.
  /// Parent refreshes the token each time they trigger a recording,
  /// so the child needs to pick up the new token.
  /// Uses adaptive interval: 15 min normally, 5 min when token was recently invalid.
  int _tokenRefreshIntervalMinutes = 15;
  int _tokenRefreshFailureCount = 0;

  void _startPeriodicTokenRefresh(MethodChannel platform, String deviceId) {
    // Cancel any existing timer
    _driveTokenRefreshTimer?.cancel();

    _driveTokenRefreshTimer = Timer.periodic(
      Duration(minutes: _tokenRefreshIntervalMinutes),
      (_) async {
        try {
          print(
              '🔄 Periodic Drive token refresh from Supabase (interval: ${_tokenRefreshIntervalMinutes}min)...');
          final tokenData =
              await GoogleDriveTokenService.fetchTokenForDevice(deviceId);

          if (tokenData != null &&
              tokenData['token'] != null &&
              (tokenData['token'] as String).isNotEmpty) {
            await platform.invokeMethod('initGoogleDriveWithToken', {
              'email': tokenData['email'] ?? '',
              'token': tokenData['token']!,
            });
            print('✅ Periodic Drive token refresh successful');

            // Try to upload any local_only recordings with the fresh token
            try {
              await platform.invokeMethod('retryPendingUploads');
              print('🔄 Triggered retry of pending uploads');
            } catch (e) {
              print('⚠️ retryPendingUploads failed: $e');
            }

            // If we were in fast-refresh mode and got a new token, slow down
            if (_tokenRefreshIntervalMinutes < 15) {
              _tokenRefreshFailureCount = 0;
              _tokenRefreshIntervalMinutes = 15;
              // Restart timer with normal interval
              _startPeriodicTokenRefresh(platform, deviceId);
              return;
            }
          } else {
            _tokenRefreshFailureCount++;
            print(
                '⚠️ No token in Supabase (failure #$_tokenRefreshFailureCount)');

            // After 2 consecutive failures, speed up refresh to 5 minutes
            if (_tokenRefreshFailureCount >= 2 &&
                _tokenRefreshIntervalMinutes > 5) {
              _tokenRefreshIntervalMinutes = 5;
              print(
                  '⚡ Switching to fast token refresh (every 5 min) due to failures');
              _startPeriodicTokenRefresh(platform, deviceId);
              return;
            }
          }
        } catch (e) {
          print('⚠️ Periodic Drive token refresh failed: $e');
        }
      },
    );
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
  void dispose() {
    _driveTokenRefreshTimer?.cancel();
    super.dispose();
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
          ),
        ],
      ),
    );
  }
}
