# Google Drive Token Sharing - Parent to Child

This feature allows parents to connect their Google Drive account once, and the child device automatically uses the same account to upload video recordings.

## How It Works

### Flow Overview:
1. **Parent connects Google Drive** on the parent device (from Child Device screen)
2. **Token is saved to Supabase** in the `devices` table for that specific child device
3. **Child device fetches token** from Supabase on app startup
4. **Videos upload automatically** to parent's Google Drive without requiring child to login

## Setup Instructions

### Step 1: Run SQL Migration
Execute this SQL in your Supabase SQL Editor to add the required columns:

```sql
-- Add Google Drive token columns to devices table
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS google_drive_email TEXT,
ADD COLUMN IF NOT EXISTS google_drive_token TEXT,
ADD COLUMN IF NOT EXISTS google_drive_token_updated_at TIMESTAMP WITH TIME ZONE;
```

Or run the full migration file: `add_google_drive_token_column.sql`

### Step 2: Rebuild the App
After the code changes, rebuild the app on both parent and child devices:
```bash
flutter clean
flutter pub get
flutter build apk
```

## Files Modified/Created

### New Files:
- `lib/services/google_drive_token_service.dart` - Service for saving/fetching tokens via Supabase
- `add_google_drive_token_column.sql` - SQL migration for database

### Modified Files:
1. **MainActivity.kt**
   - Updated `REQUEST_GOOGLE_SIGN_IN` handler to pass both email AND token to Flutter
   - Added `initGoogleDriveWithToken` method to initialize Drive with a provided token

2. **childs_device_widget.dart**
   - Updated `onGoogleDriveConnected` callback to receive Map with email and token
   - Saves token to Supabase when parent connects Google Drive

3. **main.dart**
   - Updated `_ensureGoogleDriveConnected()` to first check Supabase for parent's token
   - Falls back to login prompt only if no parent token exists

## Token Refresh Considerations

OAuth access tokens expire after ~1 hour. To handle this:

1. **On Parent Device**: When parent re-connects Google Drive, the new token is saved
2. **On Child Device**: If upload fails with 401, the system:
   - Re-fetches the token from Supabase (in case parent refreshed it)
   - Retries the upload with the new token

## Security Notes

- Tokens are stored in Supabase with Row Level Security (RLS)
- Only devices linked to the parent's profile can access the token
- Tokens should be rotated periodically by having parent reconnect

## Testing

1. On parent device:
   - Go to Child Device > Screen Recording tab
   - Tap "Connect Google Drive"
   - Sign in with parent's Google account
   - Should see "Google Drive connected... Child device can now upload recordings"

2. On child device:
   - Restart the app
   - Check logcat: `☁️ Found parent's Google Drive token for email: xxx@gmail.com`
   - Trigger a recording from parent
   - Video should upload to parent's Google Drive

## Troubleshooting

### Child device not using parent's token
Check logcat for:
```
☁️ Fetching Google Drive token for device: <device-id>
⚠️ No Google Drive token found for device
```
This means parent hasn't connected Google Drive yet, or token wasn't saved.

### Upload still failing
Check if token has expired:
```
❌ Upload failed with status: 401
```
Have parent reconnect Google Drive to refresh the token.

### Database columns missing
Run the SQL migration again and verify columns exist:
```sql
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'devices' AND column_name LIKE 'google_drive%';
```
