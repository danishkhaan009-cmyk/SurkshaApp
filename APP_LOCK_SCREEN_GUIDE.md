# App Lock Screen Feature 🔒

## Overview
The App Lock Screen is a full-screen lock interface that blocks access to the device when child mode is active. Parents must enter their 4-digit PIN to unlock the device and exit child mode.

## Features

### 🎨 Design Features
- **Modern Dark Theme**: Sleek gradient background (dark blue/gray)
- **Lock Icon**: Large, centered lock icon with green accent color
- **Secure PIN Input**: 4-digit masked password field
- **Responsive UI**: Works on all screen sizes
- **Visual Feedback**: Success/error messages with color-coded SnackBars

### 🔒 Security Features
- **Back Button Blocking**: WillPopScope prevents hardware back button from bypassing lock
- **PIN Verification**: Validates against stored parent PIN
- **Auto-Clear**: Wrong PIN entries are automatically cleared
- **Haptic Feedback**: Vibration on wrong PIN entry
- **No Bypass**: Cannot navigate away without correct PIN

### ⚡ Functionality
- Deactivates child mode on correct PIN
- Stops location tracking when unlocked
- Navigates to parent dashboard after unlock
- Shows clear error messages for wrong PIN
- Prevents empty or incomplete PIN submission

---

## File Structure

```
lib/
├── pages/
│   └── app_lock_screen/
│       ├── app_lock_screen_widget.dart    # Main lock screen UI
│       └── app_lock_screen_model.dart     # State management
├── services/
│   └── app_lock_service.dart              # App blocking service
└── index.dart                              # Export declarations
```

---

## Usage

### Navigation to Lock Screen

```dart
// From any screen, navigate to lock screen
context.goNamed('App_Lock_Screen');

// Or using push
context.pushNamed('App_Lock_Screen');
```

### Automatic Lock on App Switch

To automatically show the lock screen when the user tries to open other apps (requires native Android implementation):

```dart
import '/services/app_lock_service.dart';

// Check if apps should be locked
bool shouldLock = await AppLockService.shouldLockApps();

if (shouldLock) {
  context.goNamed('App_Lock_Screen');
}
```

---

## Integration with Child Mode

### Automatic Navigation from Splash Screen

The splash screen already checks for child mode and navigates appropriately. To add app lock screen check:

```dart
// In splash_screen_widget.dart
Future<void> _checkChildModeState() async {
  await Future.delayed(const Duration(seconds: 2));
  final isChildMode = await ChildModeService.isChildModeActive();

  if (!mounted) return;

  if (isChildMode) {
    // Navigate to app lock screen instead of Setup5
    context.goNamed('App_Lock_Screen');
  } else {
    // Normal flow - go to login
    context.goNamed('Login_Screen');
  }
}
```

### Trigger Lock Screen on App Resume

To lock the screen when app comes to foreground:

```dart
// In main.dart or app-level widget
import 'package:flutter/services.dart';

@override
void initState() {
  super.initState();
  
  // Listen for app lifecycle changes
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      final isChildMode = await ChildModeService.isChildModeActive();
      if (isChildMode) {
        // Navigate to lock screen
        appNavigatorKey.currentContext?.goNamed('App_Lock_Screen');
      }
    }
  }
}
```

---

## App Lock Service

The `AppLockService` provides additional functionality for blocking specific apps:

### Manage Blocked Apps

```dart
import '/services/app_lock_service.dart';

// Get list of blocked apps
List<String> blockedApps = await AppLockService.getBlockedApps();

// Add app to blocked list
await AppLockService.addBlockedApp('com.android.chrome');

// Remove app from blocked list
await AppLockService.removeBlockedApp('com.android.chrome');

// Check if specific app is blocked
bool isBlocked = await AppLockService.isAppBlocked('com.google.android.youtube');

// Clear all blocked apps
await AppLockService.clearBlockedApps();
```

### Show Lock Overlay

```dart
// Show lock overlay over current screen
AppLockService.showLockOverlay(context);

// Remove lock overlay
AppLockService.removeLockOverlay();
```

---

## Customization

