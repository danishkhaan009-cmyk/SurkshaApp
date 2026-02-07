# Auto-Recording Implementation Guide

## Overview

This implementation adds automatic screen recording capabilities that trigger when:
1. **Device is unlocked** - Recording starts automatically when child unlocks the device
2. **Child uses device** - Recording starts when child brings the app to foreground
3. **Parent controls** - Parent can manually start/stop recording from their device

All recordings are uploaded to both **Supabase** and **Google Drive** with comprehensive session tracking.

---

## 🚀 Features Added

### 1. **Auto-Recording on Device Unlock**
- Automatically starts screen recording when child unlocks their device
- Recording continues until device is locked or screen turns off
- Tracks unlock events and creates recording sessions

### 2. **Auto-Recording on App Usage**  
- Detects when child brings any app to foreground
- Starts recording immediately upon app usage
- Perfect for monitoring what apps child is actively using

### 3. **Parent Manual Control**
- Parent can start/stop recording anytime from parent app
- Overrides auto-recording settings
- Real-time status updates

### 4. **Session Tracking**
- Every recording session is tracked in Supabase (`recording_sessions` table)
- Records: start time, stop time, duration, trigger type, segments count
- Helps parents see when and why recordings were triggered

### 5. **Continuous Recording with Segments**
- Records in 5-minute segments automatically
- Uploads each segment to Google Drive immediately
- No storage issues - segments deleted after upload

---

## 📊 Database Setup

### Step 1: Create the Database Table

Run the SQL migration file to create the `recording_sessions` table:

```bash
# In Supabase SQL Editor, run:
c:\Users\Deep Chand\Downloads\without_database23Jan2026\without_database18Jan2025\without_database 2\create_recording_sessions_table.sql
```

This creates:
- `recording_sessions` table - Tracks all recording sessions
- Adds `auto_recording_enabled` column to `devices` table
- Adds `auto_recording_trigger` column to `devices` table
- Sets up Row Level Security policies
- Creates automatic cleanup for stale sessions

---

## 🔧 Implementation in Flutter App

### For Child Device (Android):

The implementation is already complete in the Kotlin files. The auto-recording will work automatically once enabled.

### Add Method Channels in Flutter:

In your Flutter code where you want to control auto-recording:

```dart
import 'package:flutter/services.dart';

class ScreenRecordingService {
  static const platform = MethodChannel('parental_control/permissions');
  
  // Enable/disable auto-recording
  static Future<void> setAutoRecording({
    required bool enabled,
    required String trigger, // 'unlock', 'usage', 'both', or 'none'
  }) async {
    try {
      await platform.invokeMethod('setAutoRecordingEnabled', {
        'enabled': enabled,
        'trigger': trigger,
      });
      print('✅ Auto-recording ${enabled ? 'enabled' : 'disabled'} with trigger: $trigger');
    } catch (e) {
      print('❌ Error setting auto-recording: $e');
    }
  }
  
  // Enable/disable manual recording (parent-controlled)
  static Future<void> setManualRecording(bool enabled) async {
    try {
      await platform.invokeMethod('setManualRecordingEnabled', {
        'enabled': enabled,
      });
      print('✅ Manual recording ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      print('❌ Error setting manual recording: $e');
    }
  }
  
  // Request screen recording permission (MediaProjection)
  static Future<void> requestScreenRecordingPermission() async {
    try {
      await platform.invokeMethod('requestScreenRecordingPermission');
    } catch (e) {
      print('❌ Error requesting permission: $e');
    }
  }
  
  // Check if permission is granted
  static Future<bool> hasScreenRecordingPermission() async {
    try {
      final result = await platform.invokeMethod('hasScreenRecordingPermission');
      return result ?? false;
    } catch (e) {
      print('❌ Error checking permission: $e');
      return false;
    }
  }
  
  // Check current statuses
  static Future<Map<String, bool>> getRecordingStatus() async {
    try {
      final isAuto = await platform.invokeMethod('isAutoRecordingEnabled');
      final isManual = await platform.invokeMethod('isManualRecordingEnabled');
      final hasPermission = await hasScreenRecordingPermission();
      
      return {
        'autoEnabled': isAuto ?? false,
        'manualEnabled': isManual ?? false,
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
}
```

---

## 🎮 Usage Examples

