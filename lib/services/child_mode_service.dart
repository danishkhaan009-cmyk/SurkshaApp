import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing child mode state persistence
class ChildModeService {
  static const String _childModeKey = 'is_child_mode_active';
  static const String _deviceIdKey = 'child_device_id';
  static const String _childPinKey = 'child_exit_pin';

  /// Check if child mode is active
  static Future<bool> isChildModeActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_childModeKey) ?? false;
  }

  /// Get the device ID for child mode
  static Future<String?> getChildDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }

  /// Get the exit PIN
  static Future<String?> getExitPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_childPinKey);
  }

  /// Activate child mode
  static Future<void> activateChildMode(String deviceId, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_childModeKey, true);
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_childPinKey, pin);
  }

  /// Deactivate child mode
  static Future<void> deactivateChildMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_childModeKey, false);
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_childPinKey);
  }

  /// Debug: Check current child mode status (for development)
  static Future<void> debugPrintStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isChild = prefs.getBool(_childModeKey) ?? false;
    final deviceId = prefs.getString(_deviceIdKey);
    final pin = prefs.getString(_childPinKey);

    print('🔍 Child Mode Status:');
    print('   Is Child Mode: $isChild');
    print('   Device ID: ${deviceId ?? 'Not set'}');
    print('   Has PIN: ${pin != null}');
  }

  /// Verify PIN for exiting child mode
  static Future<bool> verifyExitPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_childPinKey);
    return savedPin == enteredPin;
  }
}
