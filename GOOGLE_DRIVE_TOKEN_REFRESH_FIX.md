# Google Drive Token Authentication Fix

## Problem
Video uploads to Google Drive were failing with **HTTP 401 error**:
```
❌ Upload failed (HTTP 401)
Error: "Request had invalid authentication credentials"
Status: "UNAUTHENTICATED"
🔑 Authentication error - token may be expired or invalid
```

## Root Cause
Google OAuth 2.0 access tokens expire after 1 hour. When the camera recording service tries to upload a video using an expired token, the upload fails with a 401 authentication error.

## Solution Implemented

### 1. **Automatic Token Refresh and Retry**
When upload fails with 401 error:
1. Clear the invalid/expired token
2. Attempt silent token refresh using Google Sign-In
3. Retry the upload with the new token

```kotlin
// Upload using multipart upload
var result = uploadFileMultipart(file, parentFolderId)

// If upload failed with auth error, try refreshing token and retry once
if (result == null && accessToken == null) {
    Log.d(TAG, "🔄 Upload failed with auth error, refreshing token and retrying...")
    if (refreshTokenSilently(context)) {
        Log.d(TAG, "✅ Token refreshed, retrying upload...")
        result = uploadFileMultipart(file, parentFolderId)
    }
}
```

### 2. **Improved Token Invalidation**
Before getting a new token, properly clear the old expired token:

```kotlin
// Invalidate old token first if we have one
if (!accessToken.isNullOrEmpty()) {
    try {
        GoogleAuthUtil.clearToken(context, accessToken)
        Log.d(TAG, "🗑️ Cleared old token")
    } catch (e: Exception) {
        Log.w(TAG, "Could not clear old token: ${e.message}")
    }
}
```

### 3. **Better Error Logging**
Enhanced error messages to distinguish between:
- Token expired (can auto-refresh)
- Token invalid (needs user re-consent)
- No token (needs user to connect Drive)

## How It Works Now

### Normal Upload Flow:
```
1. Recording completes (30 seconds)
2. Check if access token exists
   ├─ YES → Use existing token
   └─ NO → Try silent refresh
3. Upload to Google Drive
   ├─ SUCCESS (200) → ✅ Done
   └─ FAIL (401) → Go to token refresh
```

### Token Refresh Flow (on 401 error):
```
1. Upload fails with 401 error
2. Clear expired token from memory
3. Check for last signed-in Google account
   ├─ Found → Request new token from Google
   │          ├─ SUCCESS → Update token, retry upload
   │          └─ FAIL → User needs to reconnect
   └─ Not Found → User needs to sign in
```

## Testing

### Test Case 1: Fresh Token (within 1 hour)
**Expected:** Upload succeeds immediately
**Result:** ✅ Works

### Test Case 2: Expired Token (after 1 hour)
**Expected:** 
1. First upload fails with 401
2. Token automatically refreshes
3. Upload retries and succeeds

**Test Steps:**
1. Connect Google Drive
2. Wait 1+ hour (or manually expire token)
3. Start camera recording
4. Check logs for:
   ```
   ❌ Upload failed (HTTP 401)
   🔄 Upload failed with auth error, refreshing token and retrying...
   ✅ Token refreshed, retrying upload...
   ✅ Upload completed successfully!
   ```

### Test Case 3: No Google Sign-In
**Expected:** Upload fails, user needs to connect Drive
**Result:** Clear error message

## User Actions Required

### If Token Refresh Fails:
The user will see a message: **"Google Drive authentication expired"**

**Solution:** 
1. Open the app
2. Go to Settings/Profile
3. Tap "Connect Google Drive"
4. Sign in with Google account
5. Grant Drive permissions

This re-establishes the authentication and future uploads will work.

## Important Notes

