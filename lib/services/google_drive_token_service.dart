import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage Google Drive token sharing between parent and child devices.
///
/// Flow:
/// 1. Parent connects to Google Drive on parent device
/// 2. Token is saved to Supabase against the child device record
/// 3. Child device fetches the token from Supabase on startup
/// 4. Child uploads videos using parent's Google Drive account
class GoogleDriveTokenService {
  static final supabase = Supabase.instance.client;

  /// Save Google Drive token to Supabase for a specific child device.
  /// Called by parent when they connect Google Drive.
  static Future<bool> saveTokenForDevice({
    required String deviceId,
    required String email,
    required String token,
  }) async {
    try {
      print('☁️ Saving Google Drive token for device: $deviceId');
      print('☁️ Email: $email');

      await supabase.from('devices').update({
        'google_drive_email': email,
        'google_drive_token': token,
        'google_drive_token_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', deviceId);

      print('✅ Google Drive token saved to Supabase for device: $deviceId');
      return true;
    } catch (e) {
      print('❌ Failed to save Google Drive token: $e');
      return false;
    }
  }

  /// Fetch Google Drive token from Supabase for this device.
  /// Called by child device on startup to get parent's token.
  static Future<Map<String, String>?> fetchTokenForDevice(
      String deviceId) async {
    try {
      print('☁️ Fetching Google Drive token for device: $deviceId');

      final response = await supabase
          .from('devices')
          .select(
              'google_drive_email, google_drive_token, google_drive_token_updated_at')
          .eq('id', deviceId)
          .maybeSingle();

      if (response == null) {
        print('⚠️ Device not found in database: $deviceId');
        return null;
      }

      final email = response['google_drive_email'] as String?;
      final token = response['google_drive_token'] as String?;

      if (email != null && token != null && token.isNotEmpty) {
        print('✅ Found Google Drive token for device');
        print('   Email: $email');
        print('   Token updated: ${response['google_drive_token_updated_at']}');
        return {
          'email': email,
          'token': token,
        };
      } else {
        print('⚠️ No Google Drive token found for device: $deviceId');
        return null;
      }
    } catch (e) {
      print('❌ Failed to fetch Google Drive token: $e');
      return null;
    }
  }

  /// Clear Google Drive token for a device.
  /// Called when parent disconnects Google Drive.
  static Future<bool> clearTokenForDevice(String deviceId) async {
    try {
      print('☁️ Clearing Google Drive token for device: $deviceId');

      await supabase.from('devices').update({
        'google_drive_email': null,
        'google_drive_token': null,
        'google_drive_token_updated_at': null,
      }).eq('id', deviceId);

      print('✅ Google Drive token cleared for device: $deviceId');
      return true;
    } catch (e) {
      print('❌ Failed to clear Google Drive token: $e');
      return false;
    }
  }

  /// Check if a device has a Google Drive token stored.
  static Future<bool> hasTokenForDevice(String deviceId) async {
    try {
      final response = await supabase
          .from('devices')
          .select('google_drive_token')
          .eq('id', deviceId)
          .maybeSingle();

      if (response == null) return false;

      final token = response['google_drive_token'] as String?;
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('❌ Failed to check Google Drive token: $e');
      return false;
    }
  }

  /// Check if the child device has requested a token refresh.
  /// Called by parent device when viewing child.
  /// Gracefully returns false if the column doesn't exist yet.
  static Future<bool> isTokenRefreshRequested(String deviceId) async {
    try {
      // Use a broad select to avoid errors if column doesn't exist
      final response = await supabase
          .from('devices')
          .select()
          .eq('id', deviceId)
          .maybeSingle();

      if (response == null) return false;

      // Column may not exist yet — safely check
      if (!response.containsKey('token_refresh_requested')) return false;

      final requested = response['token_refresh_requested'] as bool? ?? false;
      if (requested) {
        final requestedAt = response['token_refresh_requested_at'] as String?;
        print(
            '🔔 Child device $deviceId requested token refresh at: $requestedAt');
      }
      return requested;
    } catch (e) {
      // Silently ignore — column may not exist in database yet
      return false;
    }
  }

  /// Clear the token refresh request flag after parent has refreshed.
  /// Called by parent after successfully refreshing and saving a new token.
  /// Silently ignores errors if the column doesn't exist yet.
  static Future<void> clearTokenRefreshRequest(String deviceId) async {
    try {
      await supabase.from('devices').update({
        'token_refresh_requested': false,
        'token_refresh_requested_at': null,
      }).eq('id', deviceId);
      print('✅ Token refresh request cleared for device: $deviceId');
    } catch (e) {
      // Silently ignore — column may not exist in database yet
    }
  }
}
