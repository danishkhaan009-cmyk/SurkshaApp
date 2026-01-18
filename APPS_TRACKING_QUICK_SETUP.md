# Quick Setup Guide - Installed Apps Tracking

## Step 1: Database Setup (5 minutes)

1. **Open Supabase SQL Editor**
   - Go to your Supabase dashboard: https://supabase.com/dashboard
   - Select your project
   - Click "SQL Editor" in the left sidebar

2. **Run the SQL Script**
   - Open the file: `create_installed_apps_table.sql`
   - Copy all the contents
   - Paste into SQL Editor
   - Click "Run" or press `Ctrl+Enter`
   - Wait for success message

3. **Verify Table Creation**
   - Click "Table Editor" in left sidebar
   - You should see `installed_apps` table
   - Click on it to verify columns exist

## Step 2: Test on Chrome (Already Running)

Your app is already running on Chrome. Now let's test the feature:

### Test as Child Device

1. **If not logged in:**
   - Go to Login Screen
   - Enter child account credentials
   - Click "Login"

2. **Complete Child Device Setup:**
   - Select "Child Mode"
   - Complete Setup 1 (enter child name and age)
   - Complete Setup 2 (note pairing code)
   - Complete Setup 3 (scan QR)
   - Complete Setup 4 (grant permissions)
   - Complete Setup 5 (enter PIN and grant permissions)

3. **Watch Console Logs:**
   ```
   🔄 Starting app sync for device: [device-id]
   ✅ Successfully synced X apps to database
   🔄 Starting periodic app sync for device: [device-id]
   ```

### Test as Parent Device

1. **Open in a different browser or incognito:**
   - Open http://localhost:XXXX (your app URL)
   - Login with parent account
   - Go to Parent Dashboard

2. **View Child's Apps:**
   - Click on the child device
   - Navigate to "Apps" tab
   - You should see all apps from the child device

3. **Test Real-Time Updates:**
   - Keep parent dashboard open
   - Go to child device console
   - Type: `DeviceDataSyncService.syncInstalledApps('device-id')`
   - Watch parent dashboard update automatically

## Step 3: Verify Everything Works

### Check Child Device
```
✅ Apps sync on setup completion
✅ Periodic sync runs every 5 minutes
✅ Console shows: "⏰ Periodic app sync triggered"
```

### Check Parent Device
```
✅ Apps load immediately when opening Apps tab
✅ Real-time updates work (no refresh needed)
✅ Search functionality filters apps
```

## Quick Commands for Testing

### In Browser Console (Child Device):
```javascript
// Force immediate sync
DeviceDataSyncService.syncInstalledApps('your-device-id')

// Check if periodic sync is active
DeviceDataSyncService.isPeriodicSyncActive()

// Stop periodic sync
DeviceDataSyncService.stopPeriodicSync()

// Start periodic sync
DeviceDataSyncService.startPeriodicSync('your-device-id')
```

### Check Database Directly:
1. Go to Supabase → Table Editor → installed_apps
2. You should see rows with:
   - device_id
   - app_name
   - package_name
   - version_name
   - synced_at timestamp

## Common Issues & Solutions

### Issue: Apps not showing in database
**Solution:**
- Check console for errors during sync
- Verify device_id is correct
- Make sure RLS policies were created (run SQL again)

### Issue: Parent can't see apps
**Solution:**
- Verify device_id matches between child and parent
- Check Supabase RLS policies allow SELECT
- Open browser console and look for errors

### Issue: Real-time not working
**Solution:**
- Check Supabase real-time is enabled in project settings
- Verify WebSocket connection in browser Network tab
- Try refreshing the page

### Issue: Periodic sync not running
**Solution:**
- Check console for: "🔄 Starting periodic app sync"
- Verify child mode is active
- Restart app and check again

## What to Expect

### First Time Setup (Child):
1. Setup takes 2-3 minutes
2. Apps sync immediately (5-10 seconds)
3. Periodic sync starts
4. Console shows sync activity every 5 minutes

### First Time Setup (Parent):
1. Open child device page
2. Click Apps tab
3. Apps load in 1-2 seconds
4. Real-time subscription activates
5. Any changes appear automatically

## Next Steps

After testing:
1. ✅ Verify apps appear in parent dashboard
2. ✅ Test with multiple child devices
3. ✅ Test install/uninstall on child device
4. ✅ Verify real-time updates work
5. ✅ Check periodic sync every 5 minutes

## Documentation

For detailed technical documentation, see:
- [INSTALLED_APPS_TRACKING_IMPLEMENTATION.md](INSTALLED_APPS_TRACKING_IMPLEMENTATION.md)

## Support

If you encounter issues:
1. Check browser console for errors
2. Check Supabase logs
3. Verify SQL script ran successfully
4. Review the implementation guide