### Example 1: Enable Auto-Recording on Unlock

```dart
// In parent app or settings screen
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'unlock', // Start recording when device unlocks
);
```

### Example 2: Enable Auto-Recording on App Usage

```dart
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'usage', // Start recording when child uses apps
);
```

### Example 3: Enable Both Triggers

```dart
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'both', // Start on unlock AND app usage
);
```

### Example 4: Manual Parent Control

```dart
// Parent starts recording manually
await ScreenRecordingService.setManualRecording(true);

// Later... parent stops recording
await ScreenRecordingService.setManualRecording(false);
```

### Example 5: Request Permission First

```dart
// On child device setup
final hasPermission = await ScreenRecordingService.hasScreenRecordingPermission();

if (!hasPermission) {
  await ScreenRecordingService.requestScreenRecordingPermission();
}
```

---

## 📱 UI Integration Example

### Parent Control Screen (Add to childs_device_widget.dart):

```dart
// Add state variables
bool _autoRecordingEnabled = false;
bool _manualRecordingEnabled = false;
String _autoRecordingTrigger = 'unlock';

// Add UI controls
Widget _buildRecordingControls() {
  return Column(
    children: [
      // Manual Recording Toggle
      SwitchListTile(
        title: Text('Manual Recording'),
        subtitle: Text('Start/stop recording manually'),
        value: _manualRecordingEnabled,
        onChanged: (value) async {
          await ScreenRecordingService.setManualRecording(value);
          setState(() {
            _manualRecordingEnabled = value;
          });
        },
      ),
      
      Divider(),
      
      // Auto-Recording Toggle
      SwitchListTile(
        title: Text('Auto-Recording'),
        subtitle: Text('Automatically record child activity'),
        value: _autoRecordingEnabled,
        onChanged: (value) async {
          await ScreenRecordingService.setAutoRecording(
            enabled: value,
            trigger: _autoRecordingTrigger,
          );
          setState(() {
            _autoRecordingEnabled = value;
          });
        },
      ),
      
      // Trigger Selection (only show if auto-recording enabled)
      if (_autoRecordingEnabled) ...[
        RadioListTile<String>(
          title: Text('On Device Unlock'),
          value: 'unlock',
          groupValue: _autoRecordingTrigger,
          onChanged: (value) async {
            if (value != null) {
              await ScreenRecordingService.setAutoRecording(
                enabled: true,
                trigger: value,
              );
              setState(() {
                _autoRecordingTrigger = value;
              });
            }
          },
        ),
        RadioListTile<String>(
          title: Text('On App Usage'),
          value: 'usage',
          groupValue: _autoRecordingTrigger,
          onChanged: (value) async {
            if (value != null) {
              await ScreenRecordingService.setAutoRecording(
                enabled: true,
                trigger: value,
              );
              setState(() {
                _autoRecordingTrigger = value;
              });
            }
          },
        ),
        RadioListTile<String>(
          title: Text('Both Unlock & Usage'),
          value: 'both',
          groupValue: _autoRecordingTrigger,
          onChanged: (value) async {
            if (value != null) {
              await ScreenRecordingService.setAutoRecording(
                enabled: true,
                trigger: value,
              );
              setState(() {
                _autoRecordingTrigger = value;
              });
            }
          },
        ),
      ],
    ],
  );
}
```

---

## 🔍 Viewing Recording Sessions

### Query Recording Sessions from Supabase:

```dart
Future<List<Map<String, dynamic>>> getRecordingSessions(String deviceId) async {
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('recording_sessions')
      .select()
      .eq('device_id', deviceId)
      .order('started_at', ascending: false)
      .limit(50);
  
  return List<Map<String, dynamic>>.from(response as List);
}

// Display sessions
void displaySessions() async {
  final sessions = await getRecordingSessions(widget.deviceId!);
  
  for (var session in sessions) {
    print('Session: ${session['id']}');
    print('  Type: ${session['session_type']}');
    print('  Started by: ${session['started_by']}');
    print('  Trigger: ${session['trigger_event']}');
    print('  Status: ${session['status']}');
    print('  Duration: ${session['total_duration_seconds']}s');
    print('  Segments: ${session['segments_count']}');
    print('  Started: ${session['started_at']}');
    print('  Stopped: ${session['stopped_at']}');
  }
}
```

