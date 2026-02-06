# Device Reboot Behavior - Child Mode

## What Happens When Child Device Restarts

When a child device with active child mode is turned off and restarted, the following security mechanisms ensure monitoring continues:

### 1. **Data Persistence** ✅

**SharedPreferences survives reboot:**
- `is_child_mode_active` = true (persists)
- `child_device_id` = device UUID (persists)
- `child_exit_pin` = parent PIN (persists)

**Location:** Android local storage (`/data/data/com.mycompany.withoutdatabase/shared_prefs/`)

### 2. **Auto-Start on Boot** ✅

**BootReceiver triggers:**
```kotlin
// When device boots up:
BOOT_COMPLETED broadcast → BootReceiver.onReceive()
├─ Check SharedPreferences for child_mode_active
├─ If TRUE:
│  ├─ Launch MainActivity automatically
│  └─ Start MonitoringService (foreground service)
└─ If FALSE: Do nothing (parent device)
```

**Implementation Files:**
- `android/app/src/main/kotlin/.../BootReceiver.kt`
- `AndroidManifest.xml` - RECEIVE_BOOT_COMPLETED permission

**What Gets Started:**
1. Main app launches (minimized to background)
2. Foreground monitoring service starts
3. Persistent notification appears: "Child Monitoring Active"

### 3. **Rules Re-initialization** ✅

**main.dart initialization flow:**
```dart
App Starts
├─ initState()
├─ _initializeBackgroundServices()
│  ├─ Check isChildModeActive() [from SharedPreferences]
│  ├─ Get device_id [from SharedPreferences]
│  └─ If child mode detected:
│     ├─ RulesEnforcementService.initialize(context)
│     │  ├─ Load active rules from Supabase database
│     │  ├─ Update native App Lock service
│     │  └─ Start enforcement timer
│     └─ Start background monitoring (30-second checks)
```

### 4. **Background Monitoring Resumes** ✅

**Automatic resumption:**
- Foreground service keeps app alive
- Timer.periodic restarts (every 30 seconds)
- Background checks resume:
  - Location updates to database
  - Rules reload from database
  - Time limit enforcement
  - App Lock synchronization

### 5. **App Lock Re-enabled** ✅

**AccessibilityService restoration:**
- AccessibilityService settings persist across reboots
- Once app starts, locked apps list is updated
- App blocking resumes immediately
- No user action required

---

## Security Timeline After Reboot

```
00:00 - Child turns off device
00:10 - Device powers off completely
00:20 - Child presses power button
00:25 - Android boots up
00:30 - System fully loaded
00:31 - BOOT_COMPLETED broadcast sent
00:32 - ✅ BootReceiver receives broadcast
00:33 - ✅ Checks child_mode_active = true
00:34 - ✅ Auto-launches MainActivity
00:35 - ✅ Starts MonitoringService
00:36 - ✅ Foreground notification appears
00:37 - ✅ Loads rules from Supabase database
00:38 - ✅ Updates native App Lock service
00:39 - ✅ Background monitoring active
00:40 - ✅ First location update sent
01:10 - ✅ Second background check (30 sec later)
01:40 - ✅ Third background check
... continues every 30 seconds
```

**Total Downtime:** ~10 seconds (from boot to full monitoring)

---

## What the Child CANNOT Do

❌ **Cannot disable child mode by restarting**
- Child mode flag persists in SharedPreferences
- Auto-starts on every boot
- Only parent PIN can deactivate

❌ **Cannot escape App Lock after restart**
- Locked apps list reloads from database
- AccessibilityService re-enabled automatically
- Blocking resumes within seconds

❌ **Cannot stop background monitoring**
- Foreground service shows persistent notification
- Cannot be dismissed without root access
- Runs continuously even when app is "closed"

❌ **Cannot avoid location tracking**
- Location updates resume immediately
- Tracks every 30 seconds as configured
- Sends to Supabase database

---

## What the Child CAN Still Do (by design)

⚠️ **Can uninstall app IF:**
- Device Admin is not enabled
- Child has access to Settings app
- **Prevention:** Enable Device Admin during setup

⚠️ **Can disable Accessibility Service IF:**
- Child has access to Settings app
- **Prevention:** Lock Settings app with App Lock

⚠️ **Can disable Location Services IF:**
- Child has access to Settings app
- **Prevention:** Lock Settings app with App Lock

⚠️ **Can factory reset device**
- Wipes all data including child mode settings
- **No prevention possible** (Android security feature)
- Parent should enable Google Find My Device

---

## Recommended Security Hardening

### 1. Lock Critical Apps
```
Create App Lock rules for:
- Settings (prevents disabling services)
- Google Play Store (prevents uninstalling)
- Phone Settings
- Developer Options
```

### 2. Enable Device Admin
```
During child setup:
- Request Device Admin permission
- Prevents uninstallation without parent PIN
- Makes it harder to remove app
```

### 3. Disable Developer Options
```
Settings → About Phone → Tap Build Number 7 times (disable)
- Prevents ADB access
- Prevents USB debugging
- Prevents service tampering
```

### 4. Set Screen Lock
```
Require PIN/password for device unlock
- Child cannot boot to Settings without unlock
- Additional layer of security
```

---

## Testing Reboot Scenario

### Test 1: Normal Reboot
1. Install APK on child device
2. Complete child setup (activate child mode)
3. Create App Lock rule for WhatsApp
4. Restart device (power off → power on)
5. Wait 30 seconds after boot
6. Try to open WhatsApp
7. **Expected:** Lock screen appears immediately

### Test 2: Check Auto-Start
```bash
# Before reboot
adb shell pm list packages | grep SurakshaApp
com.getsurakshaapp

# Reboot device
adb reboot

# After boot (wait 30 seconds)
adb logcat | grep "BootReceiver"
# Expected: "Child mode is active - auto-starting app"

adb logcat | grep "Background monitoring"
# Expected: "Background monitoring resumed on app start"
```

### Test 3: Verify Persistent Monitoring
```bash
# Check if foreground service is running
adb shell dumpsys activity services | grep MonitoringService
# Expected: Service running with notification

# Check background checks
adb logcat | grep "🔍"
# Expected: "Running background check" every 30 seconds
```

### Test 4: Database Sync After Reboot
1. Before reboot: Note last location timestamp in Supabase
2. Restart device
3. Wait 2 minutes after boot
4. Check Supabase locations table
5. **Expected:** 3-4 new location records (2 min ÷ 30 sec)

---

## Edge Cases Handled

✅ **Multiple reboots:** App restarts every time
✅ **Battery dies and recharges:** Auto-starts on reboot
✅ **Force stop app:** Restarts on next reboot
✅ **Clear app data:** Would clear child mode (requires Settings access)
✅ **Airplane mode during boot:** App still starts, queues data when online
✅ **No internet on boot:** App starts, retries database connection

---

## Summary

### When Child Restarts Device:

**What Persists:**
- ✅ Child mode activation status
- ✅ Device ID and parent PIN
- ✅ AccessibilityService enabled state
- ✅ Foreground service configuration

**What Auto-Resumes:**
- ✅ App launches automatically (BootReceiver)
- ✅ Foreground monitoring service starts
- ✅ Rules reload from Supabase database
- ✅ App Lock re-enabled with latest rules
- ✅ Background monitoring (30-second checks)
- ✅ Location tracking

**Downtime:**
- ~10 seconds from boot to full monitoring
- No manual intervention required
- Completely transparent to child

**Child CANNOT Escape:**
- Restarting device does not disable monitoring
- Only parent PIN can deactivate child mode
- Auto-start is automatic and unavoidable

