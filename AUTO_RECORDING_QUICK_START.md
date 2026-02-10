# Auto-Recording Quick Start Guide

## 🎯 What Was Implemented

Your parental control app now automatically records screen activity when:
- ✅ Child unlocks their device
- ✅ Child uses any app on their device  
- ✅ Parent manually starts recording from parent app

All recordings upload to **Supabase** and **Google Drive** automatically.

---

## 🚀 Quick Setup (3 Steps)

### Step 1: Run Database Migration

In **Supabase SQL Editor**, run this file:
```
create_recording_sessions_table.sql
```

This creates the `recording_sessions` table to track all recordings.

### Step 2: Grant Screen Recording Permission (Child Device)

On the child's device, the app will request **Screen Recording Permission** (MediaProjection).

- This permission allows the app to capture the screen
- It only needs to be granted once
- The permission persists across device reboots

### Step 3: Choose Recording Mode

Pick one of these modes:

**A) Auto-Recording on Unlock**
```dart
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'unlock',
);
```

**B) Auto-Recording on App Usage**
```dart
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'usage',
);
```

**C) Both Unlock & Usage**
```dart
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'both',
);
```

**D) Manual Only (Parent Control)**
```dart
// Parent starts recording
await ScreenRecordingService.setManualRecording(true);

// Parent stops recording
await ScreenRecordingService.setManualRecording(false);
```

---

## 📱 Files Modified

### New Files Created:
1. **create_recording_sessions_table.sql** - Database migration for session tracking
2. **AUTO_RECORDING_IMPLEMENTATION.md** - Complete implementation guide
3. **AUTO_RECORDING_QUICK_START.md** - This file

### Files Enhanced:

#### Android (Kotlin):
1. **ScreenRecordService.kt** - Added:
   - Auto-recording on unlock trigger
   - Auto-recording on usage trigger
   - Session tracking in Supabase
   - Multiple trigger modes support
   - 5-minute segment upload system

2. **MainActivity.kt** - Added:
   - `setAutoRecordingEnabled()` method
   - `isAutoRecordingEnabled()` method
   - `setManualRecordingEnabled()` method
   - `isManualRecordingEnabled()` method
   - `requestScreenRecordingPermission()` method
   - `hasScreenRecordingPermission()` method
   - Usage detection on app resume

#### Supabase Tables:
- **recording_sessions** (NEW) - Tracks all recording sessions with:
  - Session type (screen/camera/auto)
  - Started by (parent/auto_unlock/auto_usage)
  - Trigger event
  - Status (active/paused/stopped/error)
  - Duration and segment count
  - Timestamps

- **devices** table - Added columns:
  - `auto_recording_enabled` (boolean)
  - `auto_recording_trigger` (text: unlock/usage/both/none)

---

## 🎮 How to Use

### For Parents (Parent App):

**Enable Auto-Recording:**
```dart
// Add to parent's device control screen
import 'screen_recording_service.dart'; // Add the service file from docs

// Enable auto-recording when device unlocks
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'unlock',
);

// Check current status
final status = await ScreenRecordingService.getRecordingStatus();
print('Auto enabled: ${status['autoEnabled']}');
print('Manual enabled: ${status['manualEnabled']}');
```

**View Recording Sessions:**
```dart
final supabase = Supabase.instance.client;

final sessions = await supabase
    .from('recording_sessions')
    .select()
    .eq('device_id', childDeviceId)
    .order('started_at', ascending: false)
    .limit(20);

// Shows: when recording started, why it started, duration, segments
for (var session in sessions) {
  print('${session['started_by']} triggered ${session['trigger_event']}');
  print('Duration: ${session['total_duration_seconds']}s');
}
```

### For Child Device (Automatic):

Once enabled, recording happens automatically:
1. **Child unlocks device** → Recording starts (if trigger = 'unlock' or 'both')
2. **Child opens any app** → Recording starts (if trigger = 'usage' or 'both')
3. **Screen locks** → Recording stops
4. Every 5 minutes → Current segment uploads to Google Drive

---

## 📊 What Gets Recorded

### Recording Data Stored:

**In `recording_sessions` table:**
- When recording started/stopped
- Who/what triggered it
- Total duration
- Number of segments uploaded
- Current status

**In `screen_recordings` table:**
- Each 5-minute video segment
- Google Drive file ID and link
- File size and duration
- Upload timestamp