---

## 📋 How It Works

### Recording Flow:

1. **Trigger Event Occurs**
   - Device unlocks OR
   - Child opens app OR
   - Parent manually starts

2. **Permission Check**
   - Verifies MediaProjection permission granted
   - Confirms child mode is active
   - Checks screen is on and unlocked

3. **Session Created**
   - New record in `recording_sessions` table
   - Tracks: trigger type, start time, status

4. **Recording Starts**
   - Screen recording begins
   - Notification shows on child device
   - Records in 5-minute segments

5. **Segment Upload**
   - Every 5 minutes, current segment uploads to Google Drive
   - Metadata saved to `screen_recordings` table
   - Local file deleted after upload
   - New segment starts automatically

6. **Session Updates**
   - Total duration increments
   - Segments count increments
   - Last upload timestamp updated

7. **Recording Stops**
   - Screen locks/turns off OR
   - Auto-recording disabled OR
   - Parent manually stops
   
8. **Session Completed**
   - Final segment uploads
   - Session status set to 'stopped'
   - Stop timestamp recorded

---

## 🛠️ Testing

### Test Auto-Recording on Unlock:

1. Enable auto-recording with 'unlock' trigger
2. Lock child device
3. Unlock child device
4. Check notification appears: "Suraksha Auto-Recording Active"
5. Wait 5 minutes
6. Check Supabase - should see recording uploaded

### Test Auto-Recording on Usage:

1. Enable auto-recording with 'usage' trigger
2. Minimize app
3. Open app again
4. Recording should start automatically
5. Check `recording_sessions` table for new session

### Test Manual Recording:

1. From parent app, enable manual recording
2. Child device should start recording immediately
3. From parent app, disable manual recording
4. Recording should stop

---

## 🎯 Session Types

- **`screen`** - Screen recording (continuous)
- **`camera`** - Camera recording (30-second clips)
- **`auto`** - Automatic recording triggered by events

## 🎬 Started By Types

- **`parent`** - Parent manually started recording
- **`auto_unlock`** - Triggered by device unlock
- **`auto_usage`** - Triggered by app usage

## 🔔 Trigger Events

- **`parent_manual`** - Parent clicked start button
- **`device_unlock`** - Device was unlocked
- **`app_launch`** - App brought to foreground
- **`screen_unlocked`** - Screen turned on and unlocked
- **`settings_sync`** - Settings synced from Supabase

---

## ⚙️ Configuration

### Adjust Recording Interval:

In `ScreenRecordService.kt`, line 40:

```kotlin
// Change from 5 minutes to desired duration
private const val RECORDING_INTERVAL_MS = 5 * 60 * 1000L  // 5 minutes
```

### Adjust Session Cleanup:

In SQL migration, modify the auto-stop stale sessions:

```sql
-- Currently set to 6 hours
WHERE started_at < NOW() - INTERVAL '6 hours'
```

---

## 🚨 Troubleshooting

### Recording Not Starting:

1. Check MediaProjection permission granted
2. Verify device is in child mode
3. Ensure screen is on and unlocked
4. Check logs: `adb logcat | grep ScreenRecordService`

### Sessions Not Tracking:

1. Verify SQL migration ran successfully
2. Check RLS policies are correct
3. Test with: `SELECT * FROM recording_sessions;`

### Uploads Failing:

1. Ensure Google Drive is connected
2. Check internet connection on child device
3. Verify Google Drive token is valid
4. Check logs: `adb logcat | grep GoogleDriveUploader`

---

## 📚 Additional Resources

- **Camera Recording Guide**: `CAMERA_RECORDING_VISUAL_GUIDE.md`
- **Testing Guide**: `TESTING_CAMERA_RECORDING.md`
- **Location Tracking**: `LOCATION_FEATURE.md`

---

## ✅ Summary

You now have a complete auto-recording system that:

✓ Records automatically when device unlocks
✓ Records automatically when child uses device  
✓ Allows parent manual start/stop control
✓ Uploads to Supabase and Google Drive
✓ Tracks all sessions with detailed metadata
✓ Records in manageable 5-minute segments
✓ Automatically cleans up after itself

**Next Steps:**
1. Run the SQL migration
2. Test the recording triggers
3. Integrate UI controls in parent app
4. Monitor recording sessions
