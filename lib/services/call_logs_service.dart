import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallLogsService {
  static final _supabase = Supabase.instance.client;
  static Timer? _periodicCallLogsSyncTimer;

  /// Request call log permissions
  static Future<bool> requestPermissions() async {
    try {
      // Requesting multiple permissions related to call logs
      Map<Permission, PermissionStatus> statuses = await [
        Permission.phone,
        Permission.contacts,
      ].request();

      // Specifically check for READ_CALL_LOG if possible via Permission.phone or similar
      // Note: On Android, READ_CALL_LOG is often bundled with Permission.phone in some plugins,
      // but permission_handler uses Permission.contacts or Permission.phone depending on the OS version.

      return statuses[Permission.phone]!.isGranted;
    } catch (e) {
      print('❌ Error requesting call log permissions: $e');
      return false;
    }
  }

  /// Check if call log permissions are granted
  static Future<bool> hasPermissions() async {
    try {
      final status = await Permission.phone.status;
      return status.isGranted;
    } catch (e) {
      print('❌ Error checking call log permissions: $e');
      return false;
    }
  }

  /// Fetch call logs from the device
  static Future<List<Map<String, dynamic>>> getCallLogs(
      {int limit = 50}) async {
    try {
      print('📞 Attempting to fetch call logs...');

      // Check permissions
      bool hasPermission = await hasPermissions();
      if (!hasPermission) {
        print('⚠️ Call log permission not granted, requesting...');
        hasPermission = await requestPermissions();
        if (!hasPermission) {
          print('❌ Call log permission denied');
          // On some Android versions, we need to explicitly ask for contacts too for names
          return [];
        }
      }

      // Fetch call logs
      // Use a more specific query if needed, or just get all
      final Iterable<CallLogEntry> entries = await CallLog.get();
      print('📞 Found ${entries.length} raw call log entries');

      if (entries.isEmpty) {
        print('ℹ️ No call logs found on device or empty result returned.');
        return [];
      }

      // Convert to map format
      List<Map<String, dynamic>> callLogs = entries.take(limit).map((entry) {
        return {
          'name': (entry.name == null || entry.name!.isEmpty)
              ? 'Unknown'
              : entry.name,
          'number': entry.number ?? 'Unknown',
          'formattedNumber': entry.formattedNumber ?? entry.number ?? 'Unknown',
          'callType': _getCallTypeString(entry.callType),
          'callTypeIcon': _getCallTypeIcon(entry.callType),
          'duration': entry.duration ?? 0, // in seconds
          'timestamp': entry.timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(entry.timestamp!)
              : null,
          'cachedNumberType': entry.cachedNumberType,
          'cachedNumberLabel': entry.cachedNumberLabel,
        };
      }).toList();

      print('✅ Successfully converted ${callLogs.length} call logs');
      return callLogs;
    } catch (e, stackTrace) {
      print('❌ Exception in getCallLogs: $e');
      print('Stack trace: $stackTrace');
      return []; // Return empty list instead of rethrowing to prevent UI crashes
    }
  }

  /// Get call type as string
  static String _getCallTypeString(CallType? callType) {
    switch (callType) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
      case CallType.rejected:
        return 'Rejected';
      case CallType.blocked:
        return 'Blocked';
      case CallType.voiceMail:
        return 'Voicemail';
      case CallType.wifiIncoming:
        return 'WiFi Incoming';
      case CallType.wifiOutgoing:
        return 'WiFi Outgoing';
      default:
        return 'Unknown';
    }
  }

  /// Get icon for call type
  static String _getCallTypeIcon(CallType? callType) {
    switch (callType) {
      case CallType.incoming:
        return 'call_received';
      case CallType.outgoing:
        return 'call_made';
      case CallType.missed:
        return 'call_missed';
      case CallType.rejected:
        return 'call_end';
      case CallType.blocked:
        return 'block';
      case CallType.voiceMail:
        return 'voicemail';
      case CallType.wifiIncoming:
        return 'wifi_calling';
      case CallType.wifiOutgoing:
        return 'wifi_calling';
      default:
        return 'phone';
    }
  }

  /// Format duration in seconds to readable format
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  /// Format timestamp to readable format
  static String formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  // ==================== DATABASE SYNC METHODS ====================

  /// Fetches call logs from the device and uploads to the database
  static Future<void> syncCallLogs(String deviceId) async {
    try {
      print('📞 Starting call logs sync for device: $deviceId');
      final callLogs = await getCallLogs(limit: 50);

      if (callLogs.isEmpty) {
        print('⚠️ No call logs found to sync.');
        return;
      }

      final records = callLogs
          .map((call) => {
                'device_id': deviceId,
                'name': call['name'],
                'number': call['number'],
                'formatted_number': call['formattedNumber'],
                'call_type': call['callType'],
                'call_type_icon': call['callTypeIcon'],
                'duration': call['duration'],
                'timestamp': call['timestamp'] != null
                    ? (call['timestamp'] as DateTime).toIso8601String()
                    : null,
                'cached_number_type': call['cachedNumberType'],
                'cached_number_label': call['cachedNumberLabel'],
                'synced_at': DateTime.now().toIso8601String(),
              })
          .toList();

      // Upsert into the database
      await _supabase.from('call_logs').upsert(
            records,
            onConflict: 'device_id, number, timestamp, call_type',
          );

      print('✅ Successfully synced ${records.length} call logs to database.');
    } catch (e) {
      print('❌ Error syncing call logs: $e');
    }
  }

  /// Start periodic background sync for call logs
  /// Syncs every 10 minutes to keep parent's view updated
  static void startPeriodicCallLogsSync(String deviceId) {
    print('🔄 Starting periodic call logs sync for device: $deviceId');

    // Stop any existing timer
    stopPeriodicCallLogsSync();

    // Initial sync
    syncCallLogs(deviceId);

    // Set up periodic sync every 10 minutes
    _periodicCallLogsSyncTimer =
        Timer.periodic(const Duration(minutes: 10), (timer) {
      print('⏰ Periodic call logs sync triggered');
      syncCallLogs(deviceId);
    });
  }

  /// Stop periodic call logs sync
  static void stopPeriodicCallLogsSync() {
    _periodicCallLogsSyncTimer?.cancel();
    _periodicCallLogsSyncTimer = null;
    print('🛑 Stopped periodic call logs sync');
  }

  /// Fetches call logs for a specific device from the database
  static Future<List<Map<String, dynamic>>> fetchCallLogsFromDb(
      String deviceId) async {
    try {
      print('📡 Fetching call logs for device: $deviceId from database');
      final response = await _supabase
          .from('call_logs')
          .select()
          .eq('device_id', deviceId)
          .order('timestamp', ascending: false)
          .limit(50);

      print('✅ Fetched ${response.length} call logs from database.');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching call logs: $e');
      return [];
    }
  }

  /// Subscribe to real-time changes for a device's call logs
  static Stream<List<Map<String, dynamic>>> watchCallLogs(String deviceId) {
    print('👁️ Setting up real-time watch for call logs: $deviceId');

    return _supabase
        .from('call_logs')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('timestamp', ascending: false)
        .map((data) {
          print('📡 Real-time call logs update received: ${data.length} calls');
          return List<Map<String, dynamic>>.from(data);
        });
  }
}
