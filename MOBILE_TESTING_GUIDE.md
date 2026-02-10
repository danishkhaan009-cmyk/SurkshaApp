# Mobile Testing Guide

## ✅ Web Error Fixed
The error "Permission.locationAlways is not supported on web" has been fixed. The app now:
- Only requests `locationAlways` on mobile platforms (Android/iOS)
- Skips unsupported permissions on web
- Works correctly in Chrome browser

## 📱 Testing on Android Emulator

### Option 1: Using Available Emulator
```bash
# Launch the Android emulator
flutter emulators --launch Pixel_3a_API_34_extension_level_7_arm64-v8a

# Wait 30-60 seconds for emulator to boot, then run:
flutter run -d emulator-5554
```

### Option 2: Quick Test Command
```bash
# This will start the emulator and run the app automatically
flutter run
# Then select the Android option when prompted
```

## 📲 Testing on Physical Android Phone

### Step 1: Enable Developer Options on Your Phone
1. Go to **Settings** → **About Phone**
2. Tap **Build Number** 7 times (you'll see "You are now a developer!")
3. Go back to **Settings** → **System** → **Developer Options**
4. Enable **USB Debugging**

### Step 2: Connect Your Phone
1. Connect your phone to Mac via USB cable
2. On phone: Allow USB debugging when prompted
3. Verify connection:
   ```bash
   flutter devices
   ```
   You should see your phone listed

### Step 3: Run App on Phone
```bash
# Run directly on connected phone
flutter run

# Or specify device if multiple devices connected
flutter run -d <device-id>
```

## 📲 Testing on Physical iPhone

### Prerequisites
- Mac with Xcode installed
- Apple Developer account (free tier works)
- iPhone connected via USB/Lightning cable

### Step 1: Trust Computer
1. Connect iPhone to Mac
2. On iPhone: Tap **Trust** when "Trust This Computer?" appears
3. Enter iPhone passcode

### Step 2: Configure Xcode
1. Open terminal and run:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. In Xcode:
   - Select **Runner** project
   - Go to **Signing & Capabilities**
   - Select your Apple ID team
   - Bundle Identifier will auto-generate

### Step 3: Run on iPhone
```bash
flutter run
# Select iPhone from device list
```

## 🧪 What to Test

### Permission Flow Testing
1. **Navigate to Child Device Setup:**
   - Login → Select Mode → Choose Child Mode
   - Go through Setup1 → Setup2 → Setup3 → Setup4

2. **Test Grant Permissions Button (Setup4):**
   - Click "Grant Permissions" button
   - Should see permission dialogs for:
     - ✅ Location access
     - ✅ Background location (Android)
     - ✅ Photos access
     - ✅ Storage access (Android)
   - Grant all permissions
   - Should navigate to Setup5 automatically

3. **Test Grant Permissions Button (Setup5):**
   - Click "Grant Permissions" button again
   - Should see success message
   - Should stay on Setup5 screen

4. **Test Permission Denials:**
   - Deny location permission when prompted
   - Should see orange warning message
   - Try clicking button again
   - If permanently denied → should show dialog with "Open Settings"

### Location Tracking Testing
1. **On Child Device:**
   - Complete setup with all permissions granted
   - Keep app running in background
   - Move around (or simulate location in emulator)

2. **On Parent Dashboard:**
   - Go to Childs Device → Location Plus tab
   - Pull down to refresh
   - Should see location updates appear
   - Test "Get Directions" button

## 🐛 Platform Differences

### Web (Chrome/Safari)
- ❌ No `locationAlways` permission (fixed - no longer requested)
- ✅ Basic location via browser geolocation API
- ❌ No background tracking
- ❌ Limited storage/photos access

### Android
- ✅ Full location tracking
- ✅ Background location (`locationAlways`)
- ✅ Storage & photos access
- ✅ All features work

### iOS
- ✅ Full location tracking
- ✅ Background location
- ✅ Photos access
- ⚠️ Requires "Always Allow" for background tracking
- ⚠️ May need `NSLocationAlwaysAndWhenInUseUsageDescription` in Info.plist

## 📝 Expected Results

### Chrome (After Fix)
- ✅ No errors about `locationAlways`
- ✅ Will request basic location permission
- ✅ App runs smoothly
- ⚠️ Limited tracking capabilities

### Mobile Devices
- ✅ All permission dialogs appear properly
- ✅ Background tracking works
- ✅ Location history updates
- ✅ Full app functionality

## 🔧 Troubleshooting

### Emulator Won't Start
```bash
# Check emulator status
emulator -list-avds

# Force kill and restart
killall qemu-system-x86_64
flutter emulators --launch Pixel_3a_API_34_extension_level_7_arm64-v8a
```

### Phone Not Detected
```bash
# Check ADB connection (Android)
flutter devices

# Restart ADB if needed
adb kill-server
adb start-server
flutter devices
```

### Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Permission Issues on Android
- Go to Phone Settings → Apps → Your App → Permissions
- Manually enable all required permissions
- Clear app data and try again

### iOS Certificate Issues
- Open Xcode: `open ios/Runner.xcworkspace`
- Let Xcode automatically manage signing
- May need to register device in Apple Developer Portal

## 🚀 Quick Start Command

For fastest testing:
```bash
# Run this single command - it will show available devices
flutter run

# Then type the number for your device (1, 2, 3, etc.)
```

## 📊 Monitoring During Testing

Watch the console for these log messages:
- `✅ Child device permissions granted successfully` - Permissions OK
- `❌ Error requesting permissions:` - Permission error
- Location updates in Supabase database
- Navigation route changes

## 💡 Tips

1. **Use Chrome for quick UI testing** (permissions limited)
2. **Use Android Emulator for full feature testing** (all permissions work)
3. **Use Physical Phone for real-world testing** (best for GPS tracking)
4. **Check Supabase dashboard** to verify location data is being saved
5. **Test in both Parent and Child modes** to verify full flow
