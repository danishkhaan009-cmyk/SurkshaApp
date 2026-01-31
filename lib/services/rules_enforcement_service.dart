import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '/services/child_mode_service.dart';
import '/services/app_block_bridge.dart';
import '/services/location_tracking_service.dart';
import '/services/app_lock_service.dart';
import '/services/call_logs_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/supabase/supabase_rules.dart';

/// Service to enforce parental control rules dynamically
class RulesEnforcementService {
  static Timer? _enforcementTimer;
  static Timer? _backgroundMonitorTimer;
  static final Map<String, dynamic> _activeRules = {};
  static BuildContext? _appContext;
  static String? _currentDeviceId;

  /// Initialize the rules enforcement service
  static Future<void> initialize(BuildContext context) async {
    _appContext = context;
    _currentDeviceId = await ChildModeService.getChildDeviceId();

    // Verify this is actually a child device before starting enforcement
    final isChildMode = await ChildModeService.isChildModeActive();
    if (!isChildMode) {
      print('⚠️ Not in child mode - skipping rules enforcement initialization');
      return;
    }

    if (_currentDeviceId == null || _currentDeviceId!.isEmpty) {
      print('⚠️ No device ID found - cannot initialize rules enforcement');
      return;
    }

    print('🎯 === CHILD DEVICE VERIFICATION ===');
    print('   Device ID: $_currentDeviceId');
    print('   Child Mode Active: $isChildMode');
    print('   This device WILL enforce rules');
    print('===================================');

    print(
        '✅ Initializing rules enforcement for child device: $_currentDeviceId');

    // Enable native blocking engine (for both App Lock and URL Blocking)
    await AppBlockBridge.setChildMode(true);
    print('🔒 Native blocking engine enabled');

    await loadActiveRules();
    // Start AppLockService to enforce app locks
    AppLockService().start(deviceId: _currentDeviceId!);
    print('🔒 AppLockService started for device: $_currentDeviceId');
    startEnforcement();
    startBackgroundMonitoring();
  }

