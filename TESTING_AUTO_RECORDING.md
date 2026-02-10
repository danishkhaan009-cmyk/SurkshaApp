# 🧪 TESTING GUIDE - Auto-Recording Feature

## Prerequisites Checklist

Before running the app, make sure:

- [ ] ✅ Supabase SQL migration executed (`create_recording_sessions_table.sql`)
- [ ] ✅ Android device connected via USB
- [ ] ✅ USB Debugging enabled on Android device
- [ ] ✅ Google Drive connected on test device (for video uploads)

---

## 🚀 Running the App

### Step 1: Build and Install

Run this command to install on connected Android device:

```bash
flutter run -d V308242120314
```

Or to run on any connected Android device:

```bash
flutter run
```

### Step 2: First-Time Setup on Device

When app opens:

1. **Grant Required Permissions:**
   - Screen Recording Permission (MediaProjection)
   - Accessibility Permission
   - Usage Access Permission
   - Location Permission
   - Camera and Microphone (for camera recording)

2. **Connect Google Drive:**
   - Go to Settings or Recording tab
   - Tap "Connect Google Drive"
   - Sign in with Google account
   - Grant Drive file access permission

3. **Set Up Child Mode:**
   - Enable "Child Mode" in settings
   - Note the Device ID shown

---

## 🧪 Testing Scenarios

### Test 1: Auto-Recording on Device Unlock ✓

**Setup:**
```dart
// In parent app or test code
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'unlock',
);
```

**Test Steps:**
1. Enable auto-recording with 'unlock' trigger
2. Lock the device (press power button)
3. Wait 2 seconds
4. Unlock the device
5. **Expected**: Notification appears: "Suraksha Auto-Recording Active"
6. Open notification shade - should see recording notification
7. Wait 30 seconds
8. **Verify in Supabase:**
   ```sql
   SELECT * FROM recording_sessions 
   WHERE started_by = 'auto_unlock' 
   ORDER BY started_at DESC LIMIT 1;
   ```

**Success Criteria:**
- ✅ Recording starts within 2 seconds of unlock
- ✅ Notification shows
- ✅ Session created in Supabase with `started_by='auto_unlock'`
- ✅ `trigger_event='device_unlock'`

---

### Test 2: Auto-Recording on App Usage ✓

**Setup:**
```dart
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'usage',
);
```

**Test Steps:**
1. Enable auto-recording with 'usage' trigger
2. Minimize the app (go to home screen)
3. Wait 5 seconds
4. Open the app again
5. **Expected**: Recording starts immediately
6. **Verify in Supabase:**
   ```sql
   SELECT * FROM recording_sessions 
   WHERE started_by = 'auto_usage' 
   ORDER BY started_at DESC LIMIT 1;
   ```

**Success Criteria:**
- ✅ Recording starts when app comes to foreground
- ✅ Session created with `started_by='auto_usage'`
- ✅ `trigger_event='app_launch'`

---

### Test 3: Manual Parent Control ✓

**Setup:**
```dart
// Parent starts recording
await ScreenRecordingService.setManualRecording(true);
```

**Test Steps:**
1. From parent device/test code, enable manual recording
2. Child device should start recording immediately
3. Wait 6 minutes (to test segment upload)
4. Check for upload notification
5. Stop recording:
   ```dart
   await ScreenRecordingService.setManualRecording(false);
   ```
6. **Verify in Supabase:**
   ```sql
   SELECT * FROM recording_sessions 
   WHERE started_by = 'parent' 
   ORDER BY started_at DESC LIMIT 1;
   ```

**Success Criteria:**
- ✅ Recording starts on child device
- ✅ First segment (5 min) uploads to Drive
- ✅ Second segment starts automatically
- ✅ Recording stops when parent disables
- ✅ Session marked as 'stopped' in database

---

### Test 4: Segment Upload (5-minute chunks) ✓

**Test Steps:**
1. Start any recording (manual or auto)
2. Let it run for 6+ minutes
3. Monitor logcat:
   ```bash
   adb logcat | grep -E "ScreenRecordService|GoogleDriveUploader"
   ```
4. **Expected**: 
   - After 5 minutes: "⏰ 5 minutes elapsed - saving and restarting"
   - Upload starts
   - New segment begins
5. **Verify in Supabase:**
   ```sql
   SELECT device_id, file_name, duration_seconds, status, drive_link
   FROM screen_recordings
   WHERE recorded_at > NOW() - INTERVAL '10 minutes'
   ORDER BY recorded_at DESC;
   ```

**Success Criteria:**
- ✅ First segment exactly 5 minutes
- ✅ Upload to Google Drive successful
- ✅ Metadata saved to `screen_recordings` table
- ✅ Local file deleted after upload
- ✅ Second segment starts automatically
- ✅ Session `segments_count` increments

---

### Test 5: Recording Stops on Screen Lock ✓

**Test Steps:**
1. Start any recording
2. Let it record for 30 seconds
3. Lock the device (press power button)
4. **Expected**: Recording stops
5. **Verify in Supabase:**
   ```sql
   SELECT status, stopped_at 
   FROM recording_sessions 
   WHERE id = 'LATEST_SESSION_ID';
   ```

