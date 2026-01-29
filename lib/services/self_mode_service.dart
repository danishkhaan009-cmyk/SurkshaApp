import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing self mode (single user mode) state persistence
class SelfModeService {
  static const String _selfModeKey = 'is_self_mode_active';
  static const String _deviceIdKey = 'self_mode_device_id';

  // Backup keys to prevent data loss
  static const String _selfModeBackupKey = 'self_mode_backup';
  static const String _deviceIdBackupKey = 'self_mode_device_id_backup';

  /// Check if self mode is active
  static Future<bool> isSelfModeActive() async {
    final prefs = await SharedPreferences.getInstance();

    // Check primary key first
    bool isActive = prefs.getBool(_selfModeKey) ?? false;

    // If primary is false, check backup (in case primary was cleared)
    if (!isActive) {
      isActive = prefs.getBool(_selfModeBackupKey) ?? false;

      // If backup shows active but primary doesn't, restore primary
      if (isActive) {
        print('⚠️ Restoring self mode from backup!');
        final deviceId = prefs.getString(_deviceIdBackupKey);
        if (deviceId != null) {
          await prefs.setBool(_selfModeKey, true);
          await prefs.setString(_deviceIdKey, deviceId);
          await prefs.commit();
        }
      }
    }

    return isActive;
  }

  /// Get the device ID for self mode
  static Future<String?> getSelfModeDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    // Check primary key first
    String? deviceId = prefs.getString(_deviceIdKey);

    // If primary is null, check backup
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = prefs.getString(_deviceIdBackupKey);

      // If backup has data but primary doesn't, restore it
      if (deviceId != null && deviceId.isNotEmpty) {
        print('⚠️ Restoring self mode device ID from backup: $deviceId');
        await prefs.setString(_deviceIdKey, deviceId);
        await prefs.commit();
      }
    }

    return deviceId;
  }

  /// Activate self mode
  static Future<void> activateSelfMode({String? deviceId}) async {
    final prefs = await SharedPreferences.getInstance();

    // Generate device ID if not provided
    final id = deviceId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Save to primary keys
    await prefs.setBool(_selfModeKey, true);
    await prefs.setString(_deviceIdKey, id);

    // Save to backup keys to prevent data loss
    await prefs.setBool(_selfModeBackupKey, true);
    await prefs.setString(_deviceIdBackupKey, id);

    // Force commit to ensure data is persisted immediately
    await prefs.commit();

    // Verify the save was successful
    final verified = await isSelfModeActive();
    print('✅ Self mode activated and verified: $verified');
    print('   Device ID: $id');

    // Double-check backup was saved
    final backupVerified = prefs.getBool(_selfModeBackupKey) ?? false;
    print('✅ Backup saved: $backupVerified');
  }

  /// Deactivate self mode
  static Future<void> deactivateSelfMode() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear primary keys
    await prefs.setBool(_selfModeKey, false);
    await prefs.remove(_deviceIdKey);

    // Clear backup keys
    await prefs.setBool(_selfModeBackupKey, false);
    await prefs.remove(_deviceIdBackupKey);

    // Force commit to ensure data is persisted immediately
    await prefs.commit();

    // Verify the deactivation was successful
    final verified = await isSelfModeActive();
    print('✅ Self mode deactivated and verified: ${!verified}');
  }

  /// Debug: Check current self mode status (for development)
  static Future<void> debugPrintStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // Check primary keys
    final isSelf = prefs.getBool(_selfModeKey) ?? false;
    final deviceId = prefs.getString(_deviceIdKey);

    // Check backup keys
    final isSelfBackup = prefs.getBool(_selfModeBackupKey) ?? false;
    final deviceIdBackup = prefs.getString(_deviceIdBackupKey);

    print('🔍 Self Mode Status:');
    print('   PRIMARY - Is Self Mode: $isSelf');
    print('   PRIMARY - Device ID: ${deviceId ?? 'Not set'}');
    print('   BACKUP - Is Self Mode: $isSelfBackup');
    print('   BACKUP - Device ID: ${deviceIdBackup ?? 'Not set'}');
  }
}
