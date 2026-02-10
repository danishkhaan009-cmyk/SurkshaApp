import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'url_blocking_service.dart';
import 'device_status_service.dart';

/// Service for managing child mode state persistence
class ChildModeService {
  // Method channel for syncing with native Android
  static const MethodChannel _channel =
      MethodChannel('parental_control/permissions');
  static const String _childModeKey = 'is_child_mode_active';
  static const String _deviceIdKey = 'child_device_id';
  static const String _childPinKey = 'child_exit_pin';

  // Backup keys to prevent data loss
  static const String _childModeBackupKey = 'child_mode_backup';
  static const String _deviceIdBackupKey = 'device_id_backup';
  static const String _pinBackupKey = 'pin_backup';

  /// Check if child mode is active
  static Future<bool> isChildModeActive() async {
    final prefs = await SharedPreferences.getInstance();

    // Check primary key first
    bool isActive = prefs.getBool(_childModeKey) ?? false;

    // If primary is false, check backup (in case primary was cleared)
    if (!isActive) {
      isActive = prefs.getBool(_childModeBackupKey) ?? false;

      // If backup shows active but primary doesn't, restore primary
      if (isActive) {
        print('⚠️ Restoring child mode from backup!');
        final deviceId = prefs.getString(_deviceIdBackupKey);
        final pin = prefs.getString(_pinBackupKey);
        if (deviceId != null && pin != null) {
          await prefs.setBool(_childModeKey, true);
          await prefs.setString(_deviceIdKey, deviceId);
          await prefs.setString(_childPinKey, pin);
          await prefs.commit();
        }
      }
    }

    return isActive;
  }

  /// Get the device ID for child mode
  static Future<String?> getChildDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    // Check primary key first
    String? deviceId = prefs.getString(_deviceIdKey);

    // If primary is null, check backup
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = prefs.getString(_deviceIdBackupKey);

      // If backup has data but primary doesn't, restore it
      if (deviceId != null && deviceId.isNotEmpty) {
        print('⚠️ Restoring device ID from backup: $deviceId');
        await prefs.setString(_deviceIdKey, deviceId);
        await prefs.commit();
      }
    }

    return deviceId;
  }

  /// Get the exit PIN
  static Future<String?> getExitPin() async {
    final prefs = await SharedPreferences.getInstance();

    // Check primary key first
    String? pin = prefs.getString(_childPinKey);

    // If primary is null, check backup
    if (pin == null || pin.isEmpty) {
      pin = prefs.getString(_pinBackupKey);

      // If backup has data but primary doesn't, restore it
      if (pin != null && pin.isNotEmpty) {
        print('⚠️ Restoring PIN from backup');
        await prefs.setString(_childPinKey, pin);
        await prefs.commit();
      }
    }

    return pin;
  }

  /// Activate child mode
  static Future<void> activateChildMode(String deviceId, String pin) async {
    final prefs = await SharedPreferences.getInstance();

    // Save to primary keys
    await prefs.setBool(_childModeKey, true);
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_childPinKey, pin);

    // Save to backup keys to prevent data loss
    await prefs.setBool(_childModeBackupKey, true);
    await prefs.setString(_deviceIdBackupKey, deviceId);
    await prefs.setString(_pinBackupKey, pin);

    // Force commit to ensure data is persisted immediately
    await prefs.commit();

    // Sync device ID to native Android SharedPreferences for LocationWorker
    await _syncDeviceIdToNative(deviceId);

    // Initialize URL blocking service
    try {
      await UrlBlockingService().initialize(deviceId);
      print('✅ URL Blocking Service initialized');
    } catch (e) {
      print('⚠️ Failed to initialize URL Blocking: $e');
    }

    // Start heartbeat for real-time status tracking
    try {
      DeviceStatusService().startHeartbeat(deviceId);
      print('💓 Device heartbeat started');
    } catch (e) {
      print('⚠️ Failed to start heartbeat: $e');
    }

    // Verify the save was successful
    final verified = await isChildModeActive();
    print('✅ Child mode activated and verified: $verified');
    print('   Device ID: $deviceId');
    print('   PIN set: ${pin.isNotEmpty}');

    // Double-check backup was saved
    final backupVerified = prefs.getBool(_childModeBackupKey) ?? false;
    print('✅ Backup saved: $backupVerified');
  }

  /// Sync device ID to native Android SharedPreferences for LocationWorker access
  static Future<void> _syncDeviceIdToNative(String deviceId) async {
    try {
      await _channel.invokeMethod('syncDeviceId', {'deviceId': deviceId});
      print('✅ Device ID synced to native: $deviceId');
    } catch (e) {
      print('⚠️ Failed to sync device ID to native: $e');
    }
  }

  /// Deactivate child mode
  static Future<void> deactivateChildMode() async {
    final prefs = await SharedPreferences.getInstance();

    // Stop heartbeat and release device before clearing local state
    final deviceId =
        prefs.getString(_deviceIdKey) ?? prefs.getString(_deviceIdBackupKey);
    DeviceStatusService().stopHeartbeat();
    if (deviceId != null && deviceId.isNotEmpty) {
      await DeviceStatusService.releaseDevice(deviceId);
      print('💔 Device released: $deviceId');
    }

    // Clear primary keys
    await prefs.setBool(_childModeKey, false);
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_childPinKey);

    // Clear backup keys
    await prefs.setBool(_childModeBackupKey, false);
    await prefs.remove(_deviceIdBackupKey);
    await prefs.remove(_pinBackupKey);

    // Force commit to ensure data is persisted immediately
    await prefs.commit();

    // Verify the deactivation was successful
    final verified = await isChildModeActive();
    print('✅ Child mode deactivated and verified: ${!verified}');
  }

  /// Debug: Check current child mode status (for development)
  static Future<void> debugPrintStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // Check primary keys
    final isChild = prefs.getBool(_childModeKey) ?? false;
    final deviceId = prefs.getString(_deviceIdKey);
    final pin = prefs.getString(_childPinKey);

    // Check backup keys
    final isChildBackup = prefs.getBool(_childModeBackupKey) ?? false;
    final deviceIdBackup = prefs.getString(_deviceIdBackupKey);
    final pinBackup = prefs.getString(_pinBackupKey);

    // Get all keys to see what's in SharedPreferences
    final allKeys = prefs.getKeys();

    print('🔍 Child Mode Status:');
    print('   PRIMARY - Is Child Mode: $isChild');
    print('   PRIMARY - Device ID: ${deviceId ?? 'Not set'}');
    print('   PRIMARY - Has PIN: ${pin != null}');
    print('   BACKUP - Is Child Mode: $isChildBackup');
    print('   BACKUP - Device ID: ${deviceIdBackup ?? 'Not set'}');
    print('   BACKUP - Has PIN: ${pinBackup != null}');
    print('   All SharedPreferences keys: $allKeys');
  }

  /// Verify PIN for exiting child mode
  static Future<bool> verifyExitPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_childPinKey);
    return savedPin == enteredPin;
  }
}
