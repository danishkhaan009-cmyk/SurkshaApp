# Installed Apps Tracking Implementation

## Overview
This document describes the implementation of real-time app tracking for child devices, allowing parents to view installed applications on their children's devices.

## Features Implemented

### 1. Database Table
Created `installed_apps` table in Supabase with:
- `device_id` - Links to the child device
- `app_name` - Name of the application
- `package_name` - Android package identifier
- `version_name` - App version string
- `version_code` - Numeric version code
- `synced_at` - Last sync timestamp
- Unique constraint on `(device_id, package_name)`
- RLS policies for public access

**SQL File:** [create_installed_apps_table.sql](create_installed_apps_table.sql)

### 2. Enhanced Device Data Sync Service
**File:** `lib/services/device_data_sync_service.dart`

Features:
- `syncInstalledApps()` - One-time sync of installed apps
- `startPeriodicSync()` - Starts background sync every 5 minutes
- `stopPeriodicSync()` - Stops periodic sync
- `fetchInstalledApps()` - Fetch apps from database
- `watchInstalledApps()` - Real-time stream of app changes

### 3. Child Device Integration

#### Child Device Setup (Setup 5)
**File:** `lib/pages/child_device_setup5/child_device_setup5_widget.dart`

When child device is set up:
1. Initial app sync runs immediately
2. Periodic sync starts (every 5 minutes)
3. Apps are uploaded to Supabase

#### Self Mode
**File:** `lib/pages/self_mode/self_mode_widget.dart`

When child enters self mode:
1. Periodic sync resumes automatically
2. Apps stay synchronized while in self mode

### 4. Parent Dashboard Integration
**File:** `lib/pages/childs_device/childs_device_widget.dart`

Features:
- Real-time subscription to app changes via Supabase streams
- Automatic updates when child installs/uninstalls apps
- Search functionality for filtering apps
- Shows app name, package name, and version

## How It Works

### Child Device Flow
```
1. Child logs in
2. Device setup completes
3. Apps are scanned using device_apps package
4. Apps uploaded to Supabase (initial sync)
5. Periodic sync starts (every 5 minutes)
6. Any new/removed apps are synced automatically
```

### Parent Device Flow
```
1. Parent opens child's device page
2. Subscribes to real-time updates from Supabase
3. Apps displayed immediately from database
4. Updates appear automatically when child installs/uninstalls apps
```

### Real-Time Sync
- Uses Supabase real-time subscriptions
- Parent sees updates within seconds
- No polling or manual refresh needed

## Usage

### For Parents
1. Log in to parent account
2. Navigate to Parent Dashboard
3. Select a child device
4. Click "Apps" tab
5. View all installed applications in real-time

### For Children
- Apps are automatically tracked
- No manual action required
- Tracking continues in background

## Database Setup

Run this SQL in your Supabase SQL Editor:

```sql
-- See create_installed_apps_table.sql for full script
```

## Testing

### Test Child Device Sync
1. Set up child device (Child Device Setup 1-5)
2. Check console for: `✅ Successfully synced X apps to database`
3. Wait 5 minutes and check for: `⏰ Periodic app sync triggered`

### Test Parent View
1. Open parent dashboard
2. Select child device → Apps tab
3. Should see all apps immediately
4. Install/uninstall app on child device
5. Parent view updates within 5 seconds

### Test Real-Time Updates
1. Open parent dashboard on one device
2. Open child device on another
3. Install a new app on child device
4. Watch parent dashboard update automatically

## Configuration

### Sync Interval
Default: 5 minutes

To change, modify `DeviceDataSyncService.startPeriodicSync()`:
```dart
_periodicSyncTimer = Timer.periodic(
  const Duration(minutes: 5), // Change this
  (timer) => syncInstalledApps(deviceId)
);
```

### App Filtering
Apps are filtered to show only:
- Apps with launch intents (user-facing apps)
- System apps are included (can be filtered out if needed)

## Benefits

✅ **Real-Time Updates** - Parent sees changes immediately
✅ **Cross-Device** - Works from different devices
✅ **Automatic** - No manual sync required
✅ **Efficient** - Uses Supabase streams, not polling
✅ **Reliable** - Periodic backup sync ensures consistency
✅ **Scalable** - Works with multiple children/devices

## Future Enhancements

- Add app icons to display
- Show install/update timestamps
- Filter by app categories
- Show app usage statistics
- Alert parent on specific app installations
- Block/allow apps remotely

## Troubleshooting

### Apps not showing for parent
1. Check if child device completed setup
2. Verify device ID is correct
3. Check Supabase RLS policies
4. Look for sync errors in child device console

### Apps not updating
1. Check if periodic sync is running
2. Verify network connection
3. Check Supabase project status
4. Review console for sync errors

### Real-time not working
1. Check Supabase real-time is enabled
2. Verify subscription is active
3. Check network/firewall settings
4. Review browser console for WebSocket errors
