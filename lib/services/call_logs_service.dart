import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';

class CallLogsService {
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
      {int limit = 100}) async {
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
          'name': (entry.name == null || entry.name!.isEmpty) ? 'Unknown' : entry.name,
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
}