  /// Start background monitoring - runs every 30 seconds
  static void startBackgroundMonitoring() async {
    // Cancel existing timer if any
    _backgroundMonitorTimer?.cancel();

    print('🔄 Starting background monitoring (every 30 seconds)');

    // Start foreground service (Android only) to keep app alive during monitoring
    if (!kIsWeb) {
      try {
        await AppBlockBridge.startMonitoringService();
        print('✅ Foreground monitoring service started - survives Doze mode');
      } catch (e) {
        print('⚠️ Could not start foreground service: $e');
      }
    }

    // Run immediately on start
    _runBackgroundCheck();

    // Then run every 30 seconds
    _backgroundMonitorTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _runBackgroundCheck(),
    );
  }

  /// Background check - runs every 30 seconds even when phone is locked
  static Future<void> _runBackgroundCheck() async {
    try {
      // Only run on child devices
      final isChildMode = await ChildModeService.isChildModeActive();
      if (!isChildMode) {
        print('⏭️ Background check skipped - not in child mode');
        return;
      }

      final deviceId = await ChildModeService.getChildDeviceId();
      if (deviceId == null) {
        print('⚠️ No device ID found for background check');
        return;
      }

      print('🔍 Running background check for device: $deviceId');

      // 1. Update location to database
      await _updateLocationInBackground(deviceId);

      // 2. Sync call logs to database
      await _syncCallLogsInBackground(deviceId);

      // 3. Reload rules from database (check for changes)
      await loadActiveRules();

      // 4. Refresh app locks to ensure they're enforced
      await AppLockService().refreshLockedPackages();

      // 5. Check and enforce time-based rules
      await _enforceTimeLimitRules();

      print('✅ Background check completed');
    } catch (e) {
      print('❌ Background check error: $e');
    }
  }

  /// Update location in background
  static Future<void> _updateLocationInBackground(String deviceId) async {
    try {
      if (kIsWeb) return; // Skip on web

      final LocationTrackingService locationService = LocationTrackingService();

      // Trigger location update without starting continuous tracking
      await locationService.startTracking(deviceId);

      await locationService.triggerLocationUpdate();

      print('📍 Location updated in background');
    } catch (e) {
      print('⚠️ Location update failed: $e');
    }
  }

  /// Sync call logs in background
  static Future<void> _syncCallLogsInBackground(String deviceId) async {
    try {
      if (kIsWeb) return; // Skip on web

      print('📞 Starting call log sync for device: $deviceId');

      // Sync call logs using CallLogsService
      await CallLogsService.syncCallLogs(deviceId);

      print('✅ Call logs synced in background');
    } catch (e) {
      print('❌ Call log sync failed: $e');
    }
  }

  /// Enforce time limit rules
  static Future<void> _enforceTimeLimitRules() async {
    for (var rule in _activeRules.values) {
      final ruleType = rule['rule_type'] as String?;

      if (ruleType == 'Time Limit') {
        final timeLimit = rule['time_limit_minutes'] as int? ?? 0;
        final startTime = rule['created_at'];

        // Calculate time elapsed
        if (startTime != null) {
          final start = DateTime.parse(startTime);
          final elapsed = DateTime.now().difference(start).inMinutes;

          if (elapsed >= timeLimit) {
            print('⏰ Time limit reached for: ${rule['title']}');
            // Time limit exceeded - could trigger notification or action
          }
        }
      }
    }
  }

  /// Stop background monitoring
  static void stopBackgroundMonitoring() async {
    _backgroundMonitorTimer?.cancel();
    _backgroundMonitorTimer = null;

    // Stop foreground service (Android only)
    if (!kIsWeb) {
      try {
        await AppBlockBridge.stopMonitoringService();
        print('✅ Foreground monitoring service stopped');
      } catch (e) {
        print('⚠️ Could not stop foreground service: $e');
      }
    }

    print('🛑 Background monitoring stopped');
  }

  /// Load active rules from Supabase
  static Future<void> loadActiveRules() async {
    _activeRules.clear();

    // Verify child mode is still active
    final isChildMode = await ChildModeService.isChildModeActive();
    if (!isChildMode) {
      print('⚠️ Not in child mode - clearing any existing rules');
      if (!kIsWeb) {
        await AppBlockBridge.setLockedApps([]);
        await AppBlockBridge.setChildMode(false);
      }
      return;
    }

    if (_currentDeviceId == null || _currentDeviceId!.isEmpty) {
      print('⚠️ No device ID found, skipping rule load');
      return;
    }

    try {
      print('🔍 Loading rules for child device: $_currentDeviceId');
      final rules = await SupabaseRules.getActiveRules(_currentDeviceId!);

      if (rules.isEmpty) {
        print('⚠️ WARNING: NO RULES FOUND for device_id: $_currentDeviceId');
        print('   Check if:');
        print('   1. Rules exist in database');
        print('   2. Rules have correct device_id');
        print('   3. Rules have is_active = true');
      } else {
        for (var rule in rules) {
          String title = rule['title'];
          _activeRules[title] = rule;
          print('   📋 Loaded rule: $title (${rule['rule_type']})');
        }
      }

      print(
          '✅ Loaded ${_activeRules.length} active rules from database for device $_currentDeviceId');

      // Update native Android service with App Lock rules
      // ONLY on Android child devices (not parent dashboard or web)
      if (!kIsWeb) {
        // CRITICAL: Only activate blocking on devices in child mode
        final isChildMode = await ChildModeService.isChildModeActive();
        if (isChildMode) {
          print('✅ Device is in CHILD mode - activating app blocking');
          // Always ensure native blocking engine is enabled for URL blocking
          await AppBlockBridge.setChildMode(true);
          await _updateNativeAppBlockService();
        } else {
          print('⏭️ Device is in PARENT mode - skipping app blocking');
          // Ensure service is disabled on parent devices
          await AppBlockBridge.setLockedApps([]);
          await AppBlockBridge.setChildMode(false);
        }
      } else {
        print('🌐 Web platform - App Lock not available');
      }
    } catch (e) {
      print('❌ Error loading rules: $e');
      // On error, clear locked apps but keep child mode for URL blocking
      if (!kIsWeb) {
        await AppBlockBridge.setLockedApps([]);
        // NOTE: Don't disable child mode on error - URL blocking still needs it
      }
    }
  }

  /// Update native Android AppBlockService with locked app packages
  /// This should ONLY be called on child devices
  static Future<void> _updateNativeAppBlockService() async {
    try {
      // Get all App Lock rules
      final lockedPackages = <String>[];

      for (var rule in _activeRules.values) {
        if (rule['rule_type'] == 'App Lock') {
          final packageName = rule['app_package_name'] as String?;
          if (packageName != null && packageName.isNotEmpty) {
            lockedPackages.add(packageName);
            print('   🔒 Locking app: $packageName (${rule['title']})');
          }
        }
      }

      if (lockedPackages.isEmpty) {
        print(
            '📱 No App Lock rules found - clearing locked apps (keeping URL blocking active)');
        await AppBlockBridge.setLockedApps([]);
        // NOTE: Don't disable child mode here! URL blocking still needs it
        return;
      }

      // Send to native service (only on child device)
      await AppBlockBridge.setLockedApps(lockedPackages);
      await AppBlockBridge.setChildMode(true);

      print(
          '📱 Child device $_currentDeviceId - Updated native service: ${lockedPackages.length} apps locked');
    } catch (e) {
      print('❌ Error updating native service: $e');
    }
  }

  /// Save active rules to SharedPreferences
  static Future<void> saveActiveRules(List<Map<String, dynamic>> rules) async {
    // Filter only active rules
    _activeRules.clear();
    for (var rule in rules) {
      if (rule['isActive'] == true) {
        String title = rule['title'];
        _activeRules[title] = rule;
      }
    }

    print('✅ Saved ${_activeRules.length} active rules');
  }

  /// Start enforcement timer - checks every minute
  static void startEnforcement() {
    _enforcementTimer?.cancel();

    _enforcementTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndEnforceRules();
    });

    print('✅ Rules enforcement started');
  }

  /// Stop enforcement
  static void stopEnforcement() {
    _enforcementTimer?.cancel();
    print('⏸️ Rules enforcement stopped');
  }

  /// Check and enforce all active rules
  static Future<void> _checkAndEnforceRules() async {
    final isChildMode = await ChildModeService.isChildModeActive();
    if (!isChildMode) return;

    final now = DateTime.now();

    for (var entry in _activeRules.entries) {
      final rule = entry.value;
      final ruleType = rule['rule_type'] as String?;

      if (ruleType == 'Bedtime Lock') {
        _enforceBedtimeLock(rule, now);
      } else if (ruleType == 'App Lock') {
        // App Lock ONLY works on Android devices with APK installed
        // Skip completely on web - requires native AccessibilityService
        if (!kIsWeb) {
          _enforceAppLock(rule);
        } else {
          print('⏭️ App Lock skipped - web platform not supported');
        }
      } else if (ruleType == 'Daily Screen Time') {
        _enforceDailyScreenLimit(rule, now);
      } else if (ruleType == 'App Time Limit') {
        _enforceAppTimeLimit(rule, now);
      } else if (ruleType == 'URL Block' || ruleType == 'Website Block') {
        // Add URL blocking enforcement
        if (!kIsWeb) {
          await _enforceUrlBlock(rule);
        }
      }
    }
  }

  /// Enforce bedtime lock rule
  static void _enforceBedtimeLock(Map<String, dynamic> rule, DateTime now) {
    final subtitle = rule['subtitle'] as String?;
    if (subtitle == null) return;

    // Parse time from subtitle (e.g., "10:00 PM - 7:00 AM")
    final timeMatch =
        RegExp(r'(\d+):(\d+)\s*(AM|PM)\s*-\s*(\d+):(\d+)\s*(AM|PM)')
            .firstMatch(subtitle);

    if (timeMatch != null) {
      int startHour = int.parse(timeMatch.group(1)!);
      int startMinute = int.parse(timeMatch.group(2)!);
      String startPeriod = timeMatch.group(3)!;

      int endHour = int.parse(timeMatch.group(4)!);
      int endMinute = int.parse(timeMatch.group(5)!);
      String endPeriod = timeMatch.group(6)!;

      // Convert to 24-hour format
      if (startPeriod == 'PM' && startHour != 12) startHour += 12;
      if (startPeriod == 'AM' && startHour == 12) startHour = 0;
      if (endPeriod == 'PM' && endHour != 12) endHour += 12;
      if (endPeriod == 'AM' && endHour == 12) endHour = 0;

      final currentTime = now.hour * 60 + now.minute;
      final startTime = startHour * 60 + startMinute;
      final endTime = endHour * 60 + endMinute;

      bool inBedtime = false;

      if (startTime > endTime) {
        // Crosses midnight (e.g., 10 PM - 7 AM)
        inBedtime = currentTime >= startTime || currentTime < endTime;
      } else {
        // Same day (e.g., 2 PM - 5 PM)
        inBedtime = currentTime >= startTime && currentTime < endTime;
      }

      if (inBedtime && _appContext != null) {
        print('🔒 Bedtime detected - showing lock screen');
        _navigateToLockScreen();
      }
    }
  }

  /// Enforce app lock rule
  /// This is now handled by native Android AccessibilityService
  /// The service automatically detects when a locked app is opened
  /// and redirects to the lock screen
  static void _enforceAppLock(Map<String, dynamic> rule) {
    final appPackageName = rule['app_package_name'] as String?;
    final appName = rule['app_name'] as String?;

    if (appPackageName == null) {
      print('⚠️ App Lock rule missing package name');
      return;
    }

    // App blocking is now handled by native AccessibilityService
    // This just logs that the rule is active
    print('✅ App Lock active for $appName ($appPackageName)');
  }

  /// Enforce daily screen time limit
  static Future<void> _enforceDailyScreenLimit(
      Map<String, dynamic> rule, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = 'screen_time_${now.year}_${now.month}_${now.day}';
    final screenTime = prefs.getInt(todayKey) ?? 0;

    final subtitle = rule['subtitle'] as String?;
    if (subtitle == null) return;

    // Extract limit in minutes
    final limitMatch =
        RegExp(r'(\d+)\s*(?:hours?|minutes?)').firstMatch(subtitle);
    if (limitMatch != null) {
      int limitMinutes = int.parse(limitMatch.group(1)!);

      if (subtitle.contains('hours')) {
        limitMinutes *= 60;
      }

      if (screenTime >= limitMinutes && _appContext != null) {
        print('⏱️ Daily screen time limit reached - showing lock screen');
        _navigateToLockScreen();
      }
    }
  }

  /// Enforce app-specific time limit
  static Future<void> _enforceAppTimeLimit(
      Map<String, dynamic> rule, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();

    // Get app package name and time limit from rule
    final appPackageName = rule['app_package_name'] as String?;
    final timeLimitMinutes = rule['time_limit_minutes'] as int?;

    if (appPackageName == null || timeLimitMinutes == null) {
      print('⚠️ App time limit rule missing required data');
      return;
    }

    // Create daily key for this app
    final todayKey =
        'app_usage_${appPackageName}_${now.year}_${now.month}_${now.day}';
    final usageMinutes = prefs.getInt(todayKey) ?? 0;

    // Check if app usage exceeded limit
    if (usageMinutes >= timeLimitMinutes && _appContext != null) {
      print(
          '⏱️ App time limit reached for ${rule['app_name']} ($usageMinutes/$timeLimitMinutes minutes) - locking');
      _navigateToLockScreen();
    } else {
      print(
          '📱 App time limit: ${rule['app_name']} - $usageMinutes/$timeLimitMinutes minutes used');
    }
  }

  /// Track app usage time (call this when app is used)
  static Future<void> trackAppUsage(String packageName, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey =
        'app_usage_${packageName}_${now.year}_${now.month}_${now.day}';
    final currentUsage = prefs.getInt(todayKey) ?? 0;
    await prefs.setInt(todayKey, currentUsage + minutes);
    print(
        '📊 Tracked $minutes min for $packageName (total: ${currentUsage + minutes})');
  }

  static Future<void> _enforceUrlBlock(Map<String, dynamic> rule) async {
    final blockedUrl = rule['blocked_url'] as String?;
    if (blockedUrl != null) {
      print('🌐 Blocking URL: $blockedUrl');
      // Call your VPN bridge here
      // await VpnBridge.addBlockedUrl(blockedUrl);
    }
  }

  /// Get app usage for today
  static Future<int> getAppUsageToday(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey =
        'app_usage_${packageName}_${now.year}_${now.month}_${now.day}';
    return prefs.getInt(todayKey) ?? 0;
  }

  /// Navigate to lock screen
  static void _navigateToLockScreen() {
    if (_appContext != null) {
      try {
        // Use GoRouter to navigate
        _appContext!.goNamed('App_Lock_Screen');
      } catch (e) {
        print('Error navigating to lock screen: $e');
      }
    }
  }

  /// Track screen time (call this periodically)
  static Future<void> incrementScreenTime(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = 'screen_time_${now.year}_${now.month}_${now.day}';
    final currentTime = prefs.getInt(todayKey) ?? 0;
    await prefs.setInt(todayKey, currentTime + minutes);
  }

  /// Get today's screen time
  static Future<int> getTodayScreenTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = 'screen_time_${now.year}_${now.month}_${now.day}';
    return prefs.getInt(todayKey) ?? 0;
  }

  /// Reset daily screen time (called at midnight)
  static Future<void> resetDailyScreenTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = 'screen_time_${now.year}_${now.month}_${now.day}';
    await prefs.remove(todayKey);
  }

  /// Dispose the service
  static void dispose() {
    _enforcementTimer?.cancel();
    _backgroundMonitorTimer?.cancel();
    _activeRules.clear();
    print('🛑 Rules enforcement service disposed');
  }
}
