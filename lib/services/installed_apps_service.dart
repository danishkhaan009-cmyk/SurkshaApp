import 'package:device_apps/device_apps.dart';
import 'dart:typed_data';

class InstalledAppsService {
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
          'versionCode': app.versionCode ?? 0,
          'installTime': DateTime.fromMillisecondsSinceEpoch(app.installTimeMillis),
          'updateTime': DateTime.fromMillisecondsSinceEpoch(app.updateTimeMillis),
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
        'versionCode': app.versionCode ?? 0,
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
}
