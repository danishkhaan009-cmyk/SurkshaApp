import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:without_database/services/child_mode_service.dart';

/// Service to manage app locking when child mode is active
class AppLockService {
  static OverlayEntry? _overlayEntry;
  static bool _isLockActive = false;
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final _channel = const MethodChannel('parental_control/permissions');
  Timer? _pollTimer;
  Set<String> _lockedPackages = <String>{};
  final bool _isShowingLock = false;
  String? deviceId;

  /// Check if app lock should be active
  static Future<bool> shouldLockApps() async {
    return await ChildModeService.isChildModeActive();
  }

  /// Show app lock overlay
  static void showLockOverlay(BuildContext context) {
    if (_isLockActive) return;

    _isLockActive = true;

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF0F1419),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFF58C16D),
                  size: 80,
                ),
                const SizedBox(height: 20),
                const Text(
                  'App Locked',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This app is restricted in child mode',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Remove app lock overlay
  static void removeLockOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isLockActive = false;
    }
  }

  /// Get list of blocked apps (can be extended)
  static Future<List<String>> getBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('blocked_apps') ??
        [
          'com.android.chrome',
          'com.android.settings',
          'com.google.android.youtube',
        ];
  }

  /// Add app to blocked list
  static Future<void> addBlockedApp(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = await getBlockedApps();
    if (!blockedApps.contains(packageName)) {
      blockedApps.add(packageName);
      await prefs.setStringList('blocked_apps', blockedApps);
    }
  }

  /// Remove app from blocked list
  static Future<void> removeBlockedApp(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final blockedApps = await getBlockedApps();
    blockedApps.remove(packageName);
    await prefs.setStringList('blocked_apps', blockedApps);
  }

  /// Check if specific app is blocked
  static Future<bool> isAppBlocked(String packageName) async {
    final blockedApps = await getBlockedApps();
    return blockedApps.contains(packageName);
  }

  /// Clear all blocked apps
  static Future<void> clearBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('blocked_apps');
  }

  void start(
      {required String deviceId,
      Duration interval = const Duration(seconds: 2)}) {
    this.deviceId = deviceId;
    _loadLockedPackages();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _checkForegroundApp());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadLockedPackages() async {
    if (deviceId == null || deviceId!.isEmpty) {
      print('AppLockService: deviceId is null/empty, skipping load.');
      // Try to load from cache
      await _loadFromCache();
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // Fetch pin_code (plain text) for local validation on child device
      final res = await supabase
          .from('device_rules')
          .select('app_package_name, pin_code')
          .eq('device_id', deviceId as Object)
          .eq('rule_type', 'App Lock')
          .eq('is_active', true);

      List<dynamic> rows;
      rows = res;

      final packages = <String>{};
      for (final row in rows) {
        final pkg = (row['app_package_name'] ?? '').toString().trim();
        final pin = (row['pin_code'] ?? '').toString().trim();
        if (pkg.isNotEmpty) {
          packages.add(pkg);
          // Pass the PIN to native service for validation
          if (pin.isNotEmpty) {
            await _channel.invokeMethod('setAppLockPin', {
              'package': pkg,
              'pin': pin,
            });
          }
        }
      }

      _lockedPackages = packages;

      // Store in SharedPreferences for persistence across app restarts
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('locked_packages', _lockedPackages.toList());

      // Sync list with native service
      await _channel.invokeMethod('setLockedApps', {
        'apps': _lockedPackages.toList(),
      });

      print(
          'AppLockService: loaded locked packages: ${_lockedPackages.length}');
    } catch (e, st) {
      print('AppLockService: failed to load locked packages: $e\n$st');
      // Fallback to cached data
      await _loadFromCache();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('locked_packages') ?? [];
      _lockedPackages = cached.toSet();

      if (_lockedPackages.isNotEmpty) {
        // Sync with native service
        await _channel.invokeMethod('setLockedApps', {
          'apps': _lockedPackages.toList(),
        });
        print(
            'AppLockService: loaded ${_lockedPackages.length} packages from cache');
      }
    } catch (e) {
      print('AppLockService: failed to load from cache: $e');
    }
  }

  Future<void> refreshLockedPackages() async => _loadLockedPackages();

  Future<void> _checkForegroundApp() async {
    if (_isShowingLock) return;
    try {
      final pkg = await _channel.invokeMethod<String>('getForegroundApp') ?? '';
      if (pkg.isEmpty) return;
      if (_lockedPackages.contains(pkg)) {
        // Fallback check
      }
    } catch (e) {
      print('AppLockService: error checking foreground app: $e');
    }
  }

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
}
