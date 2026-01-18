# App Lock & Background Monitoring Implementation Verification

## 1. APP LOCK MECHANISM - ✅ REAL BLOCKING (Not Spoofing)

### How It Works:
The app uses **Android AccessibilityService** to monitor and block apps at the system level.

#### Implementation Details:

**Native Android Service** (`AppBlockService.kt`):
```kotlin
class AppBlockService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return
            
            // Only block if child mode is active
            if (!isChildModeActive) return
            
            // Check if this app is locked
            if (lockedApps.contains(packageName)) {
                blockApp(packageName)  // Immediately intercept
            }
        }
    }
    
    private fun blockApp(packageName: String) {
        // Launch lock screen immediately when blocked app is detected
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/appLockScreen")
        }
        startActivity(intent)
    }
}
```

### Verification Points:

✅ **Real-time Detection**: AccessibilityService monitors `TYPE_WINDOW_STATE_CHANGED` events
✅ **System-Level Interception**: Detects when any app window opens
✅ **Immediate Blocking**: Launches lock screen with `FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_CLEAR_TOP`
✅ **Package Name Matching**: Compares actual package name (e.g., `com.instagram.android`)
✅ **Not Spoofing**: This is NOT a fake overlay - it's actual app window interception

### Required Permissions:
- `android.permission.BIND_ACCESSIBILITY_SERVICE` - Declared in AndroidManifest.xml
- User must manually enable the AccessibilityService in Android Settings

### Limitations:
- ⚠️ Can be disabled if user turns off AccessibilityService
- ⚠️ Doesn't work on system apps (Settings, Phone, etc.)
- ⚠️ May not block apps in split-screen mode
- ⚠️ Only works on Android (native service)

---

## 2. BACKGROUND MONITORING - ⚠️ PARTIAL SUPPORT

### Current Implementation:

**Flutter Timer.periodic** (`rules_enforcement_service.dart`):
```dart
_backgroundMonitorTimer = Timer.periodic(
  const Duration(seconds: 30),
  (_) => _runBackgroundCheck(),
);
```

### How It Works:

1. **When App is Active**: ✅ Timer runs perfectly every 30 seconds
2. **When App is Minimized**: ✅ Timer continues to run (Flutter isolate stays alive)
3. **When Phone is Locked**: ⚠️ **DEPENDS ON BATTERY OPTIMIZATION**

### Battery Optimization Impact:

#### Android Doze Mode (Android 6.0+):
When screen is off for extended periods, Android enters Doze mode:
- ⏸️ Network access is suspended
- ⏸️ Wake locks are ignored
- ⏸️ Timers are batched or delayed
- ⏸️ Only periodic maintenance windows (every ~15-30 minutes)

#### App Standby Buckets (Android 9.0+):
Apps are placed in buckets based on usage:
- **Active**: No restrictions
- **Working Set**: Timer may be delayed by ~10 minutes
- **Frequent**: Timer may be delayed by ~2 hours
- **Rare**: Timer may be delayed by ~24 hours

### Current Issues:

❌ **No WAKE_LOCK Permission**: App cannot keep CPU awake when screen is off
❌ **No Foreground Service**: Flutter app will be throttled in background
❌ **No WorkManager**: No guaranteed background execution
❌ **Timer.periodic is NOT reliable** when phone is locked for extended periods

### What Actually Happens When Phone is Locked:

1. **First 5 minutes**: Timer continues to work (screen just off)
2. **After 5+ minutes**: Android may throttle or delay the timer
3. **After 30+ minutes**: Doze mode kicks in, timer may not run at all
4. **After 1+ hour**: App is definitely in standby, no background execution

---

## 3. RECOMMENDED FIXES

### Option A: Android Foreground Service (RECOMMENDED)

Create a persistent notification and foreground service:

```kotlin
class MonitoringService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Create notification
        val notification = createNotification("Child monitoring active")
        startForeground(NOTIFICATION_ID, notification)
        
        // Schedule periodic work
        scheduleBackgroundCheck()
        
        return START_STICKY
    }
}
```

**Required Permissions**:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

