import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

/// Service to handle real Android permissions
class PermissionService {
  static const MethodChannel _channel =
      MethodChannel('parental_control/permissions');

  /// Request Accessibility Service permission
  /// Opens Android Settings > Accessibility
  static Future<bool> requestAccessibilityPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('requestAccessibility');
      return result == true;
    } catch (e) {
      print('Error requesting accessibility: $e');
      // Fallback: Try to open settings
      await openAccessibilitySettings();
      return false;
    }
  }

  /// Request Usage Access permission
  /// Opens Android Settings > Usage Access
  static Future<bool> requestUsageAccessPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('requestUsageAccess');
      return result == true;
    } catch (e) {
      print('Error requesting usage access: $e');
      await openUsageAccessSettings();
      return false;
    }
  }

  /// Request Device Admin permission
  static Future<bool> requestDeviceAdminPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('requestDeviceAdmin');
      return result == true;
    } catch (e) {
      print('Error requesting device admin: $e');
      return false;
    }
  }

  /// Request Notification Listener permission
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      // For Android 13+, request POST_NOTIFICATIONS permission
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return false;
    } catch (e) {
      print('Error requesting notification access: $e');
      return false;
    }
  }

  /// Request Display over other apps (Overlay) permission
  static Future<bool> requestOverlayPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      // Check current status first
      final currentStatus = await Permission.systemAlertWindow.status;

      if (currentStatus.isGranted) {
        return true;
      }

      // Open settings directly for overlay permission
      // This permission cannot be requested via dialog, must use settings
      await _channel.invokeMethod('requestOverlay');
      return false; // Return false as user needs to manually enable it
    } catch (e) {
      print('Error requesting overlay permission: $e');
      return false;
    }
  }

  /// Check if Accessibility Service is enabled
  static Future<bool> isAccessibilityEnabled() async {
    if (!Platform.isAndroid) {
      print('⚠️ Not Android platform - accessibility check skipped');
      return false;
    }

    try {
      print('🔍 Checking accessibility service status...');
      final result = await _channel.invokeMethod('isAccessibilityEnabled');
      print('✅ Accessibility check result: $result');
      return result == true;
    } catch (e) {
      print('❌ Error checking accessibility: $e');
      return false;
    }
  }

  /// Check if Usage Access is granted
  static Future<bool> isUsageAccessGranted() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('isUsageAccessGranted');
      return result == true;
    } catch (e) {
      print('Error checking usage access: $e');
      return false;
    }
  }

  /// Check if Device Admin is enabled
  static Future<bool> isDeviceAdminEnabled() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('isDeviceAdminEnabled');
      return result == true;
    } catch (e) {
      print('Error checking device admin: $e');
      return false;
    }
  }

  /// Check if Notification permission is granted
  static Future<bool> isNotificationAccessGranted() async {
    if (!Platform.isAndroid) return false;

    try {
      // Check POST_NOTIFICATIONS permission for Android 13+
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      print('Error checking notification access: $e');
      return false;
    }
  }

  /// Check if Overlay permission is granted
  static Future<bool> isOverlayPermissionGranted() async {
    if (!Platform.isAndroid) return false;

    try {
      // First try permission_handler
      final status = await Permission.systemAlertWindow.status;
      if (status.isGranted) return true;

      // Fallback to native check
      final result = await _channel.invokeMethod('isOverlayGranted');
      return result == true;
    } catch (e) {
      print('Error checking overlay permission: $e');
      return false;
    }
  }

  /// Open Accessibility Settings
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('Error opening accessibility settings: $e');
    }
  }

  /// Open Usage Access Settings
  static Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (e) {
      print('Error opening usage access settings: $e');
    }
  }

  /// Open Notification Listener Settings
  static Future<void> openNotificationListenerSettings() async {
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      print('Error opening notification listener settings: $e');
    }
  }

  static Future<bool> ensurePermissionsWithPrompt(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    bool acc = await isAccessibilityEnabled();
    bool usage = await isUsageAccessGranted();

    if (acc && usage) return true;

    final missing = <String>[];
    if (!acc) missing.add('Accessibility');
    if (!usage) missing.add('Usage access');

    final open = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Permissions required'),
        content: Text(
          'The app needs the following permissions to enforce app locks:\n\n${missing.join('\n')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (open != true) return false;

    // Open each missing settings screen (native handlers must exist)
    if (!acc) await requestAccessibilityPermission();
    if (!usage) await requestUsageAccessPermission();

    // Wait briefly for user to act and native settings to return
    await Future.delayed(const Duration(milliseconds: 600));

    // Re-check after user action
    acc = await isAccessibilityEnabled();
    usage = await isUsageAccessGranted();
    return acc && usage;
  }

  /// Check all permissions at once
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'accessibility': await isAccessibilityEnabled(),
      'usageAccess': await isUsageAccessGranted(),
      'deviceAdmin': await isDeviceAdminEnabled(),
      'notification': await isNotificationAccessGranted(),
      'overlay': await isOverlayPermissionGranted(),
    };
  }
}
