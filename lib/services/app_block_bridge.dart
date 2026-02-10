import 'package:flutter/services.dart';

/// Bridge to communicate with native Android AppBlockService
class AppBlockBridge {
  static const MethodChannel _channel =
      MethodChannel('parental_control/permissions');

  /// Send list of locked app package names to native service
  static Future<bool> setLockedApps(List<String> packageNames) async {
    try {
      final result = await _channel.invokeMethod('setLockedApps', {
        'apps': packageNames,
      });
      print('📱 Updated locked apps in native service: $packageNames');
      return result == true;
    } catch (e) {
      print('❌ Error setting locked apps: $e');
      return false;
    }
  }

  /// Set PIN for a specific app
  static Future<bool> setAppLockPin(String packageName, String pin) async {
    try {
      final result = await _channel.invokeMethod('setAppLockPin', {
        'package': packageName,
        'pin': pin,
      });
      return result == true;
    } catch (e) {
      print('❌ Error setting app lock pin: $e');
      return false;
    }
  }

  /// Enable/disable child mode in native service
  static Future<bool> setChildMode(bool active) async {
    try {
      final result = await _channel.invokeMethod('setChildMode', {
        'active': active,
      });
      print(
          '🔒 Child mode ${active ? "enabled" : "disabled"} in native service');
      return result == true;
    } catch (e) {
      print('❌ Error setting child mode: $e');
      return false;
    }
  }

  /// Get currently locked apps from native service
  static Future<List<String>> getLockedApps() async {
    try {
      final result = await _channel.invokeListMethod<String>('getLockedApps');
      return result ?? [];
    } catch (e) {
      print('❌ Error getting locked apps: $e');
      return [];
    }
  }

  /// Start foreground monitoring service (keeps background monitoring alive)
  static Future<bool> startMonitoringService() async {
    try {
      final result = await _channel.invokeMethod('startMonitoringService');
      print('🚀 Foreground monitoring service started');
      return result == true;
    } catch (e) {
      print('❌ Error starting monitoring service: $e');
      return false;
    }
  }

  /// Stop foreground monitoring service
  static Future<bool> stopMonitoringService() async {
    try {
      final result = await _channel.invokeMethod('stopMonitoringService');
      print('🛑 Foreground monitoring service stopped');
      return result == true;
    } catch (e) {
      print('❌ Error stopping monitoring service: $e');
      return false;
    }
  }
}
