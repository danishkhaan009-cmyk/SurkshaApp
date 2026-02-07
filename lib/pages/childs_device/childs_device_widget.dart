import 'dart:async';

import '../../services/app_lock_service.dart';
import '../../services/google_drive_token_service.dart';
import 'package:without_database/flutter_flow/flutter_flow_button_tabbar.dart';
import 'package:without_database/flutter_flow/flutter_flow_icon_button.dart';
import 'package:without_database/flutter_flow/flutter_flow_theme.dart';
import 'package:without_database/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:without_database/services/call_logs_service.dart';
import 'package:without_database/services/installed_apps_service.dart';
import 'package:without_database/services/location_tracking_service.dart';
import 'package:without_database/backend/supabase/supabase_rules.dart';
import 'childs_device_model.dart';
export 'childs_device_model.dart';

class ChildsDeviceWidget extends StatefulWidget {
  const ChildsDeviceWidget({
    super.key,
    this.deviceId,
    this.childName,
    this.childAge,
  });

  final String? deviceId;
  final String? childName;
  final int? childAge;

  static String routeName = 'Childs_Device';
  static String routePath = '/childsDevice';

  @override
  State<ChildsDeviceWidget> createState() => _ChildsDeviceWidgetState();
}

class _ChildsDeviceWidgetState extends State<ChildsDeviceWidget>
    with TickerProviderStateMixin {
  late ChildsDeviceModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Location state variables
  bool _isLoadingLocation = true;
  List<Map<String, dynamic>> _locationHistory = [];
  Map<String, dynamic>? _latestLocation;
  String? _deviceId;

  // Installed apps state variables
  bool _isLoadingApps = false;
  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  String? _appsError;
  final TextEditingController _appSearchController = TextEditingController();
  StreamSubscription? _appsSubscription;

  // Location subscription for real-time updates
  StreamSubscription? _locationSubscription;
  Timer? _locationRefreshTimer;

  // Call logs state variables
  bool _isLoadingCallLogs = false;
  List<Map<String, dynamic>> _callLogs = [];
  String? _callLogsError;

  // VPN/URL Blocking state variables
  bool _isLoadingBlockedUrls = false;
  bool _isLoadingSearchHistory = false;
  List<Map<String, dynamic>> _blockedUrls = [];
  List<Map<String, dynamic>> _searchHistory = [];
  final TextEditingController _urlInputController = TextEditingController();

  // Screen Recording state variables
  bool _isLoadingRecordingSettings = false;
  List<Map<String, dynamic>> _screenRecordings = [];
  bool _isLoadingRecordings = false;
  bool _isGoogleDriveConnected = false;
  String? _googleDriveAccount;
  Timer? _recordingStatusTimer;

  // Screen Recording state (actual screen capture via MediaProjection)
  bool _isScreenRecordingEnabled = false;
  bool _isScreenRecordingActive = false;

  static const platform = MethodChannel('parental_control/permissions');

  // List to store rules
  List<Map<String, dynamic>> rules = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChildsDeviceModel());

    _model.tabBarController = TabController(
      vsync: this,
      length: 6,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));
    _model.tabBarController!.addListener(_handleTabChange);

    _model.switchValue = true;

    // Setup search listener
    _appSearchController.addListener(_filterApps);

    // Setup method channel listener for native callbacks
    platform.setMethodCallHandler(_handleNativeCallback);

    // Initialize data loading with proper coordination
    _initializeData();
  }

  // Coordinate data loading to prevent overwhelming the UI
  Future<void> _initializeData() async {
    // Fetch location data and setup real-time subscription
    _fetchLocationData();
    _setupLocationSubscription();

    // Wait a frame to let the UI settle
    await Future.delayed(Duration.zero);

    // Fetch rules from database
    _fetchRulesFromDatabase();

    // Stagger remaining operations slightly
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _fetchInstalledApps();
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fetchRecordingSettings();
        _fetchScreenRecordings();
      }
    });
  }

  // Handle native callbacks from Android
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onScreenRecordPermissionGranted':
        if (call.arguments == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Screen recording permission granted'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
      case 'onGoogleDriveConnected':
        // Handle new format: call.arguments is a Map with 'email' and 'token'
        final data = call.arguments;
        String? email;
        String? token;

        if (data is Map) {
          email = data['email'] as String?;
          token = data['token'] as String?;
        } else if (data is String) {
          // Legacy support: just email string
          email = data;
        }

        setState(() {
          _isGoogleDriveConnected = email != null && email.isNotEmpty;
          _googleDriveAccount = email;
        });

        if (_isGoogleDriveConnected && widget.deviceId != null) {
          // Save token to Supabase so child device can use it
          if (token != null && token.isNotEmpty) {
            try {
              await GoogleDriveTokenService.saveTokenForDevice(
                deviceId: widget.deviceId!,
                email: email!,
                token: token,
              );
              print(
                '✅ Google Drive token saved to Supabase for device: ${widget.deviceId}',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Google Drive connected: $email\nChild device can now upload recordings.',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ),
              );
            } catch (e) {
              print('❌ Failed to save token to Supabase: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Connected to Google Drive: $email\n(Warning: Token sync failed)',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connected to Google Drive: $email'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        break;
    }
  }

  // Fetch screen recording settings and status
  Future<void> _fetchRecordingSettings() async {
    setState(() => _isLoadingRecordingSettings = true);

    try {
      final isDriveConnected = await platform.invokeMethod(
        'isGoogleDriveConnected',
      );
      final driveAccount = await platform.invokeMethod('getGoogleDriveAccount');

      // Check screen recording status
      try {
        final screenRecordStatus =
            await platform.invokeMethod('isScreenRecordingActive');
        if (screenRecordStatus is Map) {
          setState(() {
            _isScreenRecordingEnabled =
                screenRecordStatus['isEnabled'] ?? false;
            _isScreenRecordingActive =
                screenRecordStatus['isRecording'] ?? false;
          });
        }
      } catch (e) {
        print('Error checking screen recording status: $e');
        // Fallback: check from Supabase
        try {
          await _fetchScreenRecordingSettingsFromSupabase();
        } catch (_) {}
      }

      setState(() {
        _isGoogleDriveConnected = isDriveConnected ?? false;
        _googleDriveAccount = driveAccount;
      });

      // Check if child device is requesting a token refresh (401 occurred)
      _checkAndAutoRefreshToken();
    } catch (e) {
      print('Error fetching recording settings: $e');
    }

    setState(() => _isLoadingRecordingSettings = false);
  }

  // Fetch screen recording settings from Supabase (for remote parent control)
  Future<void> _fetchScreenRecordingSettingsFromSupabase() async {
    try {
      if (widget.deviceId == null) return;
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('screen_recording_settings')
          .select('recording_enabled')
          .eq('device_id', widget.deviceId!)
          .maybeSingle();
      if (response != null) {
        setState(() {
          _isScreenRecordingEnabled = response['recording_enabled'] ?? false;
        });
      }
    } catch (e) {
      print('Error fetching screen recording settings from Supabase: $e');
    }
  }

  // Start polling recording status every 3 seconds
  void _startRecordingStatusPolling() {
    _recordingStatusTimer?.cancel();
    _recordingStatusTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (mounted && _model.tabBarController!.index == 4) {
          _fetchRecordingSettings();
        }
      },
    );
  }

  // Stop polling recording status
  void _stopRecordingStatusPolling() {
    _recordingStatusTimer?.cancel();
    _recordingStatusTimer = null;
  }

  // Fetch screen recordings list
  Future<void> _fetchScreenRecordings() async {
    setState(() => _isLoadingRecordings = true);

    try {
      // Pass the child's device ID to fetch their recordings
      final recordings = await platform.invokeMethod('getScreenRecordings', {
        'deviceId': widget.deviceId,
      });
      if (recordings != null) {
        setState(() {
          _screenRecordings = List<Map<String, dynamic>>.from(
            (recordings as List).map((e) => Map<String, dynamic>.from(e)),
          );
        });
        print(
          '✅ Fetched ${_screenRecordings.length} recordings for device: ${widget.deviceId}',
        );
      }
    } catch (e) {
      print('Error fetching recordings from native: $e');
      // Fallback: fetch from Supabase directly
      await _fetchScreenRecordingsFromSupabase();
    }

    setState(() => _isLoadingRecordings = false);
  }

  // Fetch recordings directly from Supabase
  Future<void> _fetchScreenRecordingsFromSupabase() async {
    try {
      if (widget.deviceId == null || widget.deviceId!.isEmpty) {
        print('⚠️ No device ID available for fetching recordings');
        return;
      }

      print(
        '📱 Fetching recordings from Supabase for device: ${widget.deviceId}',
      );
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('screen_recordings')
          .select()
          .eq('device_id', widget.deviceId!)
          .order('recorded_at', ascending: false)
          .limit(50);

      setState(() {
        _screenRecordings = List<Map<String, dynamic>>.from(response);
      });
      print('✅ Fetched ${_screenRecordings.length} recordings from Supabase');
    } catch (e) {
      print('❌ Error fetching recordings from Supabase: $e');
    }
  }

  /// Refresh Google Drive token on parent device and save to Supabase for child.
  /// This ensures the child always has a fresh token for uploads.
  Future<void> _refreshAndSaveDriveToken() async {
    try {
      if (widget.deviceId == null) return;

      print('🔄 Refreshing Google Drive token for child device...');
      final result = await platform.invokeMethod('refreshGoogleDriveToken');

      if (result is Map) {
        final email = result['email'] as String?;
        final token = result['token'] as String?;

        if (email != null && token != null && token.isNotEmpty) {
          // Save fresh token to Supabase so child can fetch it
          await GoogleDriveTokenService.saveTokenForDevice(
            deviceId: widget.deviceId!,
            email: email,
            token: token,
          );
          print('✅ Fresh Drive token saved to Supabase for child device');
        }
      }
    } catch (e) {
      print('⚠️ Could not refresh Drive token (non-fatal): $e');
      // Non-fatal - child may still have a valid token
    }
  }

  /// Check if child device has requested a token refresh (e.g., after 401 error).
  /// If so, auto-refresh the token and push to Supabase.
  /// Rate-limited: only checks once every 30 seconds to avoid Supabase spam.
  DateTime? _lastTokenRefreshCheck;
  Future<void> _checkAndAutoRefreshToken() async {
    try {
      if (widget.deviceId == null) return;

      // Rate limit: check at most once every 30 seconds
      final now = DateTime.now();
      if (_lastTokenRefreshCheck != null &&
          now.difference(_lastTokenRefreshCheck!).inSeconds < 30) {
        return;
      }
      _lastTokenRefreshCheck = now;

      final needsRefresh =
          await GoogleDriveTokenService.isTokenRefreshRequested(
              widget.deviceId!);

      if (needsRefresh) {
        print('🔔 Child device needs token refresh! Auto-refreshing...');

        // Refresh the token on parent's device
        await _refreshAndSaveDriveToken();

        // Clear the refresh request flag
        await GoogleDriveTokenService.clearTokenRefreshRequest(
            widget.deviceId!);

        print('✅ Auto token refresh complete, child will pick up new token');
      }
    } catch (e) {
      print('⚠️ Auto token refresh check failed: $e');
    }
  }

  /// Toggle screen recording (actual screen capture of what child sees) on/off.
  /// This records the child's screen when they use other apps.
  Future<void> _toggleScreenRecordingEnabled(bool enabled) async {
    try {
      if (widget.deviceId == null) return;

      // Check if Google Drive is connected first
      if (enabled && !_isGoogleDriveConnected) {
        await platform.invokeMethod('requestGoogleDrivePermission');
        return;
      }

      setState(() => _isLoadingRecordingSettings = true);

      // Refresh Drive token before enabling
      if (enabled) {
        await _refreshAndSaveDriveToken();
      }

      // Update setting in Supabase so child device can pick it up
      final supabase = Supabase.instance.client;
      await supabase.from('screen_recording_settings').upsert({
        'device_id': widget.deviceId,
        'recording_enabled': enabled,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'device_id');

      setState(() {
        _isScreenRecordingEnabled = enabled;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Screen recording enabled! Will record when child uses apps.'
                : 'Screen recording disabled',
          ),
          backgroundColor: enabled ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

      print(
          '✅ Screen recording ${enabled ? "ENABLED" : "DISABLED"} for device: ${widget.deviceId}');
    } catch (e) {
      print('Error toggling screen recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingRecordingSettings = false);
    }
  }

  // Fetch rules from Supabase
  Future<void> _fetchRulesFromDatabase() async {
    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // Fetch rules for this device
      final rulesData = await supabase
          .from('device_rules')
          .select()
          .eq('device_id', widget.deviceId!)
          .order('created_at', ascending: false);

      setState(() {
        rules = rulesData.map<Map<String, dynamic>>((rule) {
          // Convert database rule to UI format
          IconData ruleIcon;

          switch (rule['rule_type']) {
            case 'App Time Limit':
              ruleIcon = FontAwesomeIcons.clock;
              break;
            case 'Daily Screen Time':
              ruleIcon = Icons.access_time_rounded;
              break;
            case 'Bedtime Lock':
              ruleIcon = Icons.bedtime_outlined;
              break;
            case 'App Lock':
              ruleIcon = Icons.lock_rounded;
              break;
            default:
              ruleIcon = Icons.rule;
          }

          return {
            'id': rule['id'], // Store database ID
            'icon': ruleIcon,
            'title': rule['title'],
            'subtitle': rule['subtitle'],
            // keep both casing variants so helpers can read either
            'isActive': rule['is_active'] ?? rule['isActive'] ?? false,
            'is_active': rule['is_active'] ?? rule['isActive'] ?? false,
            'rule_type': rule['rule_type'],
            'app_package_name': rule['app_package_name'] ??
                rule['package_name'] ??
                rule['appPackageName'],
            'time_limit_minutes': rule['time_limit_minutes'],
            // include PIN related fields so UI can detect if PIN was set
            'app_lock_pin': rule['app_lock_pin'],
            'pin_code': rule['pin_code'],
          };
        }).toList();
      });

      print('✅ Loaded ${rules.length} rules from database');
    } catch (e) {
      print('❌ Error fetching rules: $e');
    }
  }

  // Fetch location history from Supabase
  Future<void> _fetchLocationData() async {
    try {
      print('🔍 Fetching location data for device: ${widget.deviceId}');

      // Use the device ID passed from parent dashboard
      if (widget.deviceId == null || widget.deviceId!.isEmpty) {
        print('⚠️ No device ID provided');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      _deviceId = widget.deviceId;
      print('✅ Using Device ID: $_deviceId');

      // Fetch latest location using LocationTrackingService
      final latestLocation = await LocationTrackingService.fetchLatestLocation(
        _deviceId!,
      );

      print('📍 Latest location found: ${latestLocation != null}');

      // Fetch location history using LocationTrackingService
      final locationHistory =
          await LocationTrackingService.fetchLocationHistory(
        _deviceId!,
        limit: 10,
      );

      print('📜 Found ${locationHistory.length} location history entries');

      if (!mounted) return;

      setState(() {
        _latestLocation = latestLocation;
        _locationHistory = locationHistory;
        _isLoadingLocation = false;
      });

      if (_latestLocation != null) {
        print('✅ Latest location: ${_latestLocation?['address']}');
      } else {
        print('⚠️ No latest location found');
      }

      print('✅ Location data fetch completed');
    } catch (e) {
      print('❌ Error fetching location data: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // Setup real-time location subscription
  void _setupLocationSubscription() {
    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      print('⚠️ Cannot setup location subscription: No device ID');
      return;
    }

    // Cancel any existing subscription
    _locationSubscription?.cancel();
    _locationRefreshTimer?.cancel();

    print(
      '🔗 Setting up real-time location subscription for device: ${widget.deviceId}',
    );

    // Subscribe to real-time location history updates (includes latest)
    _locationSubscription = LocationTrackingService.watchLocationHistory(
      widget.deviceId!,
      limit: 10,
    ).listen(
      (locationHistory) {
        if (!mounted) return;

        print(
          '📍 Real-time location update received: ${locationHistory.length} entries',
        );

        setState(() {
          _locationHistory = locationHistory;
          if (locationHistory.isNotEmpty) {
            _latestLocation = locationHistory.first;
            print(
              '📍 Updated latest location: ${_latestLocation?['address']}',
            );
          }
        });
      },
      onError: (error) {
        print('❌ Location subscription error: $error');
      },
    );

    // Also set up periodic refresh every 60 seconds as a fallback
    _locationRefreshTimer = Timer.periodic(const Duration(seconds: 60), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      print('🔄 Periodic location refresh triggered');
      _fetchLocationData();
    });

    print('✅ Location subscription setup completed');
  }

  // Fetch installed apps
  Future<void> _fetchInstalledApps() async {
    print(
      '🔄 Starting to fetch installed apps for device: ${widget.deviceId}...',
    );
    setState(() {
      _isLoadingApps = true;
      _appsError = null;
    });

    try {
      // Use the device ID from widget parameter to fetch apps from database
      final deviceIdToFetch = widget.deviceId ?? _deviceId;

      if (deviceIdToFetch == null || deviceIdToFetch.isEmpty) {
        throw Exception('Device ID is not available');
      }

      // Cancel existing subscription if any
      await _appsSubscription?.cancel();

      // Set up real-time subscription for app updates
      print('👁️ Setting up real-time subscription for apps...');
      _appsSubscription =
          InstalledAppsService.watchInstalledApps(deviceIdToFetch).listen(
        (appsFromDb) {
          if (!mounted) return;

          // Transform the data to match the expected format
          final apps = appsFromDb
              .map(
                (app) => {
                  'appName': app['app_name'] ?? 'Unknown App',
                  'packageName': app['package_name'] ?? '',
                  'versionName': app['version_name'] ?? '',
                },
              )
              .toList();

          print('✅ Real-time update: ${apps.length} installed apps');

          setState(() {
            _installedApps = apps;
            _filteredApps = _appSearchController.text.isEmpty
                ? apps
                : apps.where((app) {
                    final query = _appSearchController.text.toLowerCase();
                    final appName = (app['appName'] as String).toLowerCase();
                    final packageName =
                        (app['packageName'] as String).toLowerCase();
                    return appName.contains(query) ||
                        packageName.contains(query);
                  }).toList();
            _isLoadingApps = false;
            _appsError = null;
          });
        },
        onError: (error) {
          print('❌ Error in real-time subscription: $error');
          if (mounted) {
            setState(() {
              _isLoadingApps = false;
              _appsError = error.toString();
            });
          }
        },
      );
    } catch (e, stackTrace) {
      print('❌ Error fetching installed apps: $e');
      print('Stack trace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoadingApps = false;
        _appsError = e.toString();
      });
    }
  }

  // Filter apps based on search query
  void _filterApps() {
    final query = _appSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = _installedApps;
      } else {
        _filteredApps = _installedApps.where((app) {
          final appName = (app['appName'] as String).toLowerCase();
          final packageName = (app['packageName'] as String).toLowerCase();
          return appName.contains(query) || packageName.contains(query);
        }).toList();
      }
    });
  }

  // Replace the existing _fetchCallLogs with this database-backed version
  Future<void> _fetchCallLogs() async {
    print('📞 Starting to fetch call logs from database...');
    if (!mounted) return;

    setState(() {
      _isLoadingCallLogs = true;
      _callLogsError = null;
    });

    try {
      // Fetch call logs from the database for this device
      final callLogs = await CallLogsService.fetchCallLogsFromDb(
        widget.deviceId ?? '',
      );

      print('✅ Loaded ${callLogs.length} call logs from database');

      // Convert timestamp strings back to DateTime objects
      final parsed = <Map<String, dynamic>>[];
      for (final item in callLogs) {
        final call = Map<String, dynamic>.from(item);
        // Convert timestamp string to DateTime if needed
        if (call['timestamp'] is String) {
          call['timestamp'] = DateTime.parse(call['timestamp']);
        }
        parsed.add(call);
      }

      if (!mounted) return;
      setState(() {
        _callLogs = parsed;
        _isLoadingCallLogs = false;
        _callLogsError = null;
      });
    } catch (e, st) {
      print('❌ Error fetching call logs: $e');
      print('Stack trace: $st');
      if (!mounted) return;
      setState(() {
        _isLoadingCallLogs = false;
        _callLogsError = e.toString();
        _callLogs = [];
      });
    }
  }

  void _handleTabChange() {
    if (!_model.tabBarController!.indexIsChanging) {
      // Tab 4: Screen Recording
      if (_model.tabBarController!.index == 4) {
        if (_screenRecordings.isEmpty && !_isLoadingRecordings) {
          _fetchRecordingSettings();
          _fetchScreenRecordings();
        }
        // Start polling recording status when on recording tab
        _startRecordingStatusPolling();
      } else {
        // Stop polling when leaving recording tab
        _stopRecordingStatusPolling();
      }
      // Tab 5: Call Logs
      if (_model.tabBarController!.index == 5) {
        if (_callLogs.isEmpty && !_isLoadingCallLogs) {
          _fetchCallLogs();
        }
      }
    }
  }

  // in dispose()
  @override
  void dispose() {
    try {
      _model.tabBarController!.removeListener(_handleTabChange);
    } catch (_) {}
    _model.dispose();
    _appSearchController.dispose();
    _urlInputController.dispose();
    _appsSubscription?.cancel();
    _locationSubscription?.cancel();
    _locationRefreshTimer?.cancel();
    _recordingStatusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1A1A1A),
              size: 30.0,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          title: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 0.0, 0.0),
            child: Text(
              '${widget.childName ?? 'Child Name'}, ${widget.childAge ?? 12}',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.interTight(
                      fontWeight: FlutterFlowTheme.of(
                        context,
                      ).headlineMedium.fontWeight,
                      fontStyle: FlutterFlowTheme.of(
                        context,
                      ).headlineMedium.fontStyle,
                    ),
                    color: const Color(0xFF1A1A1A),
                    fontSize: 22.0,
                    letterSpacing: 0.0,
                    fontWeight: FlutterFlowTheme.of(
                      context,
                    ).headlineMedium.fontWeight,
                    fontStyle: FlutterFlowTheme.of(
                      context,
                    ).headlineMedium.fontStyle,
                  ),
            ),
          ),
          actions: const [],
          centerTitle: false,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 1.0,
                  height: 0.0,
                  decoration: const BoxDecoration(color: Color(0xFFF6F6F6)),
                  child: Align(
                    alignment: const AlignmentDirectional(0.0, 0.0),
                    child: Column(
                      children: [
                        Align(
                          alignment: const Alignment(-1.0, 0),
                          child: FlutterFlowButtonTabBar(
                            useToggleButtonStyle: false,
                            isScrollable: true,
                            labelStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FlutterFlowTheme.of(
                                      context,
                                    ).titleSmall.fontWeight,
                                    fontStyle: FlutterFlowTheme.of(
                                      context,
                                    ).titleSmall.fontStyle,
                                  ),
                                  fontSize: 16.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(
                                    context,
                                  ).titleSmall.fontWeight,
                                  fontStyle: FlutterFlowTheme.of(
                                    context,
                                  ).titleSmall.fontStyle,
                                  lineHeight: 2.0,
                                ),
                            unselectedLabelStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FlutterFlowTheme.of(
                                      context,
                                    ).titleSmall.fontWeight,
                                    fontStyle: FlutterFlowTheme.of(
                                      context,
                                    ).titleSmall.fontStyle,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(
                                    context,
                                  ).titleSmall.fontWeight,
                                  fontStyle: FlutterFlowTheme.of(
                                    context,
                                  ).titleSmall.fontStyle,
                                ),
                            labelColor: FlutterFlowTheme.of(
                              context,
                            ).primaryText,
                            unselectedLabelColor: FlutterFlowTheme.of(
                              context,
                            ).secondaryText,
                            backgroundColor: const Color(0xFFD4E7D4),
                            unselectedBackgroundColor: Colors.white,
                            borderColor: const Color(0xFF00B242),
                            unselectedBorderColor: FlutterFlowTheme.of(
                              context,
                            ).alternate,
                            borderWidth: 1.0,
                            borderRadius: 5.0,
                            elevation: 0.0,
                            buttonMargin: const EdgeInsetsDirectional.fromSTEB(
                              10.0,
                              10.0,
                              10.0,
                              10.0,
                            ),
                            tabs: const [
                              Tab(
                                text: 'Rules',
                                icon: Icon(Icons.access_time),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                  50.0,
                                  0.0,
                                  50.0,
                                  0.0,
                                ),
                              ),
                              Tab(
                                text: 'Apps',
                                icon: Icon(Icons.apps_sharp),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                  50.0,
                                  0.0,
                                  50.0,
                                  0.0,
                                ),
                              ),
                              Tab(
                                text: 'Location Plus',
                                icon: Icon(Icons.location_on_outlined),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                  50.0,
                                  0.0,
                                  50.0,
                                  0.0,
                                ),
                              ),
                              Tab(
                                text: 'URL Blocker',
                                icon: Icon(Icons.vpn_lock_outlined),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                  50.0,
                                  0.0,
                                  50.0,
                                  0.0,
                                ),
                              ),
                              Tab(
                                text: 'Recording',
                                icon: Icon(Icons.videocam_outlined),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                  50.0,
                                  0.0,
                                  50.0,
                                  0.0,
                                ),
                              ),
                              Tab(
                                text: 'Call Pro',
                                icon: Icon(Icons.call_outlined),
                                iconMargin: EdgeInsetsDirectional.fromSTEB(
                                  50.0,
                                  0.0,
                                  50.0,
                                  0.0,
                                ),
                              ),
                            ],
                            controller: _model.tabBarController,
                            onTap: (i) async {
                              [
                                () async {}, // Rules tab
                                () async {
                                  // Apps tab - load apps if not loaded
                                  print('📱 Apps tab clicked');
                                  if (_installedApps.isEmpty &&
                                      !_isLoadingApps) {
                                    print('🔄 Apps list is empty, fetching...');
                                    await _fetchInstalledApps();
                                  } else {
                                    print(
                                      '✅ Apps already loaded: ${_installedApps.length} apps',
                                    );
                                  }
                                },
                                () async {}, // Location Plus tab
                                () async {
                                  // VPN tab - load blocked URLs and search history
                                  print('🔒 VPN tab clicked');
                                  await _fetchBlockedUrls();
                                  await _fetchSearchHistory();
                                }, // VPN tab
                                () async {
                                  // Recording tab
                                  print('🎥 Recording tab clicked');
                                  await _fetchRecordingSettings();
                                  await _fetchScreenRecordings();
                                }, // Recording tab
                                () async {
                                  // Call Pro tab - load call logs if not loaded
                                  print('📞 Call Pro tab clicked');
                                  if (_callLogs.isEmpty &&
                                      !_isLoadingCallLogs) {
                                    print(
                                      '🔄 Call logs list is empty, fetching...',
                                    );
                                    await _fetchCallLogs();
                                  } else {
                                    print(
                                      '✅ Call logs already loaded: ${_callLogs.length} calls',
                                    );
                                  }
                                }, // Call Pro tab
                              ][i]();
                            },
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _model.tabBarController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              // Tab 0: Rules
                              _buildRulesTab(),
                              // Tab 1: Apps
                              _buildAppsTab(),
                              // Tab 2: Location
                              _buildLocationTab(),
                              // Tab 3: VPN
                              _buildVpnTab(),
                              // Tab 4: Screen Recording
                              _buildScreenRecordingTab(),
                              // Tab 5: Call Pro
                              _buildCallsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddRuleDialog() {
    String? selectedRuleType = 'App Time Limit';
    String? selectedCategory = 'Social Media';
    String? selectedApp;
    int timeLimit = 60;
    String? appPin;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: SingleChildScrollView(
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add New Rule',
                            style: GoogleFonts.inter(
                              fontSize: 20.0,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Create rules to manage app usage and screen time',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          color: const Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 24.0),

                      // Rule Type
                      Text(
                        'Rule Type',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRuleType,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            items: [
                              'App Time Limit',
                              'Daily Screen Time',
                              'Bedtime Lock',
                              'App Lock',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.0,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedRuleType = newValue;
                              });
                            },
                            icon: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // App Category
                      if (selectedRuleType == 'App Time Limit' ||
                          selectedRuleType == 'App Lock') ...[
                        Text(
                          'App Category',
                          style: GoogleFonts.inter(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCategory,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              items: [
                                'Social Media',
                                'Messaging',
                                'Entertainment',
                                'Gaming',
                                'Browsers',
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Row(
                                    children: [
                                      Text(
                                        value,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.0,
                                          color: const Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedCategory = newValue;
                                  selectedApp = null; // Reset app selection
                                });
                              },
                              icon: const Icon(Icons.keyboard_arrow_down),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        // App Name
                        Text(
                          'App Name',
                          style: GoogleFonts.inter(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _getAppsForCategory(
                                selectedCategory,
                              ).contains(selectedApp)
                                  ? selectedApp
                                  : null,
                              hint: Text(
                                'Select an app',
                                style: GoogleFonts.inter(
                                  fontSize: 14.0,
                                  color: const Color(0xFF999999),
                                ),
                              ),
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              items: _getAppsForCategory(selectedCategory).map((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.0,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedApp = newValue;
                                });
                              },
                              icon: const Icon(Icons.keyboard_arrow_down),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                      ],

                      // For App Lock - show PIN instead of time limit
                      if (selectedRuleType == 'App Lock') ...[
                        Text(
                          'Set PIN for this App',
                          style: GoogleFonts.inter(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 4,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '4-digit PIN',
                              counterText: '',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14.0,
                                color: const Color(0xFF999999),
                              ),
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14.0,
                              color: const Color(0xFF1A1A1A),
                            ),
                            onChanged: (value) {
                              appPin = value;
                            },
                          ),
                        ),
                      ],

                      // For other rule types - show time limit
                      if (selectedRuleType != 'App Lock') ...[
                        Text(
                          'Time Limit (minutes)',
                          style: GoogleFonts.inter(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '60',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14.0,
                                color: const Color(0xFF999999),
                              ),
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14.0,
                              color: const Color(0xFF1A1A1A),
                            ),
                            onChanged: (value) {
                              timeLimit = int.tryParse(value) ?? 60;
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 24.0),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14.0,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Add new rule to database
                                if (selectedRuleType != null &&
                                    widget.deviceId != null) {
                                  String ruleTitle;
                                  String ruleSubtitle;
                                  String? appPackageName;
                                  String? bedtimeStart;
                                  String? bedtimeEnd;

                                  if (selectedRuleType == 'App Time Limit' &&
                                      selectedApp != null) {
                                    ruleTitle = '$selectedApp Time Limit';
                                    ruleSubtitle =
                                        'Limited to $timeLimit minutes';

                                    // Get package name from database
                                    appPackageName =
                                        await SupabaseRules.getPackageName(
                                      selectedApp!,
                                    );
                                  } else if (selectedRuleType ==
                                      'Daily Screen Time') {
                                    ruleTitle = 'Daily Screen Limit';
                                    ruleSubtitle = '$timeLimit minutes per day';
                                  } else if (selectedRuleType == 'App Lock') {
                                    if (selectedApp == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '❌ Please select an app to lock',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    if (appPin == null || appPin!.length != 4) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '❌ Please set a 4-digit PIN',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    ruleTitle = '$selectedApp Lock';
                                    ruleSubtitle = 'App locked - PIN required';

                                    // Get package name for the locked app
                                    appPackageName =
                                        await SupabaseRules.getPackageName(
                                      selectedApp!,
                                    );
                                  } else {
                                    // Bedtime Lock
                                    ruleTitle = 'Bedtime Lock';
                                    ruleSubtitle = '10:00 PM - 7:00 AM';
                                    bedtimeStart = '22:00:00';
                                    bedtimeEnd = '07:00:00';
                                  }

                                  // Get current user (parent) ID
                                  final supabase = Supabase.instance.client;
                                  final parentId =
                                      supabase.auth.currentUser?.id;

                                  if (parentId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('❌ Please log in first'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  // Show loading
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Adding rule...'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }

                                  // Add rule to database
                                  final success = await SupabaseRules.addRule(
                                    deviceId: widget.deviceId!,
                                    parentId: parentId,
                                    ruleType: selectedRuleType!,
                                    title: ruleTitle,
                                    subtitle: ruleSubtitle,
                                    appCategory: selectedCategory,
                                    appName: selectedApp,
                                    appPackageName: appPackageName,
                                    timeLimitMinutes: timeLimit,
                                    bedtimeStart: bedtimeStart,
                                    bedtimeEnd: bedtimeEnd,
                                    isActive: true,
                                    appLockPin: appPin,
                                  );

                                  if (success) {
                                    // Refresh rules from database
                                    await _fetchRulesFromDatabase();

                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '✅ Rule added successfully',
                                          ),
                                          backgroundColor: Color(0xFF58C16D),
                                        ),
                                      );

                                      Navigator.of(context).pop();
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('❌ Failed to add rule'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF666666),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14.0,
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Add Rule',
                                style: GoogleFonts.inter(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditRuleDialog(int index) {
    Map<String, dynamic> rule = rules[index];
    String? selectedRuleType;
    String? selectedCategory;
    String? selectedApp;
    int timeLimit = 60;

    // Parse existing rule data
    String title = rule['title'];
    String subtitle = rule['subtitle'];

    // Extract time limit from subtitle
    RegExp timeLimitRegex = RegExp(r'(\d+)\s*minutes?');
    Match? match = timeLimitRegex.firstMatch(subtitle);
    if (match != null) {
      timeLimit = int.parse(match.group(1)!);
    } else {
      // Try to extract from "X hours per day"
      RegExp hoursRegex = RegExp(r'(\d+)\s*hours?');
      Match? hoursMatch = hoursRegex.firstMatch(subtitle);
      if (hoursMatch != null) {
        timeLimit = int.parse(hoursMatch.group(1)!) * 60;
      }
    }

    // Determine rule type from title
    if (title.contains('Bedtime')) {
      selectedRuleType = 'Bedtime Lock';
    } else if (title.contains('Daily Screen')) {
      selectedRuleType = 'Daily Screen Time';
    } else if (title.contains('App Lock') || title.contains(' Lock')) {
      selectedRuleType = 'App Lock';
      // Extract app name from "AJIO Lock" -> "AJIO"
      String appName = title.replaceAll(' Lock', '').trim();
      // Validate app exists in categories before setting
      bool appFound = false;
      for (var category in [
        'Social Media',
        'Messaging',
        'Entertainment',
        'Gaming',
        'Browsers',
      ]) {
        if (_getAppsForCategory(category).contains(appName)) {
          selectedCategory = category;
          selectedApp = appName;
          appFound = true;
          break;
        }
      }
      if (!appFound) {
        // App not in predefined lists, set default
        selectedCategory = 'Social Media';
        selectedApp = null;
      }
    } else {
      selectedRuleType = 'App Time Limit';
      // Extract app name
      String appName = title.replaceAll(' Time Limit', '').trim();
      // Validate app exists in categories before setting
      bool appFound = false;
      for (var category in [
        'Social Media',
        'Messaging',
        'Entertainment',
        'Gaming',
        'Browsers',
      ]) {
        if (_getAppsForCategory(category).contains(appName)) {
          selectedCategory = category;
          selectedApp = appName;
          appFound = true;
          break;
        }
      }
      if (!appFound) {
        // App not in predefined lists, set default
        selectedCategory = 'Social Media';
        selectedApp = null;
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Rule',
                          style: GoogleFonts.inter(
                            fontSize: 20.0,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Update rules to manage app usage and screen time',
                      style: GoogleFonts.inter(
                        fontSize: 14.0,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Rule Type
                    Text(
                      'Rule Type',
                      style: GoogleFonts.inter(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRuleType,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          items: [
                            'App Time Limit',
                            'Daily Screen Time',
                            'Bedtime Lock',
                            'App Lock',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: GoogleFonts.inter(
                                  fontSize: 14.0,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedRuleType = newValue;
                            });
                          },
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // App Category
                    if (selectedRuleType == 'App Time Limit') ...[
                      Text(
                        'App Category',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            items: [
                              'Social Media',
                              'Messaging',
                              'Entertainment',
                              'Gaming',
                              'Browsers',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Row(
                                  children: [
                                    Text(
                                      value,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.0,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedCategory = newValue;
                                selectedApp = null;
                              });
                            },
                            icon: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // App Name
                      Text(
                        'App Name',
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _getAppsForCategory(
                              selectedCategory,
                            ).contains(selectedApp)
                                ? selectedApp
                                : null,
                            hint: Text(
                              'Select an app',
                              style: GoogleFonts.inter(
                                fontSize: 14.0,
                                color: const Color(0xFF999999),
                              ),
                            ),
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            items: _getAppsForCategory(selectedCategory).map((
                              String value,
                            ) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: selectedApp == value
                                        ? const Color(0xFF58C16D)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    value,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.0,
                                      color: selectedApp == value
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedApp = newValue;
                              });
                            },
                            icon: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    // Time Limit
                    Text(
                      'Time Limit (minutes)',
                      style: GoogleFonts.inter(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: TextEditingController(
                          text: timeLimit.toString(),
                        ),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14.0,
                            color: const Color(0xFF999999),
                          ),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          color: const Color(0xFF1A1A1A),
                        ),
                        onChanged: (value) {
                          timeLimit = int.tryParse(value) ?? timeLimit;
                        },
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14.0,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Update the rule in database
                              if (selectedRuleType != null &&
                                  rule['id'] != null) {
                                String ruleTitle;
                                String ruleSubtitle;

                                if (selectedRuleType == 'App Time Limit' &&
                                    selectedApp != null) {
                                  ruleTitle = '$selectedApp Time Limit';
                                  ruleSubtitle =
                                      'Limited to $timeLimit minutes';
                                } else if (selectedRuleType ==
                                    'Daily Screen Time') {
                                  ruleTitle = 'Daily Screen Limit';
                                  ruleSubtitle = '$timeLimit minutes per day';
                                } else if (selectedRuleType == 'App Lock') {
                                  ruleTitle = 'App Lock';
                                  ruleSubtitle =
                                      'Full device lock - PIN required';
                                } else {
                                  ruleTitle = 'Bedtime Lock';
                                  ruleSubtitle = '10:00 PM - 7:00 AM';
                                }

                                // Update in database
                                final success = await SupabaseRules.updateRule(
                                  ruleId: rule['id'],
                                  title: ruleTitle,
                                  subtitle: ruleSubtitle,
                                  timeLimitMinutes: timeLimit,
                                );

                                if (success) {
                                  // Refresh rules from database
                                  await _fetchRulesFromDatabase();

                                  // Reload enforcement service
                                  // Parent dashboard - rules will auto-sync to child device
                                  print(
                                    '✅ Rule deleted - child device will update automatically',
                                  );

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '✅ Rule updated successfully',
                                        ),
                                        backgroundColor: Color(0xFF58C16D),
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '❌ Failed to update rule',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF666666),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14.0,
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Update Rule',
                              style: GoogleFonts.inter(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRuleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required Function(bool) onToggle,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: icon.fontFamily == 'FontAwesomeSolid' ||
                          icon.fontFamily == 'FontAwesomeBrands'
                      ? FaIcon(icon, color: const Color(0xFF1A1A1A), size: 24.0)
                      : Icon(icon, color: const Color(0xFF1A1A1A), size: 24.0),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isActive,
                  onChanged: onToggle,
                  activeColor: const Color(0xFF58C16D),
                  activeTrackColor: const Color(0xFF58C16D),
                  inactiveTrackColor: const Color(0xFFE0E0E0),
                  inactiveThumbColor: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18.0),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1A1A),
                      side: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                InkWell(
                  onTap: onDelete,
                  child: Container(
                    width: 44.0,
                    height: 44.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFEF5350),
                      size: 20.0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  IconData _getAppIcon(String appName) {
    switch (appName) {
      case 'Instagram':
        return FontAwesomeIcons.instagram;
      case 'Facebook':
        return FontAwesomeIcons.facebook;
      case 'Twitter':
        return FontAwesomeIcons.twitter;
      case 'TikTok':
        return FontAwesomeIcons.tiktok;
      case 'Snapchat':
        return FontAwesomeIcons.snapchat;
      case 'WhatsApp':
        return FontAwesomeIcons.whatsapp;
      case 'Telegram':
        return FontAwesomeIcons.telegram;
      case 'YouTube':
        return FontAwesomeIcons.youtube;
      case 'Netflix':
        return Icons.movie_outlined;
      case 'Spotify':
        return FontAwesomeIcons.spotify;
      case 'Chrome':
        return FontAwesomeIcons.chrome;
      case 'Safari':
        return FontAwesomeIcons.safari;
      default:
        return Icons.apps;
    }
  }

  List<String> _getAppsForCategory(String? category) {
    switch (category) {
      case 'Social Media':
        return ['Instagram', 'Facebook', 'Twitter', 'TikTok', 'Snapchat'];
      case 'Messaging':
        return ['WhatsApp', 'Telegram', 'Signal', 'Messenger'];
      case 'Entertainment':
        return ['YouTube', 'Netflix', 'Spotify', 'Prime Video'];
      case 'Gaming':
        return ['PUBG', 'Free Fire', 'Candy Crush', 'Clash of Clans'];
      case 'Browsers':
        return ['Chrome', 'Safari', 'Firefox', 'Edge'];
      default:
        return [];
    }
  }

  // Helper method to format time ago
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  Widget _buildLocationHistoryItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String duration,
    required String time,
  }) {
    return Row(
      children: [
        // Icon Container
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        // Location Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                duration,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Time
        Text(
          time,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRulesTab() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                16.0,
                16.0,
                16.0,
                0.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Dynamic Rule Cards
                  ...rules.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> rule = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < rules.length - 1 ? 16.0 : 0.0,
                      ),
                      child: _buildRuleCard(
                        icon: rule['icon'],
                        title: rule['title'],
                        subtitle: rule['subtitle'],
                        isActive: rule['isActive'],
                        onToggle: (value) async {
                          // Update in database
                          if (rule['id'] != null) {
                            final success = await SupabaseRules.toggleRule(
                              rule['id'],
                              value,
                            );

                            if (success) {
                              setState(() {
                                rules[index]['isActive'] = value;
                              });
                              // Reload rules on child device
                              await AppLockService().refreshLockedPackages();
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('❌ Failed to update rule'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        onEdit: () {
                          _showEditRuleDialog(index);
                        },
                        onDelete: () async {
                          // Delete from database
                          if (rule['id'] != null) {
                            final success = await SupabaseRules.deleteRule(
                              rule['id'],
                            );

                            if (success) {
                              setState(() {
                                rules.removeAt(index);
                              });
                              await AppLockService().refreshLockedPackages();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Rule deleted'),
                                    backgroundColor: Color(0xFF58C16D),
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('❌ Failed to delete rule'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    );
                  }),

                  if (rules.isNotEmpty) const SizedBox(height: 24.0),

                  // Add Rule Button
                  SizedBox(
                    width: MediaQuery.sizeOf(context).width,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showAddRuleDialog();
                      },
                      icon: const Icon(
                        Icons.add,
                        size: 24.0,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Add Rule',
                        style: GoogleFonts.inter(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppsTab() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _appSearchController,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).iconTheme.color,
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          Expanded(
            child: _isLoadingApps
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF58C16D)),
                        SizedBox(height: 12),
                        Text(
                          'Loading apps...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _appsError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.apps,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _appsError!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _fetchInstalledApps,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF58C16D),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredApps.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.apps,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _appSearchController.text.isNotEmpty
                                        ? 'No apps found matching "${_appSearchController.text}"'
                                        : 'No apps found',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _appSearchController.text.isNotEmpty
                                        ? 'Try a different search term'
                                        : 'Tap reload to refresh the app list',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _fetchInstalledApps,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Reload'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF58C16D),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredApps.length,
                            itemBuilder: (context, i) {
                              final app = _filteredApps[i];
                              final appName =
                                  app['appName']?.toString() ?? 'Unknown';
                              final packageName =
                                  (app['packageName'] as String?)?.trim() ?? '';

                              final rule = _getRuleForPackage(
                                packageName,
                                requireActive: false,
                              );
                              final isActive = rule != null &&
                                  ((rule['is_active'] ?? rule['isActive']) ==
                                      true);
                              final hasPin = _ruleHasPin(rule);

                              return ListTile(
                                leading: app['icon'] != null
                                    ? Image.memory(app['icon'], width: 40)
                                    : Icon(
                                        Icons.android,
                                        color:
                                            Theme.of(context).iconTheme.color,
                                      ),
                                title: Text(
                                  appName,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                  ),
                                ),
                                subtitle: Text(
                                  packageName,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                ),
                                onTap: () async {
                                  // open lock flow if you want whole-row tap to set lock
                                  await _onLockApp(app);
                                  // refresh rules AFTER the lock action completes
                                  await _fetchRulesFromDatabase();
                                  await AppLockService()
                                      .refreshLockedPackages();
                                  setState(() {}); // refresh UI
                                },
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch.adaptive(
                                      value: isActive,
                                      onChanged: hasPin
                                          ? (value) async {
                                              final success =
                                                  await SupabaseRules
                                                      .updateRuleActiveState(
                                                packageName: packageName,
                                                deviceId: widget.deviceId ?? '',
                                                activate: value,
                                              );
                                              if (success) {
                                                await _fetchRulesFromDatabase();
                                                await AppLockService()
                                                    .refreshLockedPackages();
                                              } else {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Failed to update lock state',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                              setState(() {});
                                            }
                                          : null, // disabled if pin not set
                                      activeColor: const Color(0xFF58C16D),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!hasPin) // Show Set PIN when no PIN is set
                                      ElevatedButton(
                                        onPressed: () async {
                                          await _onLockApp(app);
                                          await _fetchRulesFromDatabase();
                                          await AppLockService()
                                              .refreshLockedPackages();
                                          setState(() {});
                                        },
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(72, 36),
                                          backgroundColor:
                                              const Color(0xFF666666),
                                        ),
                                        child: const Text('Set PIN'),
                                      )
                                    else
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF58C16D),
                                        size: 20,
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  // Return a rule for a package. If [requireActive] is true, only return an active rule.
  Map<String, dynamic>? _getRuleForPackage(
    String? packageName, {
    bool requireActive = false,
  }) {
    if (packageName == null || packageName.isEmpty) return null;
    try {
      for (final r in rules) {
        final rt = (r['rule_type'] ?? r['rule_type'])?.toString();
        final pkg =
            (r['app_package_name'] ?? r['app_package_name'])?.toString();
        if (rt != 'App Lock') continue;
        if (pkg != packageName) continue;
        final active = (r['isActive'] ?? r['is_active']) == true;
        if (requireActive && !active) continue;
        return Map<String, dynamic>.from(r);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _ruleHasPin(Map<String, dynamic>? rule) {
    if (rule == null || rule.isEmpty) return false;
    // check multiple possible keys depending on how you stored it:
    final hasPinField = rule['app_lock_pin'] ??
        rule['appLockPin'] ??
        rule['app_lock_pin_set'] ??
        rule['appLockPinSet'] ??
        rule['pin_code'];
    if (hasPinField == null) return false;
    if (hasPinField is bool) return hasPinField;
    if (hasPinField is String) return hasPinField.trim().isNotEmpty;
    return true;
  }

  Future<String?> _showPinInputDialog(BuildContext context) async {
    final pinController = TextEditingController();
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set App PIN', textAlign: TextAlign.center),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '4-digit PIN',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final pin = pinController.text.trim();
                if (pin.length != 4 || int.tryParse(pin) == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('PIN must be 4 digits'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop(pin);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onLockApp(Map<String, dynamic> app) async {
    final appName = (app['appName'] ?? 'Unknown').toString();
    String? packageName = (app['packageName'] as String?)?.trim();

    if (packageName == null || packageName.isEmpty) {
      try {
        packageName = await SupabaseRules.getPackageName(appName);
      } catch (_) {
        packageName = null;
      }
    }

    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No device selected'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Ask parent to set a PIN for this app
    final pin = await _showPinInputDialog(context);
    if (pin == null) return; // cancelled

    final supabase = Supabase.instance.client;
    final parentId = supabase.auth.currentUser?.id;
    if (parentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Please log in first'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Adding app lock...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      final success = await SupabaseRules.addRule(
        deviceId: widget.deviceId!,
        parentId: parentId,
        ruleType: 'App Lock',
        title: '$appName Lock',
        subtitle: 'App locked - PIN required',
        appCategory: null,
        appName: appName,
        appPackageName: packageName,
        timeLimitMinutes: 0,
        bedtimeStart: null,
        bedtimeEnd: null,
        isActive: true,
        appLockPin: pin,
      );

      if (mounted) {
        if (success) {
          await _fetchRulesFromDatabase();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ App locked successfully'),
              backgroundColor: Color(0xFF58C16D),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to lock app'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, st) {
      print('❌ Error adding app lock: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _getCallTypeIconData(String iconName) {
    switch (iconName) {
      case 'call_received':
        return Icons.call_received;
      case 'call_made':
        return Icons.call_made;
      case 'call_missed':
        return Icons.call_missed;
      case 'call_end':
        return Icons.call_end;
      case 'block':
        return Icons.block;
      case 'voicemail':
        return Icons.voicemail;
      case 'wifi_calling':
        return Icons.wifi_calling;
      case 'phone':
      default:
        return Icons.phone;
    }
  }

  Widget _buildCallsTab() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _fetchCallLogs,
        color: const Color(0xFF58C16D),
        child: Builder(
          builder: (context) {
            if (_isLoadingCallLogs) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                children: const [
                  SizedBox(height: 40),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF58C16D)),
                        SizedBox(height: 12),
                        Text(
                          'Loading call logs...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 400),
                ],
              );
            }

            if (_callLogsError != null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_missed,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _callLogsError!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _fetchCallLogs,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF58C16D),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 300),
                ],
              );
            }

            if (_callLogs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No call logs found',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Pull down to refresh or tap reload',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _fetchCallLogs,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reload'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF58C16D),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 300),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              itemCount: _callLogs.length + 1,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_callLogs.length} Calls',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        if (_isLoadingCallLogs)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF58C16D),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                final call = _callLogs[index - 1];
                final iconName = (call['call_type_icon'] as String?) ?? 'phone';
                final iconData = _getCallTypeIconData(iconName);
                final callType = call['call_type'] as String? ?? 'Unknown';
                final number = call['number'] as String? ?? 'Unknown';
                final name = call['name'] as String? ?? 'Unknown';
                final duration = call['duration'] is int
                    ? call['duration'] as int
                    : int.tryParse('${call['duration']}') ?? 0;

                DateTime? timestamp;
                final ts = call['timestamp'];
                if (ts is DateTime) {
                  timestamp = ts;
                } else if (ts is String) {
                  timestamp = DateTime.tryParse(ts);
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 0.0,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8E8E8),
                    child: Icon(iconData, color: const Color(0xFF1A1A1A)),
                  ),
                  title: Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        number,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            CallLogsService.formatDuration(duration),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CallLogsService.formatTimestamp(timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        callType,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationTab() {
    return RefreshIndicator(
      onRefresh: _fetchLocationData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last Known Location Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Known Location',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isLoadingLocation)
                      const Center(child: CircularProgressIndicator())
                    else if (_latestLocation == null)
                      const Center(child: Text('No location data available'))
                    else
                      Column(
                        children: [
                          /* ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: FlutterFlowStaticMap(
                              location: LatLng(
                                _latestLocation!['latitude'],
                                _latestLocation!['longitude'],
                              ),
                              apiKey:
                                  'pk.eyJ1IjoiZGVlcDEyMSIsImEiOiJjbHgxMDUzbWswZnB2MmtvNmY2OTI0aDBiIn0.DOPP_s7cTzW_iU2bAard1w',
                              style: mapbox.MapBoxStyle.Streets,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              zoom: 15,
                            ),
                          ),*/
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.navigation,
                                  color: Color(0xFF58C16D),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _latestLocation!['address'] ??
                                            'Unknown Location',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Last updated ${_formatTimeAgo(DateTime.parse(_latestLocation!['recorded_at']))}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final lat = _latestLocation!['latitude'];
                                final lng = _latestLocation!['longitude'];
                                final url = Uri.parse(
                                  'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                }
                              },
                              icon: const Icon(
                                Icons.navigation,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                'Get Directions',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A1A1A),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Location History Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location History',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isLoadingLocation)
                      const Center(child: CircularProgressIndicator())
                    else if (_locationHistory.isEmpty)
                      const Center(child: Text('No location history available'))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _locationHistory.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 32),
                        itemBuilder: (context, index) {
                          final location = _locationHistory[index];
                          final recordedAt = DateTime.parse(
                            location['recorded_at'],
                          );
                          final timeAgo = _formatTimeAgo(recordedAt);
                          final timeStr = DateFormat(
                            'h:mm a',
                          ).format(recordedAt);
                          final address =
                              location['address'] ?? 'Unknown Location';

                          return _buildLocationHistoryItem(
                            icon: Icons.location_on_outlined,
                            iconColor: const Color(0xFF1A1A1A),
                            iconBgColor: const Color(0xFFF5F5F5),
                            title: address,
                            duration: timeAgo,
                            time: timeStr,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(child: Text(title, style: const TextStyle(fontSize: 20)));
  }

  // ==================== SCREEN RECORDING TAB ====================

  Widget _buildScreenRecordingTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchRecordingSettings();
        await _fetchScreenRecordings();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============== SCREEN RECORDING (captures what child sees) ==============
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.screen_share,
                          color: _isScreenRecordingEnabled
                              ? Colors.green
                              : Colors.deepPurple,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Screen Recording',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      fontFamily: 'Readex Pro',
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Record what child sees on screen while using other apps',
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      fontFamily: 'Readex Pro',
                                      color: Colors.grey,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Enable/Disable Screen Recording Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isScreenRecordingEnabled
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isScreenRecordingEnabled
                              ? Colors.green.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isScreenRecordingEnabled
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: _isScreenRecordingEnabled
                                    ? Colors.green
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isScreenRecordingEnabled
                                    ? 'Screen Recording ON'
                                    : 'Screen Recording OFF',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _isScreenRecordingEnabled
                                      ? Colors.green.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isScreenRecordingEnabled,
                            onChanged: _isLoadingRecordingSettings
                                ? null
                                : (value) =>
                                    _toggleScreenRecordingEnabled(value),
                            activeThumbColor: Colors.green,
                          ),
                        ],
                      ),
                    ),

                    // Active recording indicator
                    if (_isScreenRecordingEnabled)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Recording child\'s screen activity. Videos upload to Google Drive in 5-min segments.',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.deepPurple.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Continuously records the child\'s screen when they use other apps (WhatsApp, Instagram, YouTube, etc).\n\n'
                              '• Records in 5-minute segments uploaded to Google Drive\n'
                              '• Works when device is unlocked and screen is ON\n'
                              '• Pauses when screen turns off, resumes on unlock\n'
                              '• Child must grant screen recording permission once',
                              style: TextStyle(
                                color: Colors.deepPurple.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Google Drive Permission
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildPermissionRow(
                      'Google Drive',
                      _isGoogleDriveConnected,
                      () async {
                        try {
                          await platform.invokeMethod(
                            'requestGoogleDrivePermission',
                          );
                        } catch (e) {
                          print('Error requesting Drive: $e');
                        }
                      },
                      subtitle: _googleDriveAccount,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recordings List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recorded Videos',
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        fontFamily: 'Readex Pro',
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    await _fetchScreenRecordings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Recordings List
            if (_isLoadingRecordings)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_screenRecordings.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recordings yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enable recording to start capturing screen activity from the child\'s device',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _screenRecordings.length,
                itemBuilder: (context, index) {
                  final recording = _screenRecordings[index];
                  return _buildRecordingItem(recording);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow(
    String title,
    bool isGranted,
    VoidCallback onRequest, {
    String? subtitle,
  }) {
    return Row(
      children: [
        Icon(
          isGranted ? Icons.check_circle : Icons.error_outline,
          color: isGranted ? Colors.green : Colors.orange,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14)),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        if (!isGranted)
          TextButton(
            onPressed: onRequest,
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Grant'),
          ),
      ],
    );
  }

  Widget _buildRecordingItem(Map<String, dynamic> recording) {
    final fileName = recording['file_name'] ?? 'Unknown';
    final recordedAt = recording['recorded_at'];
    final status = recording['status'] ?? 'unknown';
    final driveLink = recording['drive_link'];
    final driveFileId = recording['drive_file_id'];
    final fileSize = recording['file_size'] ?? 0;
    final durationSeconds = recording['duration_seconds'] ?? 0;

    // Parse date
    String formattedDate = '';
    if (recordedAt != null) {
      try {
        final date = DateTime.parse(recordedAt);
        formattedDate =
            '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedDate = recordedAt.toString();
      }
    }

    // Format file size
    String formattedSize = '';
    if (fileSize > 0) {
      if (fileSize > 1024 * 1024) {
        formattedSize = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else if (fileSize > 1024) {
        formattedSize = '${(fileSize / 1024).toStringAsFixed(1)} KB';
      } else {
        formattedSize = '$fileSize B';
      }
    }

    // Format duration
    String formattedDuration = '';
    if (durationSeconds > 0) {
      final minutes = durationSeconds ~/ 60;
      final seconds = durationSeconds % 60;
      formattedDuration = '${minutes}m ${seconds}s';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: driveLink != null && driveLink.toString().isNotEmpty
            ? () => _showVideoPlayerDialog(driveLink, driveFileId, fileName)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Video thumbnail/icon with play button overlay
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: status == 'uploaded'
                          ? Colors.blue.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.videocam,
                      size: 32,
                      color: status == 'uploaded' ? Colors.blue : Colors.orange,
                    ),
                  ),
                  if (status == 'uploaded' && driveLink != null)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Info section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (formattedDuration.isNotEmpty) ...[
                          Icon(
                            Icons.timer,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDuration,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (formattedSize.isNotEmpty) ...[
                          Icon(
                            Icons.data_usage,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedSize,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'uploaded')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_done,
                            size: 12,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Uploaded',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (status == 'failed')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 12,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Failed',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.orange.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (driveLink != null && driveLink.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20),
                      color: Colors.blue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _openDriveLink(driveLink),
                      tooltip: 'Open in browser',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoPlayerDialog(
    String driveLink,
    String? driveFileId,
    String fileName,
  ) {
    // Create a preview/embed link for Google Drive video
    String? previewUrl;
    if (driveFileId != null && driveFileId.isNotEmpty) {
      // Google Drive preview URL
      previewUrl = 'https://drive.google.com/file/d/$driveFileId/preview';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.95,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Video content
              Flexible(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_circle_outline,
                          size: 80,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tap to play video in browser',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play Video'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openDriveLink(driveLink);
                          },
                        ),
                        if (previewUrl != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.preview),
                            label: const Text('Preview in Drive'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _openDriveLink(previewUrl!);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Footer with actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Open in Browser'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openDriveLink(driveLink);
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share Link'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: driveLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDriveLink(String link) async {
    try {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error opening link: $e');
    }
  }

  // ==================== VPN TAB METHODS ====================

  /// Fetch blocked URLs from Supabase
  Future<void> _fetchBlockedUrls() async {
    if (widget.deviceId == null || widget.deviceId!.isEmpty) return;

    setState(() => _isLoadingBlockedUrls = true);

    try {
      final response = await Supabase.instance.client
          .from('blocked_urls')
          .select()
          .eq('device_id', widget.deviceId!)
          .eq('is_active', true)
          .order('blocked_at', ascending: false);

      setState(() {
        _blockedUrls = List<Map<String, dynamic>>.from(response);
        _isLoadingBlockedUrls = false;
      });
      print('✅ Loaded ${_blockedUrls.length} blocked URLs');
    } catch (e) {
      print('❌ Failed to fetch blocked URLs: $e');
      setState(() => _isLoadingBlockedUrls = false);
    }
  }

  /// Fetch search history from Supabase
  Future<void> _fetchSearchHistory() async {
    print('🔍 Fetching search history...');
    print('   Device ID: ${widget.deviceId}');

    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      print('⚠️ No device ID provided for search history');
      return;
    }

    setState(() => _isLoadingSearchHistory = true);

    try {
      print('📡 Querying search_history table for device: ${widget.deviceId}');

      final response = await Supabase.instance.client
          .from('search_history')
          .select()
          .eq('device_id', widget.deviceId!)
          .order('visited_at', ascending: false)
          .limit(25);

      print('📡 Response received: ${response.length} items');

      if (response.isEmpty) {
        print('⚠️ No search history found for device: ${widget.deviceId}');
      } else {
        print('✅ First item: ${response.first}');
      }

      setState(() {
        _searchHistory = List<Map<String, dynamic>>.from(response);
        _isLoadingSearchHistory = false;
      });
      print('✅ Loaded ${_searchHistory.length} search history items');
    } catch (e) {
      print('❌ Failed to fetch search history: $e');
      setState(() => _isLoadingSearchHistory = false);
    }
  }

  /// Block a URL
  Future<void> _blockUrl(String url) async {
    if (widget.deviceId == null || widget.deviceId!.isEmpty) return;
    if (url.trim().isEmpty) return;

    // Clean URL - ensure it has a proper format
    String cleanUrl = url.trim().toLowerCase();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    try {
      // Check if URL is already blocked
      final existing = _blockedUrls.where((u) => u['url'] == cleanUrl).toList();
      if (existing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This URL is already blocked'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      print('🔒 Blocking URL for device ID: ${widget.deviceId}');
      await Supabase.instance.client.from('blocked_urls').insert({
        'device_id': widget.deviceId,
        'url': cleanUrl,
        'blocked_by': Supabase.instance.client.auth.currentUser?.id,
        'is_active': true,
      });

      print('✅ URL blocked: $cleanUrl for device: ${widget.deviceId}');
      _urlInputController.clear();
      await _fetchBlockedUrls();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Blocked: $cleanUrl'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to block URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to block URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Unblock a URL
  Future<void> _unblockUrl(String urlId) async {
    try {
      await Supabase.instance.client
          .from('blocked_urls')
          .update({'is_active': false}).eq('id', urlId);

      print('✅ URL unblocked');
      await _fetchBlockedUrls();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL unblocked successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to unblock URL: $e');
    }
  }

  /// Build the VPN tab with URL blocking
  Widget _buildVpnTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchBlockedUrls();
        await _fetchSearchHistory();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Debug info section
            /*   Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Info:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue[800]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Device ID: ${widget.deviceId ?? "Not set"}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                  Text(
                    'History Count: ${_searchHistory.length}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _insertTestHistoryEntry,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Test Entry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _fetchSearchHistory();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Refreshed history')),
                          );
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
*/
            // URL Blocking Section
            _buildSectionHeader('URL Blocking', Icons.block_outlined),
            const SizedBox(height: 12),
            _buildUrlInputSection(),
            const SizedBox(height: 24),

            // Blocked URLs Section
            _buildSectionHeader('Blocked URLs', Icons.lock_outline),
            const SizedBox(height: 12),
            _buildBlockedUrlsList(),
            const SizedBox(height: 24),

            // Search History Section
            _buildSectionHeader('Search History', Icons.history_outlined),
            const SizedBox(height: 12),
            _buildSearchHistoryList(),
          ],
        ),
      ),
    );
  }

  /// Insert a test history entry for debugging
  Future<void> _insertTestHistoryEntry() async {
    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No device ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final testUrl =
          'https://test-${DateTime.now().millisecondsSinceEpoch}.com';
      await Supabase.instance.client.from('search_history').insert({
        'device_id': widget.deviceId,
        'url': testUrl,
        'title': 'Test Entry - ${DateTime.now().toString()}',
        'visited_at': DateTime.now().toIso8601String(),
        'visit_count': 1,
      });

      print('✅ Test entry inserted: $testUrl');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test entry added!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the list
      await _fetchSearchHistory();
    } catch (e) {
      print('❌ Failed to insert test entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Build section header
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: FlutterFlowTheme.of(context).primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: FlutterFlowTheme.of(context).titleMedium.override(
                fontFamily: 'Readex Pro',
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  /// Build URL input section
  Widget _buildUrlInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter website URL to block',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: 'Readex Pro',
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlInputController,
                  decoration: InputDecoration(
                    hintText: 'e.g., facebook.com',
                    prefixIcon: const Icon(Icons.link, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: FlutterFlowTheme.of(context).primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (value) => _blockUrl(value),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _blockUrl(_urlInputController.text),
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Block'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build blocked URLs list
  Widget _buildBlockedUrlsList() {
    if (_isLoadingBlockedUrls) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_blockedUrls.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No blocked URLs',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add URLs above to block them on child\'s device',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _blockedUrls.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final blockedUrl = _blockedUrls[index];
          final url = blockedUrl['url'] ?? '';
          final blockedAt = blockedUrl['blocked_at'] != null
              ? DateTime.parse(blockedUrl['blocked_at'])
              : DateTime.now();
          final timeAgo = _formatTimeAgo(blockedAt);

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.block, color: Colors.red[600], size: 20),
            ),
            title: Text(
              url,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Blocked $timeAgo',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _showUnblockConfirmation(blockedUrl),
            ),
          );
        },
      ),
    );
  }

  /// Build search history list
  Widget _buildSearchHistoryList() {
    if (_isLoadingSearchHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No search history',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Child\'s browsing history will appear here',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchHistory.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final historyItem = _searchHistory[index];
          final url = historyItem['url'] ?? '';
          final title = historyItem['title'] ?? url;
          final visitedAt = historyItem['visited_at'] != null
              ? DateTime.parse(historyItem['visited_at'])
              : DateTime.now();
          final timeAgo = _formatTimeAgo(visitedAt);
          final isBlocked = _blockedUrls.any((b) => b['url'] == url);

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.public, color: Colors.blue[600], size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$url • $timeAgo',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isBlocked
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Blocked',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: () => _blockUrl(url),
                    icon: Icon(Icons.block, size: 16, color: Colors.red[600]),
                    label: Text(
                      'Block',
                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
          );
        },
      ),
    );
  }

  /// Show unblock confirmation dialog
  void _showUnblockConfirmation(Map<String, dynamic> blockedUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock URL?'),
        content: Text(
          'Are you sure you want to unblock "${blockedUrl['url']}"?\n\nThe child will be able to access this website again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _unblockUrl(blockedUrl['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }
}