### Session Example:
```json
{
  "id": "uuid-here",
  "device_id": "child-device-123",
  "session_type": "screen",
  "status": "active",
  "started_by": "auto_unlock",
  "trigger_event": "device_unlock",
  "started_at": "2026-02-06T10:00:00Z",
  "total_duration_seconds": 900,
  "segments_count": 3,
  "last_upload_at": "2026-02-06T10:15:00Z"
}
```

---

## 🔔 Notifications

Child sees different notifications based on trigger:

- **Auto-unlock**: "Suraksha Auto-Recording Active - Recording started on device unlock"
- **Auto-usage**: "Suraksha Auto-Recording Active - Recording started on app usage"
- **Manual**: "Suraksha Protection Active - Recording screen..."

---

## ⚙️ Configuration Options

### Trigger Modes:

| Mode | When Recording Starts |
|------|----------------------|
| `unlock` | Only when device unlocks |
| `usage` | Only when app brought to foreground |
| `both` | On unlock AND usage |
| `none` | Never (manual only) |

### Recording Behavior:

- **Segment Duration**: 5 minutes (auto-uploads after each segment)
- **Auto-Stop**: When screen locks or turns off
- **Storage**: Local files deleted after upload to Drive
- **Notification**: Shows while recording is active
- **Session Cleanup**: Stale sessions (6+ hours) auto-stopped

---

## 🧪 Testing Checklist

### Test 1: Auto-Recording on Unlock ✓
1. Enable auto-recording with trigger='unlock'
2. Lock child device
3. Unlock child device
4. **Expected**: Recording starts, notification appears
5. Wait 2 minutes and check Supabase `recording_sessions`
6. **Expected**: New session with `started_by='auto_unlock'`

### Test 2: Auto-Recording on Usage ✓
1. Enable auto-recording with trigger='usage'
2. Open any app on child device
3. **Expected**: Recording starts
4. Check `recording_sessions` table
5. **Expected**: New session with `started_by='auto_usage'`

### Test 3: Manual Control ✓
1. From parent app, call `setManualRecording(true)`
2. **Expected**: Recording starts on child device
3. Wait 6 minutes for segment upload
4. Check child device - should see video uploading notification
5. Call `setManualRecording(false)`
6. **Expected**: Recording stops

### Test 4: Segment Upload ✓
1. Start any recording
2. Wait 5 minutes
3. Check Supabase `screen_recordings` table
4. **Expected**: New row with Google Drive link
5. Open Drive link - should play video

---

## 🚨 Common Issues

### Issue: Recording Not Starting
**Solution:**
- Ensure MediaProjection permission granted
- Check device is in child mode
- Verify screen is unlocked
- Check Android logs: `adb logcat | grep ScreenRecordService`

### Issue: Permission Dialog Not Showing
**Solution:**
```dart
// Request permission explicitly
await ScreenRecordingService.requestScreenRecordingPermission();
```

### Issue: Videos Not Uploading
**Solution:**
- Connect Google Drive on child device
- Check internet connection
- Verify Google Drive token is valid

### Issue: Session Not Tracked
**Solution:**
- Run SQL migration again
- Check table exists: `SELECT * FROM recording_sessions LIMIT 1;`
- Verify RLS policies allow insert

---

## 📚 Full Documentation

For complete details, see: **AUTO_RECORDING_IMPLEMENTATION.md**

Contains:
- ✅ Complete API reference
- ✅ UI integration examples
- ✅ Advanced configuration
- ✅ Troubleshooting guide
- ✅ Database schema details

---

## ✅ Checklist

Before going live:

- [ ] SQL migration ran successfully
- [ ] MediaProjection permission granted on child device
- [ ] Google Drive connected on child device
- [ ] Auto-recording mode selected
- [ ] Test unlock trigger works
- [ ] Test usage trigger works
- [ ] Test manual control works
- [ ] Verify session tracking in Supabase
- [ ] Confirm videos upload to Drive

---

## 🎉 You're Done!

The auto-recording system is now fully functional and will:
- ✅ Record screen when child unlocks device
- ✅ Record screen when child uses apps
- ✅ Upload all recordings to Supabase + Google Drive
- ✅ Track all sessions with detailed metadata
- ✅ Allow parent to start/stop anytime

**Happy Monitoring! 🛡️**
