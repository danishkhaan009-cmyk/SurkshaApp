import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service for managing real-time device status with heartbeat mechanism.
/// Enforces single-device-per-profile rule and provides status tracking.
class DeviceStatusService {
  static final DeviceStatusService _instance = DeviceStatusService._internal();
  factory DeviceStatusService() => _instance;
  DeviceStatusService._internal();

  static final SupabaseClient _supabase = Supabase.instance.client;

  Timer? _heartbeatTimer;
  String? _currentDeviceId;

  /// Heartbeat interval — how often we ping Supabase
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// Stale threshold — if last_active_at is older than this, device is considered inactive
  static const Duration staleThreshold = Duration(minutes: 2);

  /// Get a stable unique identifier for the current physical device.
  /// Uses a UUID stored in SharedPreferences so it persists across app restarts
  /// and OS updates (unlike Build.ID which changes with system updates).
  static Future<String> getDeviceIdentifier() async {
    const key = 'suraksha_device_uuid';
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(key);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(key, id);
    }
    return id;
  }

  /// Attempt to claim a device profile for this physical device.
  /// Returns true if claimed successfully, false ONLY if another device is
  /// genuinely active on this profile. On errors, defaults to allowing access.
  static Future<bool> claimDevice(String deviceId) async {
    final identifier = await getDeviceIdentifier();
    final now = DateTime.now().toUtc();

    // Step 1: Check if another device already owns this profile
    try {
      final current =
          await _supabase.from('devices').select().eq('id', deviceId).single();

      final existingIdentifier = current['active_device_identifier'] as String?;
      final lastActiveStr = current['last_active_at'] as String?;
      final isActive = current['is_active'] as bool? ?? false;

      // Only block if ALL conditions are met:
      // 1. Another identifier is set (not null/empty)
      // 2. It's a different device
      // 3. The profile is marked active
      // 4. The last heartbeat is recent (within stale threshold)
      if (existingIdentifier != null &&
          existingIdentifier.isNotEmpty &&
          existingIdentifier != identifier &&
          isActive &&
          lastActiveStr != null) {
        final lastActive = DateTime.parse(lastActiveStr);
        final elapsed = now.difference(lastActive);
        if (elapsed < staleThreshold) {
          // Confirmed: another device is actively using this profile
          debugPrint(
              '⚠️ Device conflict: $existingIdentifier active ${elapsed.inSeconds}s ago');
          return false;
        }
        // Existing device is stale — safe to take over
      }
    } catch (e) {
      // Query failed (network issue, missing columns, etc.)
      // Default to allowing access rather than blocking incorrectly
      debugPrint('⚠️ Could not verify device status, allowing claim: $e');
    }

    // Step 2: Claim the device — only use guaranteed columns
    try {
      await _supabase.from('devices').update({
        'is_active': true,
        'last_active': now.toIso8601String(),
      }).eq('id', deviceId);
    } catch (e) {
      debugPrint('⚠️ Failed to update device claim, continuing anyway: $e');
    }

    return true;
  }

  /// Release the device profile (mark as inactive)
  static Future<void> releaseDevice(String deviceId) async {
    try {
      await _supabase.from('devices').update({
        'is_active': false,
        'last_active': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', deviceId);
    } catch (e) {
      debugPrint('⚠️ Failed to release device: $e');
    }
  }

  /// Start the heartbeat timer for a claimed device
  void startHeartbeat(String deviceId) {
    stopHeartbeat(); // Clear any existing timer
    _currentDeviceId = deviceId;

    // Send first heartbeat immediately
    _sendHeartbeat();

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendHeartbeat();
    });

    debugPrint('💓 Heartbeat started for device $deviceId');
  }

  /// Stop the heartbeat timer
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('💔 Heartbeat stopped');
  }

  /// Send a single heartbeat update
  Future<void> _sendHeartbeat() async {
    if (_currentDeviceId == null) return;

    try {
      final now = DateTime.now().toUtc();
      // Only use columns guaranteed to exist in the database
      await _supabase.from('devices').update({
        'last_active': now.toIso8601String(),
        'is_active': true,
      }).eq('id', _currentDeviceId!);
    } catch (e) {
      debugPrint('⚠️ Heartbeat failed: $e');
    }
  }

  /// Check if a device is considered active.
  /// Uses is_active flag + freshness of last heartbeat.
  static bool isDeviceActive(Map<String, dynamic> device) {
    final isActive = device['is_active'] as bool? ?? false;
    if (!isActive) return false;

    // Prefer last_active (guaranteed column), fall back to last_active_at
    final lastActiveStr = (device['last_active'] as String?) ??
        (device['last_active_at'] as String?);
    if (lastActiveStr == null) return false;

    try {
      final lastActive = DateTime.parse(lastActiveStr);
      final elapsed = DateTime.now().toUtc().difference(lastActive);
      return elapsed < staleThreshold;
    } catch (e) {
      return false;
    }
  }

  /// Subscribe to real-time changes on all devices for the current user.
  /// Returns a RealtimeChannel that can be unsubscribed later.
  static RealtimeChannel subscribeToUserDevices(
    String userId,
    void Function(List<Map<String, dynamic>> devices) onUpdate,
  ) {
    return _supabase
        .channel('user_devices_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'devices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            // Re-fetch all devices when any change occurs
            try {
              final devices = await _supabase
                  .from('devices')
                  .select()
                  .eq('user_id', userId)
                  .order('paired_at', ascending: false);
              onUpdate(List<Map<String, dynamic>>.from(devices));
            } catch (e) {
              debugPrint('⚠️ Failed to fetch devices after update: $e');
            }
          },
        )
        .subscribe();
  }
}
