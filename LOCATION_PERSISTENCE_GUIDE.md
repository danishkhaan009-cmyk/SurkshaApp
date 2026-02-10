# Location Tracking Persistence After App Kill

## Problem
Location tracking stopped when the app was killed from the task manager.

## Solutions Implemented

### 1. **WorkManager Integration**
- WorkManager persists across app kills and device reboots
- Scheduled to run every 15 minutes (Android's minimum)
- Configured with `ExistingPeriodicWorkPolicy.UPDATE` to always use latest config
- No battery optimization constraints to ensure it runs

### 2. **Service Auto-Restart Mechanisms**

#### a) START_STICKY Flag
- LocationService returns `START_STICKY` from `onStartCommand()`
- Android will automatically restart the service after it's killed

#### b) onTaskRemoved() Handler
- Detects when app is removed from task manager
- Immediately attempts to restart the service
- Schedules backup restarts using AlarmManager (1s and 5s delays)
- Sends broadcast to RestartReceiver

#### c) AlarmManager Scheduled Restarts
- Uses `setExactAndAllowWhileIdle()` for guaranteed execution
- Dual restart attempts (1 second and 5 seconds)
- Works even in Doze mode

#### d) BroadcastReceivers
- **BootReceiver**: Restarts service after device reboot
- **RestartReceiver**: Handles manual restart requests and package updates

### 3. **MainApplication Initialization**
- Checks if tracking was active on app start
- Restarts LocationService if needed
- Re-schedules WorkManager if tracking was active
- Implements WorkManager.Configuration.Provider for custom config

### 4. **SharedPreferences Persistence**
- All tracking state stored in SharedPreferences:
  - `is_tracking`: Whether tracking is enabled
  - `device_id`: Device identifier
  - `supabase_url`: Supabase endpoint
  - `supabase_key`: Supabase API key
- Survives app kills and reboots

### 5. **Foreground Service Configuration**
- Declared with `android:stopWithTask="false"` in AndroidManifest.xml
- Uses persistent notification
- Holds wake lock to prevent CPU sleep
- Runs as location foreground service type

## How It Works

### Normal Operation
1. User starts location tracking
2. LocationService starts as foreground service
3. WorkManager schedules periodic updates
4. Both services update location in parallel

### When App Is Killed
1. `onTaskRemoved()` is called
2. Service immediately attempts self-restart
3. AlarmManager schedules backup restarts
4. RestartReceiver receives broadcast
5. WorkManager continues running independently

### When App Is Restarted
1. MainApplication.onCreate() checks SharedPreferences
2. If `is_tracking = true`, restarts LocationService
3. Re-schedules WorkManager if needed
4. Normal operation resumes

### After Device Reboot
1. BootReceiver receives BOOT_COMPLETED
2. Checks SharedPreferences for tracking state
3. Restarts LocationService if was active
4. WorkManager automatically resumes scheduled work

## Testing

### Test App Kill Survival:
1. Start location tracking in the app
2. Go to Recent Apps and swipe away the app
3. Check logcat: `adb logcat | grep -E "LocationService|LocationWorker"`
4. Verify service restarts within 1-5 seconds
5. Verify WorkManager continues every 15 minutes
6. Check parent app - locations should still be updating

### Test Device Reboot:
1. Start location tracking
2. Reboot device
3. Check if service restarts automatically
4. Verify locations are being saved

## Permissions Required

Make sure these are granted:
- Location permissions (Fine + Background)
- Battery optimization exemption
- Notification permission
- Boot completed permission (already in manifest)

## Battery Optimization

Call `requestBatteryOptimizationExemption()` from Flutter:
```dart
await locationTrackingService.requestBatteryOptimizationExemption();
```

This opens system settings where user can disable battery optimization for the app.

## Monitoring

### Check WorkManager Status:
```bash
adb shell dumpsys jobscheduler | grep LocationWorker
```

### Check Service Status:
```bash
adb logcat | grep LocationService
```

### View Scheduled Work:
```bash
adb shell dumpsys activity service WorkManagerService
```

## Important Notes

1. **Android 12+ Restrictions**: On Android 12+, foreground service restrictions are stricter. Make sure the app has been granted battery optimization exemption.

2. **Manufacturer Restrictions**: Some manufacturers (Xiaomi, Huawei, Oppo) have aggressive battery optimization. Users may need to manually whitelist the app.

3. **WorkManager Delays**: WorkManager runs every 15 minutes minimum, which may not be frequent enough for real-time tracking. The foreground service provides continuous updates.

4. **Network Requirement**: WorkManager requires network connectivity to save locations. If offline, it will retry later.

## Troubleshooting

### Service Not Restarting:
- Check if battery optimization is disabled
- Verify `is_tracking` is `true` in SharedPreferences
- Check logcat for error messages
- Ensure all permissions are granted

### WorkManager Not Running:
- Check if it's scheduled: use MainActivity method `isLocationWorkerScheduled`
- Verify network connectivity
- Check device isn't in aggressive battery saving mode

### Locations Not Saving:
- Verify Supabase URL and key are correct in SharedPreferences
- Check network connectivity
- Review logcat for HTTP errors
- Verify RLS policies in Supabase allow inserts
