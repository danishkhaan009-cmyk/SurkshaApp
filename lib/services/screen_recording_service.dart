import 'package:flutter/services.dart';

/// Service class for managing screen recording with auto-start capabilities
///
/// This service provides:
/// - Auto-recording when device unlocks
/// - Auto-recording when child uses device
/// - Manual recording control from parent
/// - Session tracking and status monitoring
class ScreenRecordingService {
  static const platform = MethodChannel('parental_control/permissions');

  /// Enable or disable automatic recording
  ///
  /// [enabled] - true to enable, false to disable
  /// [trigger] - When to trigger recording:
  ///   - 'unlock': Start recording when device unlocks
  ///   - 'usage': Start recording when child uses apps
  ///   - 'both': Start on both unlock and usage
  ///   - 'none': Disable auto-recording
  ///
  /// Example:
  /// ```dart
  /// await ScreenRecordingService.setAutoRecording(
  ///   enabled: true,
  ///   trigger: 'unlock',
  /// );
  /// ```
  static Future<void> setAutoRecording({
    required bool enabled,
    required String trigger,
  }) async {
    try {
      await platform.invokeMethod('setAutoRecordingEnabled', {
        'enabled': enabled,
        'trigger': trigger,
      });
      print(
          '✅ Auto-recording ${enabled ? 'enabled' : 'disabled'} with trigger: $trigger');
    } catch (e) {
      print('❌ Error setting auto-recording: $e');
      rethrow;
    }
  }

  /// Enable or disable manual recording (parent-controlled)
  ///
  /// [enabled] - true to start recording, false to stop
  ///
  /// Example:
  /// ```dart
  /// // Parent starts recording
  /// await ScreenRecordingService.setManualRecording(true);
  ///
  /// // Parent stops recording
  /// await ScreenRecordingService.setManualRecording(false);
  /// ```
  static Future<void> setManualRecording(bool enabled) async {
    try {
      await platform.invokeMethod('setManualRecordingEnabled', {
        'enabled': enabled,
      });
      print('✅ Manual recording ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      print('❌ Error setting manual recording: $e');
      rethrow;
    }
  }

  /// Request screen recording permission (MediaProjection)
  ///
  /// Must be called before recording can start.
  /// Shows Android system dialog to grant permission.
  ///
  /// Example:
  /// ```dart
  /// final hasPermission = await ScreenRecordingService.hasScreenRecordingPermission();
  /// if (!hasPermission) {
  ///   await ScreenRecordingService.requestScreenRecordingPermission();
  /// }
  /// ```
  static Future<void> requestScreenRecordingPermission() async {
    try {
      await platform.invokeMethod('requestScreenRecordingPermission');
      print('📱 Screen recording permission requested');
    } catch (e) {
      print('❌ Error requesting permission: $e');
      rethrow;
    }
  }

  /// Check if screen recording permission is granted
  ///
  /// Returns true if MediaProjection permission is granted
  ///
  /// Example:
  /// ```dart
  /// final hasPermission = await ScreenRecordingService.hasScreenRecordingPermission();
  /// if (!hasPermission) {
  ///   // Show UI to request permission
  /// }
  /// ```
  static Future<bool> hasScreenRecordingPermission() async {
    try {
      final result =
          await platform.invokeMethod('hasScreenRecordingPermission');
      return result ?? false;
    } catch (e) {
      print('❌ Error checking permission: $e');
      return false;
    }
  }

  /// Check if auto-recording is currently enabled
  ///
  /// Returns true if auto-recording is enabled on child device
  ///
  /// Example:
  /// ```dart
  /// final isEnabled = await ScreenRecordingService.isAutoRecordingEnabled();
  /// print('Auto-recording: ${isEnabled ? 'ON' : 'OFF'}');
  /// ```
  static Future<bool> isAutoRecordingEnabled() async {
    try {
      final result = await platform.invokeMethod('isAutoRecordingEnabled');
      return result ?? false;
    } catch (e) {
      print('❌ Error checking auto-recording status: $e');
      return false;
    }
  }

  /// Check if manual recording is currently active
  ///
  /// Returns true if manual recording is active
  ///
  /// Example:
  /// ```dart
  /// final isRecording = await ScreenRecordingService.isManualRecordingEnabled();
  /// print('Recording: ${isRecording ? 'ACTIVE' : 'STOPPED'}');
  /// ```
  static Future<bool> isManualRecordingEnabled() async {
    try {
      final result = await platform.invokeMethod('isManualRecordingEnabled');
      return result ?? false;
    } catch (e) {
      print('❌ Error checking manual recording status: $e');
      return false;
    }
  }

  /// Get comprehensive recording status
  ///
  /// Returns a map with:
  /// - autoEnabled: Whether auto-recording is enabled
  /// - manualEnabled: Whether manual recording is active
  /// - hasPermission: Whether screen recording permission is granted
  ///
  /// Example:
  /// ```dart
  /// final status = await ScreenRecordingService.getRecordingStatus();
  /// print('Auto: ${status['autoEnabled']}');
  /// print('Manual: ${status['manualEnabled']}');
  /// print('Permission: ${status['hasPermission']}');
  /// ```
  static Future<Map<String, bool>> getRecordingStatus() async {
    try {
      final isAuto = await isAutoRecordingEnabled();
      final isManual = await isManualRecordingEnabled();
      final hasPermission = await hasScreenRecordingPermission();

      return {
        'autoEnabled': isAuto,
        'manualEnabled': isManual,
        'hasPermission': hasPermission,
      };
    } catch (e) {
      print('❌ Error getting status: $e');
      return {
        'autoEnabled': false,
        'manualEnabled': false,
        'hasPermission': false,
      };
    }
  }

  /// Initialize the recording service on child device
  ///
  /// [deviceId] - Child device ID
  /// [supabaseUrl] - Supabase project URL
  /// [supabaseKey] - Supabase anon key
  ///
  /// Example:
  /// ```dart
  /// await ScreenRecordingService.initialize(
  ///   deviceId: 'child-device-123',
  ///   supabaseUrl: 'https://xxx.supabase.co',
  ///   supabaseKey: 'your-anon-key',
  /// );
  /// ```
  static Future<void> initialize({
    required String deviceId,
    required String supabaseUrl,
    required String supabaseKey,
  }) async {
    try {
      await platform.invokeMethod('initScreenRecordService', {
        'deviceId': deviceId,
        'supabaseUrl': supabaseUrl,
        'supabaseKey': supabaseKey,
      });
      print('✅ Screen recording service initialized for device: $deviceId');
    } catch (e) {
      print('❌ Error initializing service: $e');
      rethrow;
    }
  }
}

/// Recording trigger types
enum RecordingTrigger {
  /// Start recording when device unlocks
  unlock('unlock'),