### Change Colors

Edit `/lib/pages/app_lock_screen/app_lock_screen_widget.dart`:

```dart
// Background gradient
decoration: BoxDecoration(
  gradient: LinearGradient(
    colors: [
      const Color(0xFF0F1419),  // Change dark color
      const Color(0xFF1A2332),  // Change light color
    ],
    // ...
  ),
),

// Lock icon color
Icon(
  Icons.lock_rounded,
  color: const Color(0xFF58C16D),  // Change accent color
  size: 60,
),

// Button color
backgroundColor: const Color(0xFF58C16D),  // Change button color
```

### Change PIN Length

```dart
// In app_lock_screen_widget.dart
TextField(
  maxLength: 6,  // Change from 4 to 6 digits
  // ...
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(6),  // Update limit
  ],
)

// Update validation
if (enteredPin.length != 6) {  // Change validation
  _showError('Please enter 6-digit PIN');
  return;
}
```

### Custom Lock Message

```dart
Text(
  'Your custom message here',  // Change text
  textAlign: TextAlign.center,
  style: GoogleFonts.inter(
    color: Colors.white.withOpacity(0.6),
    fontSize: 16,
    fontWeight: FontWeight.w400,
  ),
),
```

---

## Testing

### Test Lock Screen Navigation

1. Run the app on Chrome or Android device
2. Navigate to lock screen:
   ```dart
   context.goNamed('App_Lock_Screen');
   ```
3. Try back button (should not exit)
4. Enter wrong PIN (should show error)
5. Enter correct PIN (should unlock and navigate to dashboard)

### Test PIN Verification

```dart
// In Dart DevTools console
final pin = await ChildModeService.getStoredPin();
print('Stored PIN: $pin');
```

### Test Child Mode Integration

1. Activate child mode via Setup5 screen
2. Close and reopen app
3. Should navigate to lock screen automatically (if configured)
4. Enter parent PIN to unlock

---

## Native Android Integration (Optional)

For full device-level app blocking, you'll need native Android code:

### 1. Add Usage Stats Permission

`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

### 2. Create Foreground Service

Create a service that monitors running apps and shows lock screen when blocked apps are opened.

### 3. Use AccessibilityService

Alternative approach using Android AccessibilityService to detect app launches.

---

## Troubleshooting

### Issue: Lock screen can be bypassed with back button
**Solution**: Ensure `WillPopScope` is wrapping the entire scaffold with `onWillPop: () async => false`

### Issue: PIN verification fails
**Solution**: Check that PIN is properly stored in SharedPreferences via `ChildModeService`

### Issue: Lock screen doesn't show on app resume
**Solution**: Implement `WidgetsBindingObserver` as shown in integration section

### Issue: Navigation doesn't work after unlock
**Solution**: Ensure you're using `context.goNamed()` and route is registered in `nav.dart`

---

## Future Enhancements

- [ ] **Biometric Authentication**: Add fingerprint/face unlock option
- [ ] **Time-based Locks**: Lock screen only during certain hours
- [ ] **Attempt Limits**: Lock device after X wrong PIN attempts
- [ ] **Photo Capture**: Take photo of person entering wrong PIN
- [ ] **Emergency Contact**: Button to call parent from lock screen
- [ ] **Scheduled Unlock**: Automatic unlock at specific times
- [ ] **Multi-Device Sync**: Sync lock status across devices

---

## Related Files

- `/lib/services/child_mode_service.dart` - Child mode management
- `/lib/services/location_tracking_service.dart` - Location tracking
- `/lib/pages/child_device_setup5/child_device_setup5_widget.dart` - Child mode activation
- `/lib/pages/splash_screen/splash_screen_widget.dart` - App entry point
- `/lib/flutter_flow/nav/nav.dart` - Route configuration

---

## Support

For issues or questions:
1. Check that all routes are registered in `nav.dart`
2. Verify PIN is stored correctly in `ChildModeService`
3. Test on physical Android device (not just emulator)
4. Check console logs for error messages

---

**Created**: December 2025  
**Version**: 1.0.0  
**Status**: ✅ Ready for testing
