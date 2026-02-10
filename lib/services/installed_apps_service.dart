import 'package:device_apps/device_apps.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstalledAppsService {
  static final _supabase = Supabase.instance.client;
  static Timer? _periodicSyncTimer;

  /// Fetch all installed apps on the device
  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      print('🔍 Attempting to fetch installed applications...');

      // Get all installed applications with icons
      List<Application> apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: true,
      );

      print('📱 Found ${apps.length} total applications');

      // Fetch icons for each app
      List<Map<String, dynamic>> appList = [];

      for (var app in apps) {
        Uint8List? icon;

        // Try to get app with icon
        try {
          final appWithIcon = await DeviceApps.getApp(app.packageName, true);
          if (appWithIcon is ApplicationWithIcon) {
            icon = appWithIcon.icon;
          }
        } catch (e) {
          print('Could not get icon for ${app.packageName}');
        }

        appList.add({
          'appName': app.appName,
          'packageName': app.packageName,
          'icon': icon,
          'versionName': app.versionName ?? 'Unknown',
          'versionCode': app.versionCode,
          'installTime':
              DateTime.fromMillisecondsSinceEpoch(app.installTimeMillis),
          'updateTime':
              DateTime.fromMillisecondsSinceEpoch(app.updateTimeMillis),
        });
      }

      print('✅ Converted ${appList.length} apps to map format');

      // Sort by app name
      appList.sort((a, b) => (a['appName'] as String)
          .toLowerCase()
          .compareTo((b['appName'] as String).toLowerCase()));

      print('✅ Sorted apps alphabetically');
      if (appList.isNotEmpty) {
        print(
            '📱 First 3 apps: ${appList.take(3).map((a) => a['appName']).join(', ')}');
      }

      return appList;
    } catch (e, stackTrace) {
      print('❌ Error fetching installed apps: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get specific app info by package name
  static Future<Map<String, dynamic>?> getAppByPackageName(
      String packageName) async {
    try {
      Application? app = await DeviceApps.getApp(packageName, true);
      if (app == null) return null;

      Uint8List? icon;
      if (app is ApplicationWithIcon) {
        icon = app.icon;
      }

      return {
        'appName': app.appName,
        'packageName': app.packageName,
        'icon': icon,
        'versionName': app.versionName ?? 'Unknown',
        'versionCode': app.versionCode,
      };
    } catch (e) {
      print('Error fetching app by package name: $e');
      return null;
    }
  }

  /// Check if app is installed
  static Future<bool> isAppInstalled(String packageName) async {
    try {
      return await DeviceApps.isAppInstalled(packageName);
    } catch (e) {
      print('Error checking if app is installed: $e');
      return false;
    }
  }

  /// Open an app by package name
  static Future<bool> openApp(String packageName) async {
    try {
      return await DeviceApps.openApp(packageName);
    } catch (e) {
      print('Error opening app: $e');
      return false;
    }
  }

  // ==================== DATABASE SYNC METHODS ====================

  /// Fetches the list of apps from the device and uploads it to the database.
  static Future<void> syncInstalledApps(String deviceId) async {
    try {
      print('🔄 Starting app sync for device: $deviceId');
      final apps = await getInstalledApps();

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
    print('🛑 Stopped periodic app sync');
  }

  /// Check if periodic sync is active
  static bool isPeriodicSyncActive() {
    return _periodicSyncTimer != null && _periodicSyncTimer!.isActive;
  }

  /// Fetches the list of installed apps for a specific device from the database.
  static Future<List<Map<String, dynamic>>> fetchInstalledAppsFromDb(
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
}
