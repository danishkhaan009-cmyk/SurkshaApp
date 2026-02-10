import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

/// Service to get a unique identifier for this physical device
class DeviceIdentifierService {
  static const String _deviceIdKey = 'unique_device_identifier';

  /// Get or create a unique identifier for this device
  /// This persists across app restarts and uniquely identifies the hardware
  static Future<String> getDeviceIdentifier() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we already have a device identifier
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate a new unique identifier for this device
      deviceId = _generateUniqueId();
      await prefs.setString(_deviceIdKey, deviceId);
      print('📱 Generated new device identifier: $deviceId');
    } else {
      print('📱 Retrieved existing device identifier: $deviceId');
    }

    return deviceId;
  }

  /// Generate a unique ID for this device
  static String _generateUniqueId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999).toString().padLeft(6, '0');

    // Format: DEVICE-timestamp-random
    // Example: DEVICE-1702234567890-123456
    return 'DEVICE-$timestamp-$randomPart';
  }

  /// Clear the device identifier (for testing only)
  static Future<void> clearDeviceIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    print('🗑️ Device identifier cleared');
  }
}