### Token Lifetime:
- **Access Token:** Expires after 1 hour
- **Refresh Token:** Long-lived (doesn't expire unless revoked)
- **Silent Refresh:** Works automatically if user previously signed in

### When Silent Refresh Fails:
Silent token refresh can fail if:
1. User revoked app permissions in Google account settings
2. User signed out of Google account on device
3. App data was cleared
4. Google account requires re-authentication

**In these cases:** User must manually reconnect Google Drive in the app.

### Background Recording Consideration:
For background recording (when child device is not actively using the app):
- Service maintains the access token in memory
- If token expires during recording, auto-refresh attempts to get new token
- If auto-refresh fails, video is saved locally but not uploaded
- Next time app opens, it will retry failed uploads

## Logs to Monitor

### ✅ Success Logs:
```
📤 Starting upload: SurakshaVideo_20260205_170638.mp4 (756KB)
   Token available: ya29.a0ARrdaM3p...
✅ Upload completed successfully!
   📎 File ID: 1a2b3c4d5e6f
   📄 Name: SurakshaVideo_20260205_170638.mp4
   🔗 Link: https://drive.google.com/file/d/1a2b3c4d5e6f/view
```

### 🔄 Token Refresh Logs:
```
❌ Upload failed (HTTP 401)
🔑 Authentication error - token expired or invalid
🔄 Upload failed with auth error, refreshing token and retrying...
🔄 Found signed-in account: user@example.com
🗑️ Cleared old token
✅ Silently refreshed token: ya29.a0ARrdaM4q...
✅ Token refreshed, retrying upload...
📤 Starting upload: SurakshaVideo_20260205_170638.mp4 (756KB)
✅ Upload completed successfully!
```

### ❌ Error Logs (User Action Needed):
```
❌ Upload failed (HTTP 401)
🔄 Upload failed with auth error, refreshing token and retrying...
⚠️ User needs to re-consent for Drive access
   User must open app and reconnect Google Drive
❌ Token refresh failed - user needs to reconnect Google Drive
```

## Code Changes Summary

**File:** `GoogleDriveUploader.kt`

1. ✅ Added automatic retry on 401 error
2. ✅ Implemented token invalidation before refresh
3. ✅ Enhanced error logging and diagnostics
4. ✅ Better handling of UserRecoverableAuthException
5. ✅ Clear distinction between recoverable and non-recoverable auth errors

## Best Practices for Users

### To Avoid Token Issues:
1. **Keep Google account signed in** on the child device
2. **Don't revoke app permissions** in Google account settings
3. **Keep app data intact** (don't clear app storage)
4. **Ensure internet connection** when recording

### If Upload Fails:
1. Check device internet connection
2. Open app and verify Google Drive is connected
3. Check logs for specific error message
4. Reconnect Google Drive if token refresh failed

## Migration Notes

### For Existing Users:
- No action required
- Token refresh happens automatically
- If issues occur, simply reconnect Google Drive

### For New Users:
- Must connect Google Drive during setup
- First token is valid for 1 hour
- Subsequent tokens refresh automatically

## Security Considerations

### Token Storage:
- Access token stored in encrypted SharedPreferences
- Token expiry time tracked
- Expired tokens automatically cleared

### Token Refresh:
- Uses Google's official OAuth 2.0 flow
- Silent refresh doesn't require user interaction
- Falls back to user consent if needed

### Permissions:
- Only requests `drive.file` scope
- Can only access files created by the app
- Cannot read user's other Drive files

## Troubleshooting

### Problem: "Upload failed (HTTP 401)"
**Solution:** Auto-refresh should handle this. If it doesn't, reconnect Drive.

### Problem: "User needs to re-consent"
**Solution:** User must open app and tap "Connect Google Drive" again.

### Problem: Videos saved locally but not uploaded
**Solution:** 
1. Check internet connection
2. Verify Google Drive connection status
3. Manually trigger sync in app

### Problem: Frequent 401 errors
**Cause:** Google account signed out or permissions revoked
**Solution:** Ensure child device stays signed in to Google account

## Future Improvements

Potential enhancements:
1. Background upload retry queue for failed uploads
2. Proactive token refresh before expiry
3. Multiple retry attempts with exponential backoff
4. Local cache of multiple tokens for redundancy
5. Alternative upload methods (Dropbox, OneDrive)

## Related Files

- `GoogleDriveUploader.kt` - Main upload logic
- `CameraRecordService.kt` - Recording service that uses uploader
- `google_drive_token_service.dart` - Flutter service for Drive connection

## Support

If token refresh continues to fail:
1. Check Google account is active and signed in
2. Verify internet connectivity
3. Review app permissions in Google account settings
4. Try removing and re-adding Google account on device
5. Clear app cache (not data) and reconnect Drive
