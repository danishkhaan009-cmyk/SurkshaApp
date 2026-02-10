# Testing Location Tracking - Quick Guide

## ✅ What Was Implemented

### 1. **Location Tracking Service** (`lib/services/location_tracking_service.dart`)
- Automatic location tracking every 50 meters
- Saves locations to Supabase `locations` table
- Runs continuously in background
- Singleton service (only one instance runs)

### 2. **Auto-Start on Permission Grant** (Setup5 Screen)
- When "Grant Permissions" button is clicked
- After permissions are granted
- Automatically starts tracking
- Logs: "📍 Location tracking service started for device: [deviceId]"

## 📱 How to Test

### **Step 1: Child Device Setup**
1. Open app → Login → Select Mode → **Child Mode**
2. Go through Setup1 → Setup2 → Setup3 → Setup4
3. Click **"Grant Permissions"** in Setup4
4. Allow location permission when browser/device prompts
5. Navigate to Setup5
6. Click **"Grant Permissions"** again in Setup5
7. **Watch the console logs** for:
   ```
   ✅ Child device permissions granted successfully
   📍 Location tracking service started for device: [your-device-id]
   ✅ Location saved: [lat], [lng]
   ```

### **Step 2: Verify in Supabase**
1. Go to: https://myxdypywnifdsaorlhsy.supabase.co
2. Navigate to **Table Editor** → **locations**
3. You should see new entries being added with:
   - `device_id`: Your child device ID
   - `latitude` & `longitude`: Current coordinates
   - `address`: Formatted coordinates
   - `recorded_at`: Timestamp

### **Step 3: View in Parent Dashboard**
1. Switch to Parent Mode (or use separate device/browser)
2. Login as parent
3. Go to Parent Dashboard
4. Select your child's device
5. Click on **"Location Plus"** tab
6. **Pull down to refresh**
7. You should now see:
   - **Last Known Location** with current address
   - **Location History** with recent updates

## 🔧 Testing on Different Platforms

### **Web (Chrome) - Limited**
- ✅ Browser geolocation API works
- ✅ Gets current position
- ⚠️ No background tracking (browser limitation)
- ⚠️ Updates only when app is active
- 💡 **Best for**: UI testing

### **Android Emulator - Full Features**
```bash
# Launch emulator
flutter emulators --launch Pixel_3a_API_34_extension_level_7_arm64-v8a

# Run app
flutter run -d emulator-5554
```
- ✅ Full background tracking
- ✅ Updates every 50 meters
- ✅ Continues when app is in background
- 💡 **Best for**: Feature testing

### **Physical Android Phone - Production Ready**
1. Enable USB Debugging (Developer Options)
2. Connect via USB
3. Run: `flutter run`
4. ✅ Real GPS data
5. ✅ Real-world movement tracking
6. ✅ Battery-efficient tracking
7. 💡 **Best for**: Real-world testing

## 📊 What You Should See

### **Console Logs (Child Device)**
```
✅ Starting location tracking for device: abc123
✅ Location tracking started successfully
✅ Location saved: 37.422131, -122.084801
📍 Address: Lat: 37.422131, Lng: -122.084801
```

### **Supabase Database**
```sql
SELECT * FROM locations ORDER BY recorded_at DESC LIMIT 5;
```
Should show recent location entries.

### **Parent Dashboard UI**
- **Last Known Location Card**:
  - Shows most recent address
  - "5 minutes ago" (or time)
  - "Get Directions" button (opens Google Maps)

- **Location History List**:
  - Up to 10 recent locations
  - Smart icons (home 🏠, school 🏫, etc.)
  - Each with address and timestamp

## 🐛 Troubleshooting

### **No Locations Showing?**

**Check 1: Is tracking started?**
```
Look for console log: "📍 Location tracking service started"
```
- ✅ If YES → Go to Check 2
- ❌ If NO → Grant permissions didn't work, try again

**Check 2: Are permissions granted?**
```
In child device, look for: "✅ Child device permissions granted successfully"
```
- ✅ If YES → Go to Check 3
- ❌ If NO → Click "Grant Permissions" button again

**Check 3: Is location service enabled?**
- Web: Check browser location settings
- Android: Settings → Location → ON
- Look for: "❌ Location services are disabled"

**Check 4: Is data being saved?**
```
Check Supabase locations table for new entries
```
- ✅ If data is there → Parent UI issue, check device_id match
- ❌ If no data → Check console for errors

**Check 5: Does device_id match?**
```
Child logs: "device_id: abc123"
Parent query: Looking for child with device_id "abc123"
```
- Must be exact match
- Check child's device record in Supabase `devices` table

### **Common Issues**

**Issue: "deviceId not found"**
```
⚠️ Cannot start tracking: deviceId not found
```
**Solution**: Device setup incomplete. Re-do setup from Setup1.

**Issue: "Location services are disabled"**
```
❌ Location services are disabled
```
**Solution**: 
- Web: Allow location in browser settings
- Android: Enable Location in Settings

**Issue: "Permission denied"**
```
❌ Location permissions are denied
```
**Solution**: Click "Grant Permissions" again or open Settings

**Issue: Locations appear but not in parent view**
**Solution**: 
- Pull down to refresh on Location Plus tab
- Check that child name matches exactly
- Verify device_id in database

## 🎯 Quick Test Commands

### **Trigger Manual Location Update** (for testing)
In your code, you can call:
```dart
await LocationTrackingService().triggerLocationUpdate();
```

### **Check If Tracking is Active**
```dart
bool isActive = LocationTrackingService().isTracking;
print('Tracking active: $isActive');
```

### **Stop Tracking** (when exiting child mode)
```dart
await LocationTrackingService().stopTracking();
```

## 📝 Expected Behavior

### **Automatic Updates**
- ✅ Updates every 50 meters of movement
- ✅ Runs in background (on mobile)
- ✅ Battery efficient
- ✅ Saves to database automatically

### **Parent View**
- ✅ Refreshes when you pull down
- ✅ Shows up to 10 recent locations
- ✅ Displays time ago (e.g., "5 minutes ago")
- ✅ Opens Google Maps for directions

### **Data Flow**
```
Child Device (Permission Granted)
    ↓
Location Tracking Service Starts
    ↓
Gets GPS Coordinates
    ↓
Saves to Supabase (locations table)
    ↓
Parent Dashboard Queries Database
    ↓
Displays in Location Plus Tab
```

## 🚀 Next Steps

1. **Test on child device**: Grant permissions and watch logs
2. **Verify in Supabase**: Check locations table
3. **View in parent dashboard**: Pull to refresh
4. **Move around**: Walk/drive to see updates (every 50m)
5. **Check accuracy**: Verify coordinates match actual location

## 💡 Pro Tips

1. **Keep console open** to see real-time logs
2. **Use mobile device** for real GPS testing
3. **Check Supabase first** before debugging UI
4. **Pull to refresh** parent view to see new data
5. **Wait 30 seconds** after granting permissions for first update

## ✅ Success Criteria

You'll know it's working when:
- ✅ Console shows "Location tracking service started"
- ✅ Supabase has new location entries
- ✅ Parent dashboard shows locations
- ✅ Locations update as you move
- ✅ Time ago updates correctly