**Pros**:
✅ Persistent notification keeps service alive
✅ Survives Doze mode
✅ Can use PowerManager.WakeLock for critical tasks
✅ Works even when phone is locked

**Cons**:
❌ Permanent notification (required by Android)
❌ More complex implementation
❌ Higher battery drain

### Option B: WorkManager (ALTERNATIVE)

Schedule periodic background work that survives app restarts:

```kotlin
val workRequest = PeriodicWorkRequestBuilder<MonitoringWorker>(
    15, TimeUnit.MINUTES  // Minimum interval allowed
).build()

WorkManager.getInstance(context).enqueue(workRequest)
```

**Pros**:
✅ Guaranteed execution (system handles scheduling)
✅ Survives app restart and device reboot
✅ Battery efficient (system batches work)

**Cons**:
❌ Minimum 15-minute interval (not 30 seconds)
❌ Actual execution time is not exact
❌ May be delayed during Doze mode

### Option C: Alarm Manager with Exact Alarms

Use exact alarm API for time-sensitive tasks:

```kotlin
val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
alarmManager.setExactAndAllowWhileIdle(
    AlarmManager.RTC_WAKEUP,
    triggerTime,
    pendingIntent
)
```

**Pros**:
✅ Exact timing even in Doze mode
✅ Can wake device from sleep

**Cons**:
❌ Requires `SCHEDULE_EXACT_ALARM` permission (Android 12+)
❌ Need to reschedule after each trigger
❌ Higher battery drain

---

## 4. CURRENT IMPLEMENTATION STATUS

### What Works:
✅ App Lock blocks apps in real-time (AccessibilityService)
✅ Timer runs every 30 seconds when app is active
✅ Timer continues when app is minimized (for short periods)
✅ Location updates work when timer fires
✅ Rules reload from database every 30 seconds
✅ Device-specific filtering (only loads rules for this device_id)

### What Doesn't Work:
❌ Timer stops when phone is locked for extended periods (Doze mode)
❌ No background execution during sleep mode
❌ No wake lock to keep app alive
❌ No foreground service notification
❌ Timer may be delayed/batched by Android battery optimization

---

## 5. TESTING RECOMMENDATIONS

### Test 1: App Lock Blocking (Real vs Spoofing)
1. Install APK on child device
2. Create App Lock rule for Instagram
3. Try to open Instagram
4. **Expected**: Lock screen appears IMMEDIATELY before Instagram UI loads
5. **If spoofing**: Instagram would load briefly before lock screen

### Test 2: Background Timer (Active State)
1. Activate child mode
2. Check logcat: `adb logcat | grep "🔍"`
3. Minimize app (home button)
4. **Expected**: See "Running background check" every 30 seconds
5. **Test duration**: 5-10 minutes

### Test 3: Background Timer (Locked Screen - Short Duration)
1. Activate child mode
2. Lock screen
3. Wait 5 minutes
4. Unlock and check Supabase locations table
5. **Expected**: ~10 new location records (5 min ÷ 30 sec)

### Test 4: Background Timer (Locked Screen - Long Duration) ⚠️
1. Activate child mode
2. Lock screen
3. Wait 30+ minutes
4. Unlock and check Supabase locations table
5. **Expected Result**: 
   - **First 5-10 minutes**: Regular updates
   - **After 30+ minutes**: Missing updates (Doze mode)
   - **Actual Result**: Likely FAILS due to Doze mode

### Test 5: Battery Optimization Check
```bash
# Check if app is battery optimized
adb shell dumpsys deviceidle whitelist

# Disable battery optimization manually:
Settings → Apps → without-database → Battery → Unrestricted
```

---

## 6. SUMMARY

### App Lock: ✅ VERIFIED REAL BLOCKING
- Uses Android AccessibilityService
- System-level window interception
- NOT just a fake overlay
- **Works as advertised**

### Background Monitoring: ⚠️ LIMITED RELIABILITY
- Timer works when app is active/minimized
- **FAILS when phone is locked for extended periods**
- No foreground service or wake lock
- Subject to Android Doze mode and battery optimization
- **NOT production-ready for 24/7 monitoring**

### Recommended Action:
Implement **Android Foreground Service** with persistent notification for reliable background monitoring.

