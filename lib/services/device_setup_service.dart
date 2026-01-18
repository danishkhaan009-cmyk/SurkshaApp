import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'auth_service.dart';

/// Service for managing child device setup and pairing
class DeviceSetupService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, dynamic> _setupData = {};

  // Generate unique device pairing code
  static String generatePairingCode() {
    final random = Random();
    final part1 = random.nextInt(900) + 100; // 3 digits
    final part2 = random.nextInt(900) + 100; // 3 digits
    final part3 = random.nextInt(900) + 100; // 3 digits
    return 'CHILD-$part1-$part2-$part3';
  }

  // Store device setup data temporarily (during the setup flow)
  static void storeSetupData({
    String? childName,
    String? childAge,
    String? pairingCode,
    Map<String, bool>? permissions,
  }) {
    if (childName != null) _setupData['childName'] = childName;
    if (childAge != null) _setupData['childAge'] = childAge;
    if (pairingCode != null) _setupData['pairingCode'] = pairingCode;
    if (permissions != null) _setupData['permissions'] = permissions;
  }

  // Get stored setup data
  static Map<String, dynamic> getSetupData() {
    return Map<String, dynamic>.from(_setupData);
  }

  // Clear setup data
  static void clearSetupData() {
    _setupData.clear();
  }

  // Save child device to Supabase
  static Future<Map<String, dynamic>> createChildDevice({
    required String childName,
    required String childAge,
    required String pairingCode,
    Map<String, bool>? permissions,
    String? deviceModel,
    String? osVersion,
  }) async {
    if (!AuthService.isLoggedIn) throw Exception('Not logged in');

    try {
      // Create device record
      final deviceData = {
        'user_id': AuthService.currentUser!.id,
        'device_name': '$childName\'s Device',
        'device_model': deviceModel ?? 'Unknown',
        'os_version': osVersion ?? 'Unknown',
        'is_active': false, // Not active until child pairs
        'pairing_code': pairingCode,
        'child_name': childName,
        'child_age': childAge,
        'permissions': permissions ?? {},
        'paired_at': null, // Will be set when child pairs
      };

      final response =
          await _supabase.from('devices').insert(deviceData).select().single();

      // Create initial screen time record
      await _supabase.from('screen_time').insert({
        'device_id': response['id'],
        'date': DateTime.now().toIso8601String().split('T')[0],
        'total_minutes': 0,
        'app_usage': {},
      });

      return response;
    } catch (e) {
      throw Exception('Failed to create device: $e');
    }
  }

  // Verify and activate device using pairing code (called from child device)
  static Future<Map<String, dynamic>?> verifyAndActivateDevice(
      String pairingCode) async {
    try {
      // Find device by pairing code
      final response = await _supabase
          .from('devices')
          .select()
          .eq('pairing_code', pairingCode)
          .maybeSingle();

      if (response == null) {
        throw Exception('Invalid pairing code');
      }

      // Activate the device
      await _supabase.from('devices').update({
        'is_active': true,
        'paired_at': DateTime.now().toIso8601String(),
        'last_active': DateTime.now().toIso8601String(),
      }).eq('id', response['id']);

      return response;
    } catch (e) {
      throw Exception('Failed to verify device: $e');
    }
  }

  // Get device by pairing code
  static Future<Map<String, dynamic>?> getDeviceByPairingCode(
      String pairingCode) async {
    try {
      final response = await _supabase
          .from('devices')
          .select()
          .eq('pairing_code', pairingCode)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  // Update device permissions
  static Future<void> updateDevicePermissions(
    String deviceId,
    Map<String, bool> permissions,
  ) async {
    await _supabase
        .from('devices')
        .update({'permissions': permissions}).eq('id', deviceId);
  }

  // Check if device is paired and active
  static Future<bool> isDevicePaired(String pairingCode) async {
    try {
      final response = await _supabase
          .from('devices')
          .select('is_active')
          .eq('pairing_code', pairingCode)
          .maybeSingle();

      return response?['is_active'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // Get all devices for current user
  static Future<List<Map<String, dynamic>>> getUserDevices() async {
    if (!AuthService.isLoggedIn) throw Exception('Not logged in');

    final response = await _supabase
        .from('devices')
        .select()
        .eq('user_id', AuthService.currentUser!.id)
        .order('paired_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Delete device
  static Future<void> deleteDevice(String deviceId) async {
    await _supabase.from('devices').delete().eq('id', deviceId);
  }

  // Update device last active
  static Future<void> updateDeviceLastActive(String deviceId) async {
    await _supabase.from('devices').update(
        {'last_active': DateTime.now().toIso8601String()}).eq('id', deviceId);
  }

  // Get device statistics
  static Future<Map<String, dynamic>> getDeviceStats(String deviceId) async {
    // Get total screen time for last 7 days
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 7));

    final screenTimeData = await _supabase
        .from('screen_time')
        .select('total_minutes, date')
        .eq('device_id', deviceId)
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0]);

    // Get total alerts count
    final alertsData = await _supabase
        .from('alerts')
        .select('id')
        .eq('device_id', deviceId)
        .count(CountOption.exact);

    // Get unread alerts count
    final unreadAlertsData = await _supabase
        .from('alerts')
        .select('id')
        .eq('device_id', deviceId)
        .eq('is_read', false)
        .count(CountOption.exact);

    final totalMinutes = (screenTimeData as List).fold<int>(
      0,
      (sum, item) => sum + (item['total_minutes'] as int),
    );

    return {
      'total_screen_time': totalMinutes,
      'avg_screen_time_per_day': totalMinutes / 7,
      'total_alerts': alertsData.count,
      'unread_alerts': unreadAlertsData.count,
    };
  }
}
