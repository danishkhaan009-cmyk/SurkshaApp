# Testing Camera Recording - Black Screen Fix

## Quick Test Steps

### Setup (Both Devices)
1. **Parent Device:** Open app, log in as parent
2. **Child Device:** Open app, set up as child device
3. **Child Device:** Grant camera and microphone permissions
4. **Child Device:** Connect Google Drive account

### Test Recording

#### On Parent Device:
1. Navigate to child's device page
2. Go to "Camera Recording" tab
3. Click **"Start Recording"** button (green)
4. Button should turn RED and say **"Stop Recording"**

#### On Child Device:
1. **IMPORTANT:** Keep screen ON and UNLOCKED
2. **IMPORTANT:** Keep app in foreground (don't minimize)
3. Hold phone normally with **FRONT CAMERA visible** (not blocked)
4. Wait 30 seconds for recording to complete
5. Video will auto-upload to Google Drive

#### On Parent Device:
1. After 30-40 seconds, click "Stop Recording" button (or wait for auto-complete)
2. Pull down to refresh the recordings list
3. Click on the new recording to view video
4. **Check:** Video should show child's face (from front camera)

## Expected Behavior

### ✅ Success Signs:
- Video shows child's face clearly
- File size is >10KB (usually 500-1000KB)
- Video uploads to Google Drive successfully
- Recording appears in parent's list

### ❌ Failure Signs (Black Screen):
- Video is completely black
- File size is very small (<10KB)
- File is automatically rejected (check logs)

## Why Videos Might Still Be Black

### 1. **Camera Blocked**
- Child's hand covering camera
- Phone face down on table
- Phone in pocket
- Case blocking camera lens

**Fix:** Hold phone normally with front camera visible

### 2. **Dark Environment**
- Recording in complete darkness
- No lights in room
- Camera can't capture anything

**Fix:** Turn on lights or record in daylight

### 3. **Wrong Timing**
- Screen locked when recording starts
- App minimized during recording
- Device goes to sleep mid-recording

**Fix:** Keep child device unlocked and app open

### 4. **Permission Issues**
- Camera permission denied
- System blocking camera access
- Another app using camera

**Fix:** Grant all permissions, close other camera apps

## Debugging with Logs

### On Child Device:
```bash
adb logcat | grep CameraRecordService
```

### Look for these messages:

✅ **Good signs:**
```
📷 Using FRONT camera (ID: 1) - will show child's face
✅ Camera opened
✅ Capture session configured
🎥 Camera recording started after 10 frames
✅ Video file validated: 756KB
📤 Uploading to Google Drive...
✅ Recording uploaded successfully
```

❌ **Problem signs:**
```
❌ Camera permission not granted
❌ Recording file too small (8KB) - likely black screen
   This usually means: camera was covered, no light, or permission denied
📱 App not in foreground - postponing recording request
🔒 Device is locked - postponing recording request
```

## Camera Selection

### Current Setting: FRONT CAMERA (default)
**Pros:**
- Shows child's face
- Less likely to be blocked
- Better for monitoring who the child is

**Cons:**
- Lower quality than back camera
- Child can see they're being recorded

### To Switch to BACK CAMERA:
Edit `CameraRecordService.kt`, line ~666:
```kotlin
// Change order to prefer BACK camera
if (facing == CameraCharacteristics.LENS_FACING_BACK) {
    return cameraId
}
```

## Recording Quality

### Current Settings:
- **Camera:** Front (selfie camera)
- **Resolution:** 640x480 pixels (VGA)
- **Frame Rate:** 15 fps
- **Duration:** 30 seconds
- **File Size:** ~500-1000 KB

### Adjusting Quality:
Edit `CameraRecordService.kt`, line ~713:
```kotlin
setVideoSize(640, 480)              // Change to 1280, 720 for HD
setVideoFrameRate(15)               // Change to 30 for smoother video
setVideoEncodingBitRate(200000)     // Increase for better quality
```

**Note:** Higher quality = larger files = longer upload time

## Common Issues

### Issue 1: "Recording starts but video is black"
**Diagnosis:** Camera was blocked or no light
**Solution:**
- Hold phone upright with front camera visible
- Turn on room lights
- Don't cover camera with hand

### Issue 2: "Recording request sent but nothing happens"
**Diagnosis:** Child device not ready
**Solution:**
- Unlock child device
- Open the app (must be in foreground)
- Wait for child to actively use device

### Issue 3: "Video very short or cut off"
**Diagnosis:** Device went to sleep or app minimized
**Solution:**
- Keep child device screen on
- Adjust screen timeout to longer duration
- Keep app active during recording

### Issue 4: "Button stuck on 'Stop Recording'"
**Diagnosis:** Recording state not reset
**Solution:**
- Tap "Stop Recording" button
- Pull down to refresh
- Restart app if needed

## File Size Guide

### Expected file sizes (30 seconds):
- **Good video (visible content):** 500-1000 KB
- **Black screen (camera blocked):** <50 KB
- **Completely empty:** <10 KB (auto-rejected)

### If file is small:
- ❌ <10 KB → Rejected automatically
- ⚠️ 10-50 KB → Likely mostly black
- ⚠️ 50-200 KB → Very dark or low activity
- ✅ 200+ KB → Should have visible content

## Next Steps After Testing

### If videos are still black:
1. Check camera permissions on child device
2. Verify child device screen is on and unlocked
3. Hold phone normally (not face down)
4. Turn on lights in room
5. Check logs for specific error messages

### If videos work but quality is poor:
1. Increase video bitrate (see "Adjusting Quality" above)
2. Switch to 720p resolution
3. Increase frame rate to 30fps
4. Consider switching to back camera for better quality

### If uploads are slow:
1. Current settings already optimized for small size
2. Ensure child device has good internet connection
3. Check Google Drive storage is not full
4. Consider reducing video length from 30s to 15s

## Support

For detailed technical information, see:
- `CAMERA_RECORDING_BLACK_SCREEN_FIX.md`
- `CameraRecordService.kt` (main recording logic)

For logs and debugging:
```bash
# Full logs
adb logcat

# Filter for camera service
adb logcat | grep CameraRecordService

# Filter for Google Drive uploads
adb logcat | grep GoogleDriveUploader
```
