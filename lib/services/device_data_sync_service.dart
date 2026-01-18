import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'installed_apps_service.dart';
import 'call_logs_service.dart';

class DeviceDataSyncService {
  static final _supabase = Supabase.instance.client;
  static Timer? _periodicSyncTimer;
  static Timer? _periodicCallLogsSyncTimer;
  static String? _currentDeviceId;

  /// Fetches the list of apps from the device and uploads it to the database.
  static Future<void> syncInstalledApps(String deviceId) async {
    try {
      print('🔄 Starting app sync for device: $deviceId');
      final apps = await InstalledAppsService.getInstalledApps();

      if (apps.isEmpty) {
        print('⚠️ No apps found to sync.');
        return;
      }

      final records = apps
          .map((app) => {
                'device_id': deviceId,
                'app_name': app['appName'],
                'package_name': app['packageName'],
                'version_name': app['versionName'],
                'version_code': app['versionCode'],
                'synced_at': DateTime.now().toIso8601String(),
              })
          .toList();

      // Upsert into the database. This will insert new apps and update existing ones.
      await _supabase.from('installed_apps').upsert(
            records,
            onConflict:
                'device_id, package_name', // Assumes a unique constraint on these columns
          );

      print('✅ Successfully synced ${records.length} apps to database.');
    } catch (e) {
      print('❌ Error syncing installed apps: $e');
    }
  }

  /// Start periodic background sync for installed apps
  /// Syncs every 5 minutes to keep parent's view updated
  static void startPeriodicSync(String deviceId) {
    print('🔄 Starting periodic app sync for device: $deviceId');
    _currentDeviceId = deviceId;

    // Stop any existing timer
    stopPeriodicSync();

    // Initial sync
    syncInstalledApps(deviceId);

    // Set up periodic sync every 5 minutes
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      print('⏰ Periodic app sync triggered');
      syncInstalledApps(deviceId);
    });
  }

  /// Stop periodic sync
  static void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _currentDeviceId = null;
    print('🛑 Stopped periodic app sync');
  }

  /// Check if periodic sync is active
  static bool isPeriodicSyncActive() {
    return _periodicSyncTimer != null && _periodicSyncTimer!.isActive;
  }

  /// Fetches the list of installed apps for a specific device from the database.
  static Future<List<Map<String, dynamic>>> fetchInstalledApps(
      String deviceId) async {
    try {
      print('📡 Fetching installed apps for device: $deviceId from database');
      final response = await _supabase
          .from('installed_apps')
          .select()
          .eq('device_id', deviceId)
          .order('app_name', ascending: true);

      print('✅ Fetched ${response.length} apps from database.');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching installed apps: $e');
      return [];
    }
  }

  /// Subscribe to real-time changes for a device's installed apps
  static Stream<List<Map<String, dynamic>>> watchInstalledApps(
      String deviceId) {
    print('👁️ Setting up real-time watch for device: $deviceId');

    return _supabase
        .from('installed_apps')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('app_name', ascending: true)
        .map((data) {
          print('📡 Real-time update received: ${data.length} apps');
          return List<Map<String, dynamic>>.from(data);
        });
  }

  // ==================== CALL LOGS SYNC ====================

  /// Fetches call logs from the device and uploads to the database
  static Future<void> syncCallLogs(String deviceId) async {
    try {
      print('📞 Starting call logs sync for device: $deviceId');
      final callLogs = await CallLogsService.getCallLogs(limit: 100);

      if (callLogs.isEmpty) {
        print('⚠️ No call logs found to sync.');
        return;
      }

      final records = callLogs
          .map((call) => {
                'device_id': deviceId,
                'name': call['name'],
                'number': call['number'],
                'formatted_number': call['formattedNumber'],
                'call_type': call['callType'],
                'call_type_icon': call['callTypeIcon'],
                'duration': call['duration'],
                'timestamp': call['timestamp'] != null
                    ? (call['timestamp'] as DateTime).toIso8601String()
                    : null,
                'cached_number_type': call['cachedNumberType'],
                'cached_number_label': call['cachedNumberLabel'],
                'synced_at': DateTime.now().toIso8601String(),
              })
          .toList();

      // Upsert into the database
      await _supabase.from('call_logs').upsert(
            records,
            onConflict: 'device_id, number, timestamp, call_type',
          );

      print('✅ Successfully synced ${records.length} call logs to database.');
    } catch (e) {
      print('❌ Error syncing call logs: $e');
    }
  }

  /// Start periodic background sync for call logs
  /// Syncs every 10 minutes to keep parent's view updated
  static void startPeriodicCallLogsSync(String deviceId) {
    print('🔄 Starting periodic call logs sync for device: $deviceId');

    // Stop any existing timer
    stopPeriodicCallLogsSync();

    // Initial sync
    syncCallLogs(deviceId);

    // Set up periodic sync every 10 minutes
    _periodicCallLogsSyncTimer =
        Timer.periodic(const Duration(minutes: 10), (timer) {
      print('⏰ Periodic call logs sync triggered');
      syncCallLogs(deviceId);
    });
  }

  /// Stop periodic call logs sync
  static void stopPeriodicCallLogsSync() {
    _periodicCallLogsSyncTimer?.cancel();
    _periodicCallLogsSyncTimer = null;
    print('🛑 Stopped periodic call logs sync');
  }

  /// Fetches call logs for a specific device from the database
  static Future<List<Map<String, dynamic>>> fetchCallLogs(
      String deviceId) async {
    try {
      print('📡 Fetching call logs for device: $deviceId from database');
      final response = await _supabase
          .from('call_logs')
          .select()
          .eq('device_id', deviceId)
          .order('timestamp', ascending: false)
          .limit(100);

      print('✅ Fetched ${response.length} call logs from database.');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching call logs: $e');
      return [];
    }
  }

  /// Subscribe to real-time changes for a device's call logs
  static Stream<List<Map<String, dynamic>>> watchCallLogs(String deviceId) {
    print('👁️ Setting up real-time watch for call logs: $deviceId');

    return _supabase
        .from('call_logs')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('timestamp', ascending: false)
        .map((data) {
          print('📡 Real-time call logs update received: ${data.length} calls');
          return List<Map<String, dynamic>>.from(data);
        });
  }
}