**Success Criteria:**
- ✅ Recording stops within 2 seconds of lock
- ✅ Notification dismissed
- ✅ Session status changed to 'stopped'
- ✅ `stopped_at` timestamp recorded
- ✅ Final segment uploaded

---

## 📊 Monitoring Commands

### View Logs in Real-Time:

```bash
# Android logcat for all recording events
adb logcat | grep -E "ScreenRecordService|ScreenStateReceiver|MainActivity"

# Just recording events
adb logcat | grep "ScreenRecordService"

# Just upload events
adb logcat | grep "GoogleDriveUploader"
```

### Check Recording Status:

```dart
// In Flutter app
final status = await ScreenRecordingService.getRecordingStatus();
print('Auto-recording: ${status['autoEnabled']}');
print('Manual recording: ${status['manualEnabled']}');
print('Has permission: ${status['hasPermission']}');
```

### Supabase Quick Queries:

```sql
-- Active sessions right now
SELECT COUNT(*) FROM recording_sessions WHERE status = 'active';

-- Total recordings today
SELECT COUNT(*) FROM recording_sessions 
WHERE started_at::date = CURRENT_DATE;

-- Total recording time today (in minutes)
SELECT SUM(total_duration_seconds) / 60 as minutes
FROM recording_sessions 
WHERE started_at::date = CURRENT_DATE;

-- Latest session details
SELECT * FROM recording_sessions 
ORDER BY started_at DESC LIMIT 1;
```

---

## 🐛 Troubleshooting

### Recording Not Starting?

**Check 1: Permissions**
```bash
adb shell dumpsys window | grep "mCurrentFocus"
# Should NOT show lock screen
```

**Check 2: Child Mode Active**
```bash
adb logcat | grep "isChildModeActive"
# Should show "true"
```

**Check 3: MediaProjection Permission**
```bash
adb logcat | grep "MediaProjection"
# Should show "MediaProjection result set"
```

### No Uploads to Google Drive?

**Check 1: Drive Connected**
```bash
adb logcat | grep "GoogleDriveUploader"
# Should show "GoogleDrive initialized"
```

**Check 2: Internet Connection**
```bash
adb shell ping -c 4 google.com
```

### Sessions Not in Supabase?

**Check 1: Table Exists**
```sql
SELECT * FROM information_schema.tables 
WHERE table_name = 'recording_sessions';
```

**Check 2: RLS Policies**
```sql
SELECT * FROM pg_policies 
WHERE tablename = 'recording_sessions';
```

---

## ✅ Success Indicators

You'll know it's working when:

1. **On Device Unlock:**
   - Notification appears within 2 seconds
   - Logcat shows: "🔓 Device UNLOCKED"
   - Logcat shows: "📱 Screen ON & Unlocked - Checking recording modes..."
   - Logcat shows: "▶️ Starting auto-recording (device unlock trigger)"

2. **On App Usage:**
   - Recording starts when app opens
   - Logcat shows: "📱 App resumed - foreground state: true"
   - Logcat shows: "📱 App usage detected - starting auto-recording"

3. **Every 5 Minutes:**
   - Logcat shows: "⏰ 5 minutes elapsed - saving and restarting"
   - Logcat shows: "☁️ Starting Google Drive upload..."
   - Logcat shows: "✅ Google Drive upload successful!"
   - New row in `screen_recordings` table

4. **In Supabase:**
   - New session in `recording_sessions` table
   - `segments_count` increases over time
   - `total_duration_seconds` increases
   - `last_upload_at` updates every 5 minutes

---

## 🔬 Advanced Testing

### Test Both Triggers:

```dart
await ScreenRecordingService.setAutoRecording(
  enabled: true,
  trigger: 'both',
);
```

Then test:
1. Unlock device → Recording starts
2. Lock device → Recording stops
3. Wait 10 seconds
4. Open app → Recording starts again
5. Both should create separate sessions in database

### Load Test:

1. Enable auto-recording with 'both' trigger
2. Repeatedly lock/unlock device
3. Open/close apps multiple times
4. **Expected**: Each trigger creates new session
5. Old sessions marked as 'stopped'
6. No duplicate recordings

---

## 📋 Test Checklist

- [ ] SQL migration run successfully
- [ ] Device connected and detected
- [ ] App installs without errors
- [ ] All permissions granted
- [ ] Google Drive connected
- [ ] Auto-unlock trigger works
- [ ] Auto-usage trigger works
- [ ] Manual control works
- [ ] 5-minute segments upload
- [ ] Recording stops on lock
- [ ] Sessions tracked in Supabase
- [ ] Videos accessible in Google Drive
- [ ] Notifications show correctly
- [ ] Old sessions cleanup works

---

## 📞 Support

If you encounter issues:

1. Check logs: `adb logcat | grep ScreenRecordService`
2. Verify SQL tables exist in Supabase
3. Confirm child mode is active on device
4. Ensure all permissions granted
5. Check Google Drive connection

**All tests passing = Feature working correctly! ✅**
