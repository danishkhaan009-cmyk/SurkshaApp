import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '/services/location_tracking_service.dart';
import '/services/child_mode_service.dart';
import '/services/installed_apps_service.dart';
import '/services/call_logs_service.dart';
import '/services/device_setup_service.dart';
import 'child_device_setup5_model.dart';
import 'permission_card_widget.dart';
export 'child_device_setup5_model.dart';

class ChildDeviceSetup5Widget extends StatefulWidget {
  const ChildDeviceSetup5Widget({super.key});

  static String routeName = 'Child_Device_Setup5';
  static String routePath = '/childDeviceSetup5';

  @override
  State<ChildDeviceSetup5Widget> createState() =>
      _ChildDeviceSetup5WidgetState();
}

class _ChildDeviceSetup5WidgetState extends State<ChildDeviceSetup5Widget> {
  late ChildDeviceSetup5Model _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Permission states
  bool _locationPermissionGranted = false;
  bool _accessibilityPermissionGranted = false;
  bool _usageAccessPermissionGranted = false;
  bool _deviceAdminPermissionGranted = false;
  bool _notificationPermissionGranted = false;
  bool _overlayPermissionGranted = false; // For App Lock screen
  int _grantedCount = 0;

  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChildDeviceSetup5Model());
    _checkPermissions();

    _permissionCheckTimer =
        Timer.periodic(const Duration(seconds: 20), (timer) {
      _checkPermissions();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final queryParams = GoRouterState.of(context).uri.queryParameters;
      if (queryParams['isReentry'] == 'true') {
        _exitChildMode();
      }
      _startChildMode();

      // Get deviceId from query params or fallback to setup data
      String? deviceId = queryParams['deviceId'];
      if (deviceId == null || deviceId.isEmpty) {
        final setupData = DeviceSetupService.getSetupData();
        final pairingCode = setupData['pairingCode'];
        if (pairingCode != null) {
          final device =
              await DeviceSetupService.getDeviceByPairingCode(pairingCode);
          deviceId = device?['id'] as String?;
        }
      }

      if (deviceId != null && deviceId.isNotEmpty) {
        InstalledAppsService.syncInstalledApps(deviceId);
        CallLogsService.syncCallLogs(deviceId);
        LocationTrackingService().startTracking(deviceId);
        // Future.delayed(const Duration(seconds: 2));
        // LocationTrackingService().triggerLocationUpdate();

        // Location sync is now handled by LocationTrackingService
      }
    });
  }

  Future<void> _checkPermissions() async {
    final locationStatus = await Geolocator.checkPermission();
    final accessibilityGranted =
        await PermissionService.isAccessibilityEnabled();
    final usageAccessGranted = await PermissionService.isUsageAccessGranted();
    final deviceAdminGranted = await PermissionService.isDeviceAdminEnabled();
    final notificationGranted =
        await PermissionService.isNotificationAccessGranted();
    final overlayGranted = await PermissionService.isOverlayPermissionGranted();

    if (mounted) {
      setState(() {
        _locationPermissionGranted =
            locationStatus == LocationPermission.always ||
                locationStatus == LocationPermission.whileInUse;
        _accessibilityPermissionGranted = accessibilityGranted;
        _usageAccessPermissionGranted = usageAccessGranted;
        _deviceAdminPermissionGranted = deviceAdminGranted;
        _notificationPermissionGranted = notificationGranted;
        _overlayPermissionGranted = overlayGranted;
        _updateGrantedCount();
      });
    }
  }

  void _updateGrantedCount() {
    _grantedCount = 0;
    if (_locationPermissionGranted) _grantedCount++;
    if (_accessibilityPermissionGranted) _grantedCount++;
    if (_usageAccessPermissionGranted) _grantedCount++;
    if (_deviceAdminPermissionGranted) _grantedCount++;
    if (_notificationPermissionGranted) _grantedCount++;
    if (_overlayPermissionGranted) _grantedCount++;
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
    await _checkPermissions();
    if (_locationPermissionGranted) {
      await _startChildMode();
    }
  }

  Future<void> _startChildMode() async {
    try {
      final queryParams = GoRouterState.of(context).uri.queryParameters;
      String? deviceId = queryParams['deviceId'];

      // Fallback: Try to get deviceId from setup data via pairing code
      if (deviceId == null || deviceId.isEmpty) {
        final setupData = DeviceSetupService.getSetupData();
        final pairingCode = setupData['pairingCode'];
        if (pairingCode != null) {
          final device =
              await DeviceSetupService.getDeviceByPairingCode(pairingCode);
          deviceId = device?['id'] as String?;
          print('📱 Retrieved deviceId from pairing code: $deviceId');
        }
      }

      if (deviceId == null || deviceId.isEmpty) {
        print('❌ No deviceId available - cannot activate child mode');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Device setup incomplete. Please restart setup.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final supabase = Supabase.instance.client;
      final deviceResponse = await supabase
          .from('devices')
          .select('user_id')
          .eq('id', deviceId)
          .single();
      final userId = deviceResponse['user_id'] as String?;
      if (userId == null) return;

      final profileResponse = await supabase
          .from('profiles')
          .select('pin')
          .eq('id', userId)
          .single();
      final pin = profileResponse['pin'] as String? ?? '';

      await ChildModeService.activateChildMode(deviceId, pin);
      //await LocationTrackingService().startTracking(deviceId);

      // Start periodic app sync
      InstalledAppsService.startPeriodicSync(deviceId);

      // Start periodic call logs sync
      CallLogsService.startPeriodicCallLogsSync(deviceId);

      if (mounted) {
        await RulesEnforcementService.initialize(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Child mode activated'),
              backgroundColor: Color(0xFF58C16D)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _requestAccessibilityPermission() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Accessibility'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                '1. Tap "Open Settings"\n2. Find "SurakshaApp" in the list\n3. Turn the switch to "ON"'),
            const SizedBox(height: 16),
            Text(
              '⚠️ Note: If disabled, go to Phone Settings > Apps > SurakshaApp > (⋮) > "Allow restricted settings" and try again.',
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF58C16D)),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (proceed == true) {
      await PermissionService.requestAccessibilityPermission();
    }
  }

  Future<void> _requestUsageAccessPermission() async {
    await PermissionService.requestUsageAccessPermission();
  }

  Future<void> _requestDeviceAdminPermission() async {
    await PermissionService.requestDeviceAdminPermission();
  }

  Future<void> _requestNotificationPermission() async {
    await PermissionService.requestNotificationPermission();
  }

  Future<void> _requestOverlayPermission() async {
    await PermissionService.requestOverlayPermission();
  }

  Future<void> _exitChildMode() async {
    try {
      String? deviceId =
          GoRouterState.of(context).uri.queryParameters['deviceId'] ??
              await ChildModeService.getChildDeviceId();
      if (deviceId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('❌ Device ID not found.')));
        }
        return;
      }

      final supabase = Supabase.instance.client;
      final deviceResponse = await supabase
          .from('devices')
          .select('user_id')
          .eq('id', deviceId)
          .single();
      final userId = deviceResponse['user_id'] as String?;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('❌ Parent not found for this device.')));
        }
        return;
      }

      final profileResponse = await supabase
          .from('profiles')
          .select('pin')
          .eq('id', userId)
          .single();
      final pin = profileResponse['pin'] as String?;
      if (pin == null || pin.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('❌ No PIN set by parent.')));
        }
        return;
      }

      if (mounted) _showExitPinDialog(pin, deviceId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
      }
    }
  }

  void _showExitPinDialog(String correctPin, String deviceId) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Exit Child Mode'),
        content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text == correctPin) {
                await LocationTrackingService().stopTracking();
                try {
                  await Supabase.instance.client.from('devices').update({
                    'active_device_identifier': null,
                    'last_active_at': null
                  }).eq('id', deviceId);
                } catch (_) {}
                await ChildModeService.deactivateChildMode();
                if (mounted) {
                  Navigator.of(context).pop();
                  context.goNamed(SelectModeWidget.routeName);
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ Incorrect PIN')));
                }
              }
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _exitChildMode();
        return false;
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: const Color(0xFFF6F6F6),
          body: SafeArea(
            top: true,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF58C16D),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.shield_outlined,
                              color: Colors.white, size: 48.0),
                          const SizedBox(height: 12.0),
                          Text('Required Permissions',
                              style: GoogleFonts.inter(
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          const SizedBox(height: 4.0),
                          Text('$_grantedCount of 6 granted',
                              style: GoogleFonts.inter(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: const Color(0xFFBBDEFB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield,
                              color: Color(0xFF2196F3), size: 24.0),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Why These Permissions?',
                                    style: GoogleFonts.inter(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1A1A1A))),
                                const SizedBox(height: 4.0),
                                Text(
                                  'These permissions are required for safety features like app blocking, location tracking, and uninstall protection to work correctly.',
                                  style: GoogleFonts.inter(
                                      fontSize: 13.0, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    PermissionCardWidget(
                        icon: Icons.visibility_outlined,
                        title: 'Accessibility Service',
                        description:
                            'Monitors app usage and prevents uninstall',
                        isGranted: _accessibilityPermissionGranted,
                        onGrantPressed: _requestAccessibilityPermission),
                    PermissionCardWidget(
                        icon: Icons.phone_android_outlined,
                        title: 'Usage Access',
                        description:
                            'Tracks which apps are being used and for how long',
                        isGranted: _usageAccessPermissionGranted,
                        onGrantPressed: _requestUsageAccessPermission),
                    PermissionCardWidget(
                        icon: Icons.lock_outline,
                        title: 'Device Admin',
                        description: 'Prevents unauthorized uninstallation',
                        isGranted: _deviceAdminPermissionGranted,
                        onGrantPressed: _requestDeviceAdminPermission),
                    PermissionCardWidget(
                        icon: Icons.notifications_outlined,
                        title: 'Notification Access',
                        description: 'Monitors chat messages for safety alerts',
                        isGranted: _notificationPermissionGranted,
                        onGrantPressed: _requestNotificationPermission),
                    PermissionCardWidget(
                        icon: Icons.layers_outlined,
                        title: 'Display over other apps',
                        description: 'Required for the App Lock screen to work',
                        isGranted: _overlayPermissionGranted,
                        onGrantPressed: _requestOverlayPermission),
                    PermissionCardWidget(
                        icon: Icons.location_on_outlined,
                        title: 'Location',
                        description: 'Tracks device location for safety',
                        isGranted: _locationPermissionGranted,
                        onGrantPressed: _requestLocationPermission),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _exitChildMode,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F)),
                        icon: const Icon(Icons.exit_to_app, size: 20.0),
                        label: Text('Exit Child Mode',
                            style: GoogleFonts.inter(
                                fontSize: 16.0, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
