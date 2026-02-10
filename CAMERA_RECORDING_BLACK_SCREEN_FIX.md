# Camera Recording Black Screen Fix

## Problem
When recording videos from the child's device, the uploaded videos show only a black screen.

## Root Causes

### 1. **Camera is Covered or Blocked**
- Phone is face down on a table
- Phone is in pocket
- Camera lens is covered by a case or finger
- Recording in a completely dark environment

### 2. **Wrong Camera Selected**
- Back camera may be facing down (black screen)
- Front camera should show the child's face (better for monitoring)

### 3. **No Preview Surface**
- Camera records in background without showing what's being captured
- Child doesn't see that recording is happening (by design for monitoring)

## Solutions Implemented

### ✅ 1. Switch to Front Camera First
```kotlin
// Now uses FRONT camera by default (to see child's face)
// Front camera is less likely to be blocked than back camera
```

**Benefits:**
- Shows child's face (better for monitoring)
- Less likely to be covered (front-facing)
- Child can see they're being recorded (if app is open)

### ✅ 2. File Size Validation
```kotlin
// Rejects files smaller than 10KB (likely black/empty)
if (file.length() < 10 * 1024) {
    Log.e(TAG, "Recording file too small - likely black screen")
    file.delete()
    return
}
```

**Benefits:**
- Prevents uploading useless black videos
- Saves Google Drive storage space
- Provides clear error messages in logs

### ✅ 3. Better Error Logging
```kotlin
Log.d(TAG, "📷 Using FRONT camera (ID: $cameraId) - will show child's face")
Log.e(TAG, "   This usually means: camera was covered, no light, or permission denied")
```

**Benefits:**
- Easier to debug issues
- Clear indication of which camera is being used
- Helpful error messages

### ✅ 4. Reduced Buffer Overflow Issues
```kotlin
// Limited frame rate to 15fps
captureRequestBuilder.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(15, 15))

// Wait for 10 frames before starting recording
if (frameCount >= 10) { ... }

// Added 200ms delay before camera access
backgroundHandler?.postDelayed({ startCameraRecordingInternal() }, 200)
```

**Benefits:**
- Prevents "Can't acquire next buffer" errors
- Smoother recording without UI interference
- Better compatibility with Flutter's rendering

## Testing the Fix

### 1. **Run the app:**
```bash
flutter clean
flutter run
```

### 2. **Test recording scenarios:**

#### ✅ Good Conditions (should work):
- Child holding phone normally
- Phone screen is on and unlocked
- Front camera can see child's face
- Adequate lighting

#### ❌ Bad Conditions (will produce black video):
- Phone face down on table
- Phone in pocket
- Very dark room (no light)
- Camera physically blocked

### 3. **Check logs:**
```bash
adb logcat | grep CameraRecordService
```

Look for:
- `📷 Using FRONT camera` - Confirms front camera is selected
- `✅ Video file validated: XXXkb` - File size validation passed
- `❌ Recording file too small` - File was rejected as black/empty

## How Recording Works

### Parent Side:
1. Parent taps "Start Recording" button (green)
2. Request sent to Supabase database
3. Button changes to "Stop Recording" (red)
4. Manual stop control (no auto-stop UI)

### Child Side:
1. Child device receives recording request from Supabase
2. Checks conditions:
   - ✅ Device must be unlocked
   - ✅ Screen must be on
   - ✅ App must be in foreground
   - ✅ Camera permission granted
   - ✅ Not in cooldown (5 min between recordings)
3. Starts recording from **FRONT camera** for 30 seconds
4. Uploads video to Google Drive
5. Saves record in Supabase `screen_recordings` table
6. Deletes local file after successful upload

### Recording Behavior:
- **Background service** - runs in background with minimal notification
- **No preview shown** - stealth monitoring (child doesn't see what's recorded)
- **Front camera preferred** - shows child's face
- **30 second duration** - fixed length
- **5 minute cooldown** - prevents spam

## Common Issues & Solutions

### Issue: All videos are black
**Solution:**
- Make sure child's device screen is ON and UNLOCKED when recording starts
- Ensure phone is held normally (not face down)
- Check that camera permission is granted
- Verify adequate lighting in the room

### Issue: "Recording request sent but nothing happens"
**Solution:**
- Child device must have app open and in foreground
- Check child's device screen is unlocked
- Wait for child to open the app (request will trigger then)

### Issue: "Can't acquire next buffer" error
**Solution:**
- Already fixed with frame rate limiting
- Ensure latest code is built (`flutter clean && flutter run`)

### Issue: Videos not uploading to Drive
**Solution:**
- Check Google Drive is connected on child device
- Verify internet connection on child device
- Check logs for upload errors

## Recording Quality Settings

Current settings (optimized for small file size):
- **Resolution:** 640x480 (VGA)
- **Frame rate:** 15 fps
- **Video bitrate:** 200 Kbps
- **Duration:** 30 seconds
- **Expected file size:** ~750 KB per video

These settings provide:
- Clear enough video to see child's face
- Small file size for quick upload
- Low data usage
- Good battery efficiency

## Next Steps

1. **Test with real conditions:**
   - Have child device unlocked and open
   - Start recording from parent device
   - Wait 30 seconds
   - Check uploaded video in Drive

2. **Monitor logs:**
   - Use `adb logcat` to see detailed recording process
   - Check for "black screen" rejections
   - Verify front camera is being used

3. **Adjust if needed:**
   - Can switch back to BACK camera if preferred
   - Can adjust file size validation threshold
   - Can increase video quality if needed

## Code Changes Summary

**File:** `CameraRecordService.kt`

1. ✅ Added 200ms delay before camera access
2. ✅ Limited frame rate to 15fps (reduced buffer pressure)
3. ✅ Wait for 10 frames before starting MediaRecorder
4. ✅ Switch to FRONT camera as default
5. ✅ Added file size validation (min 10KB)
6. ✅ Better error logging with emojis
7. ✅ Minimal notification priority (less UI interference)

All changes preserve existing functionality while improving reliability and debugging.