  /// Start recording when child uses apps
  usage('usage'),

  /// Start on both unlock and app usage
  both('both'),

  /// Don't auto-record (manual only)
  none('none');

  final String value;
  const RecordingTrigger(this.value);
}

/// Extension to make trigger usage easier
extension RecordingTriggerExtension on RecordingTrigger {
  /// Get the string value for API calls
  String get apiValue => value;

  /// User-friendly description
  String get description {
    switch (this) {
      case RecordingTrigger.unlock:
        return 'Record when device unlocks';
      case RecordingTrigger.usage:
        return 'Record when child uses apps';
      case RecordingTrigger.both:
        return 'Record on unlock and app usage';
      case RecordingTrigger.none:
        return 'Manual recording only';
    }
  }
}

/// Helper class for building recording control UI
class RecordingControlsWidget {
  /// Create a recording controls widget
  ///
  /// Example usage in your widget:
  /// ```dart
  /// class _MyWidgetState extends State<MyWidget> {
  ///   bool _autoEnabled = false;
  ///   bool _manualEnabled = false;
  ///   RecordingTrigger _trigger = RecordingTrigger.unlock;
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return Column(
  ///       children: [
  ///         // Manual Recording Toggle
  ///         SwitchListTile(
  ///           title: Text('Manual Recording'),
  ///           subtitle: Text('Start/stop recording manually'),
  ///           value: _manualEnabled,
  ///           onChanged: (value) async {
  ///             await ScreenRecordingService.setManualRecording(value);
  ///             setState(() => _manualEnabled = value);
  ///           },
  ///         ),
  ///
  ///         Divider(),
  ///
  ///         // Auto-Recording Toggle
  ///         SwitchListTile(
  ///           title: Text('Auto-Recording'),
  ///           subtitle: Text('Automatically record child activity'),
  ///           value: _autoEnabled,
  ///           onChanged: (value) async {
  ///             await ScreenRecordingService.setAutoRecording(
  ///               enabled: value,
  ///               trigger: _trigger.apiValue,
  ///             );
  ///             setState(() => _autoEnabled = value);
  ///           },
  ///         ),
  ///
  ///         // Trigger Selection
  ///         if (_autoEnabled) ...[
  ///           ...RecordingTrigger.values.map((trigger) {
  ///             if (trigger == RecordingTrigger.none) return SizedBox.shrink();
  ///             return RadioListTile<RecordingTrigger>(
  ///               title: Text(trigger.description),
  ///               value: trigger,
  ///               groupValue: _trigger,
  ///               onChanged: (value) async {
  ///                 if (value != null) {
  ///                   await ScreenRecordingService.setAutoRecording(
  ///                     enabled: true,
  ///                     trigger: value.apiValue,
  ///                   );
  ///                   setState(() => _trigger = value);
  ///                 }
  ///               },
  ///             );
  ///           }).toList(),
  ///         ],
  ///       ],
  ///     );
  ///   }
  /// }
  /// ```
  static const String exampleUsage = '''
See class documentation for complete example of building UI controls.
''';
}
