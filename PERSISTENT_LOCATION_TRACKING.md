# Persistent Background Location Tracking Implementation

This document describes the implementation of persistent background location tracking that continues running even when:
1. **App is killed/removed from task manager**
2. **Device is switched off or restarted**

## Overview

The implementation uses a native Android **Foreground Service** with the following key components:

### Files Modified/Created

1. **`LocationService.kt`** (New) - Native Android foreground service for persistent location tracking
2. **`BootReceiver.kt`** (Updated) - Handles device boot events to restart location service
3. **`AndroidManifest.xml`** (Updated) - Added required permissions and service declarations
4. **`MainActivity.kt`** (Updated) - Added method channel handlers for Flutter communication
5. **`build.gradle`** (Updated) - Added Google Play Services Location dependency
6. **`location_tracking_service.dart`** (Updated) - Added native service integration

## How It Works

### 1. Foreground Service (LocationService.kt)

The `LocationService` is an Android Foreground Service that:
- Runs independently of the Flutter app lifecycle
- Shows a persistent notification (required by Android for foreground services)
- Uses `FusedLocationProviderClient` for efficient location updates
- Holds a `WakeLock` to prevent the device from sleeping
- Automatically restarts if killed (`START_STICKY`)
- Saves locations directly to Supabase using HTTP requests

### 2. Boot Receiver (BootReceiver.kt)

The `BootReceiver` listens for:
- `ACTION_BOOT_COMPLETED` - Normal device boot
- `ACTION_LOCKED_BOOT_COMPLETED` - Direct boot (Android 7+)
- `QUICKBOOT_POWERON` - Quick boot on some devices (HTC, etc.)

When triggered, it checks if location tracking was active before shutdown and restarts the service.

### 3. Permissions Added

```xml
<!-- Background location (Android 10+) -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Boot completed for auto-restart -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- Foreground service permissions -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<!-- Wake lock for keeping service running -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Alarm for service restart -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />

<!-- Battery optimization exemption -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

## Usage in Flutter

### Starting Location Tracking

```dart
final locationService = LocationTrackingService();

// Start persistent tracking
await locationService.startTracking(deviceId);

// The service will now:
// - Run in the background even if app is killed
// - Auto-restart after device reboot
// - Save locations to Supabase automatically
```

### Stopping Location Tracking

```dart
await locationService.stopTracking();
```

### Checking Service Status

```dart
// Sync status check
bool isTracking = locationService.isTracking;

// Async status check with more details
Map<String, dynamic> stats = await locationService.getTrackingStatsAsync();
print('Native service running: ${stats['isNativeServiceRunning']}');
print('Battery optimization disabled: ${stats['batteryOptimizationDisabled']}');
```

### Requesting Battery Optimization Exemption

For best results, request battery optimization exemption:

```dart
await locationService.requestBatteryOptimizationExemption();
```

### Checking Battery Optimization Status

```dart
bool isExempt = await locationService.isBatteryOptimizationDisabled();
```

## Configuration

### Location Update Settings (in LocationService.kt)

- **Update Interval**: 10 minutes (`LOCATION_INTERVAL_MS = 10 * 60 * 1000L`)
- **Fastest Interval**: 5 minutes (`FASTEST_INTERVAL_MS = 5 * 60 * 1000L`)
- **Minimum Distance**: 100 meters (`MIN_DISTANCE_CHANGE = 100.0`)
- **Minimum Save Interval**: 60 seconds (`MIN_SAVE_INTERVAL_MS = 60_000L`)

### Notification Customization

The notification can be customized in `LocationService.kt`:

```kotlin
return NotificationCompat.Builder(this, CHANNEL_ID)
    .setContentTitle("Location Tracking Active")
    .setContentText("SurakshaApp is tracking your location")
    .setSmallIcon(android.R.drawable.ic_menu_mylocation)
    // ... other settings
    .build()
```

## Important Notes

### Battery Optimization

Some Android devices (especially Chinese OEMs like Xiaomi, Huawei, Oppo, Vivo) have aggressive battery optimization that may still kill the service. Users should:

1. **Disable battery optimization** for the app
2. **Lock the app** in recent tasks (on supported devices)
3. **Enable "Auto-start"** permission (on Xiaomi, Oppo, etc.)

### Android 10+ Background Location

On Android 10 and above, background location requires separate permission. The app will prompt users to grant "Allow all the time" location access.

### Data Usage

The service makes HTTP requests to save locations. Ensure users understand this may consume mobile data when not on WiFi.

## Troubleshooting

### Service not restarting after device reboot

1. Check if `RECEIVE_BOOT_COMPLETED` permission is granted
2. Verify the app is not being killed by aggressive battery optimization
3. Check logcat for `BootReceiver` logs

### Service stopping unexpectedly

1. Request battery optimization exemption
2. Lock the app in recent tasks
3. Enable auto-start permission on Chinese OEM devices

### Location not updating

1. Check if location services are enabled
2. Verify location permissions are granted
3. Check if battery saver mode is active (may throttle location updates)

## Testing

1. Start location tracking
2. Kill the app from task manager
3. Check Supabase database - locations should continue appearing
4. Restart the device
5. After boot, locations should resume automatically
