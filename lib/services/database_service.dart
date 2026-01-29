import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Service for managing database operations with Supabase
class DatabaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ==================== DEVICES ====================

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

  // Add a new device
  static Future<Map<String, dynamic>> addDevice({
    required String deviceName,
    String? deviceModel,
    String? osVersion,
  }) async {
    if (!AuthService.isLoggedIn) throw Exception('Not logged in');

    final response = await _supabase
        .from('devices')
        .insert({
          'user_id': AuthService.currentUser!.id,
          'device_name': deviceName,
          'device_model': deviceModel,
          'os_version': osVersion,
          'is_active': true,
        })
        .select()
        .single();

    return response;
  }

  // Update device status
  static Future<void> updateDeviceStatus(String deviceId, bool isActive) async {
    await _supabase.from('devices').update({
      'is_active': isActive,
      'last_active': DateTime.now().toIso8601String()
    }).eq('id', deviceId);
  }

  // Delete device
  static Future<void> deleteDevice(String deviceId) async {
    await _supabase.from('devices').delete().eq('id', deviceId);
  }

  // ==================== ALERTS ====================

  // Get alerts for a device
  static Future<List<Map<String, dynamic>>> getDeviceAlerts(String deviceId,
      {int limit = 50}) async {
    final response = await _supabase
        .from('alerts')
        .select()
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get all unread alerts for user's devices
  static Future<List<Map<String, dynamic>>> getUnreadAlerts() async {
    if (!AuthService.isLoggedIn) throw Exception('Not logged in');

    final devices = await getUserDevices();
    final deviceIds = devices.map((d) => d['id']).toList();

    if (deviceIds.isEmpty) return [];

    final response = await _supabase
        .from('alerts')
        .select()
        .inFilter('device_id', deviceIds)
        .eq('is_read', false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Create alert
  static Future<void> createAlert({
    required String deviceId,
    required String alertType,
    required String message,
    String severity = 'medium',
  }) async {
    await _supabase.from('alerts').insert({
      'device_id': deviceId,
      'alert_type': alertType,
      'alert_message': message,
      'severity': severity,
      'is_read': false,
    });
  }

  // Mark alert as read
  static Future<void> markAlertAsRead(String alertId) async {
    await _supabase.from('alerts').update({'is_read': true}).eq('id', alertId);
  }

  // Mark all alerts as read for a device
  static Future<void> markAllAlertsAsRead(String deviceId) async {
    await _supabase
        .from('alerts')
        .update({'is_read': true})
        .eq('device_id', deviceId)
        .eq('is_read', false);
  }

  // ==================== SCREEN TIME ====================

  // Get screen time for a device and date
  static Future<Map<String, dynamic>?> getScreenTime(
      String deviceId, DateTime date) async {
    final dateStr =
        date.toIso8601String().split('T')[0]; // Get just the date part

    final response = await _supabase
        .from('screen_time')
        .select()
        .eq('device_id', deviceId)
        .eq('date', dateStr)
        .maybeSingle();

    return response;
  }

  // Get screen time history for a device
  static Future<List<Map<String, dynamic>>> getScreenTimeHistory(
    String deviceId, {
    int days = 7,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final response = await _supabase
        .from('screen_time')
        .select()
        .eq('device_id', deviceId)
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0])
        .order('date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Add or update screen time
  static Future<void> upsertScreenTime({
    required String deviceId,
    required DateTime date,
    required int totalMinutes,
    Map<String, dynamic>? appUsage,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];

    await _supabase.from('screen_time').upsert({
      'device_id': deviceId,
      'date': dateStr,
      'total_minutes': totalMinutes,
      'app_usage': appUsage,
    });
  }

  // ==================== LOCATIONS ====================
/*

  // Get latest location for a device
  static Future<Map<String, dynamic>?> getLatestLocation(
      String deviceId) async {
    final response = await _supabase
        .from('locations')
        .select()
        .eq('device_id', deviceId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  // Get location history for a device
  static Future<List<Map<String, dynamic>>> getLocationHistory(
    String deviceId, {
    int limit = 100,
  }) async {
    final response = await _supabase
        .from('locations')
        .select()
        .eq('device_id', deviceId)
        .order('recorded_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  // Add location
  static Future<void> addLocation({
    required String deviceId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    await _supabase.from('locations').insert({
      'device_id': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    });
  }
*/

  // ==================== SUBSCRIPTIONS ====================

  // Get user's active subscription
  static Future<Map<String, dynamic>?> getActiveSubscription() async {
    if (!AuthService.isLoggedIn) throw Exception('Not logged in');

    final response = await _supabase
        .from('subscriptions')
        .select()
        .eq('user_id', AuthService.currentUser!.id)
        .eq('status', 'active')
        .maybeSingle();

    return response;
  }

  // Create subscription
  static Future<void> createSubscription({
    required String planName,
    DateTime? expiresAt,
    bool autoRenew = true,
  }) async {
    if (!AuthService.isLoggedIn) throw Exception('Not logged in');

    await _supabase.from('subscriptions').insert({
      'user_id': AuthService.currentUser!.id,
      'plan_name': planName,
      'status': 'active',
      'expires_at': expiresAt?.toIso8601String(),
      'auto_renew': autoRenew,
    });
  }

  // Update subscription status
  static Future<void> updateSubscriptionStatus(
      String subscriptionId, String status) async {
    await _supabase
        .from('subscriptions')
        .update({'status': status}).eq('id', subscriptionId);
  }

  // ==================== REAL-TIME SUBSCRIPTIONS ====================

  // Listen to device updates
  static RealtimeChannel subscribeToDeviceUpdates(
      String deviceId, Function(dynamic) onUpdate) {
    return _supabase
        .channel('device_$deviceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'devices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: deviceId,
          ),
          callback: onUpdate,
        )
        .subscribe();
  }

  // Listen to new alerts for user's devices
  static RealtimeChannel subscribeToAlerts(
      List<String> deviceIds, Function(dynamic) onAlert) {
    return _supabase
        .channel('alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          callback: onAlert,
        )
        .subscribe();
  }
}
