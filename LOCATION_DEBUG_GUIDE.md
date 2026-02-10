# 🔍 Location Tracking Debug Guide

## Current Status
✅ App is running on Chrome
✅ Debug logging is enabled
✅ Location tracking service is implemented

## 🐛 Debugging Steps

### Step 1: Check Console Logs
Open Chrome DevTools Console (F12 or Cmd+Option+I) and watch for these logs:

#### When Going to Child's Device Page:
```
🔍 Fetching location data for child: [child_name]
📱 Found [X] devices for child: [child_name]
✅ Device ID: [device-id]
📍 Found [X] latest locations
📜 Found [X] location history entries
✅ Location data fetch completed
```

**If you see:**
- `Found 0 devices` → The child_name doesn't match any device
- `Found 0 latest locations` → No location data in database
- `No devices found` → Device not paired yet

#### When Granting Permissions (Child Mode Setup5):
```
✅ Child device permissions granted successfully
📍 Location tracking service started for device: [device-id]
✅ Starting location tracking for device: [device-id]
✅ Location tracking started successfully
💾 Attempting to save location for device: [device-id]
📍 Coordinates: [lat], [lng]
✅ Location saved successfully
```

**If you see:**
- `⚠️ Cannot start tracking: deviceId not found` → Setup data incomplete
- `❌ Location services are disabled` → Enable browser location
- `❌ Failed to save location` → Database permission issue

### Step 2: Manual Test with SQL

#### 2a. Check what devices exist:
```sql
SELECT id, child_name, device_name, parent_id, paired_at 
FROM devices 
ORDER BY paired_at DESC;
```
**Note the:**
- `id` (this is the device_id)
- `child_name` (must match exactly what parent sees)

#### 2b. Insert test location manually:
```sql
-- Replace 'YOUR_DEVICE_ID' with actual id from above query
INSERT INTO locations (device_id, latitude, longitude, address, recorded_at)
VALUES (
  'YOUR_DEVICE_ID',
  37.4219999,
  -122.0840575,
  'Google Campus - 1600 Amphitheatre Parkway',
  NOW()
);
```

#### 2c. Verify it was inserted:
```sql
SELECT * FROM locations 
WHERE device_id = 'YOUR_DEVICE_ID'
ORDER BY recorded_at DESC 
LIMIT 5;
```

#### 2d. Check if parent can see it:
Go to Parent Dashboard → Select Child → Location Plus Tab → Pull to Refresh

### Step 3: Common Issues & Solutions

#### Issue 1: "No location data available"
**Diagnosis:**
```sql
-- Check if locations table has any data at all
SELECT COUNT(*) FROM locations;

-- Check specific device
SELECT * FROM locations WHERE device_id = 'YOUR_DEVICE_ID';
```

**Solutions:**
- If COUNT = 0 → No locations saved yet, go to child device and grant permissions
- If no data for device → device_id mismatch, check devices table

#### Issue 2: Child name mismatch
**Diagnosis:**
```sql
-- What child_name is in devices?
SELECT child_name FROM devices;

-- What is parent trying to query?
-- Check console log: "Fetching location data for child: [name]"
```

**Solutions:**
- Names must match EXACTLY (case-sensitive)
- Check for extra spaces or special characters
- Update device if needed:
```sql
UPDATE devices 
SET child_name = 'CorrectName' 
WHERE id = 'device-id';
```

#### Issue 3: Permission errors on web
**Web Limitations:**
- ⚠️ Web browsers have limited location tracking
- ⚠️ Only works when tab is active
- ⚠️ No background tracking

**Solutions:**
1. Click "Allow" when browser asks for location
2. Check browser settings: chrome://settings/content/location
3. For real testing, use Android device

#### Issue 4: Data saved but not showing in UI
**Diagnosis:**
```sql
-- Verify data exists
SELECT d.child_name, l.* 
FROM locations l
JOIN devices d ON d.id = l.device_id
ORDER BY l.recorded_at DESC 
LIMIT 10;
```

**Solutions:**
- Pull down to refresh in Location Plus tab
- Check console for fetch errors
- Verify child_name matches exactly

### Step 4: Test Location Tracking on Child Device

1. **Open in Chrome (Child Mode):**
   - Login → Select Mode → Child Mode
   - Complete Setup1 → Setup2 → Setup3 → Setup4
   - Click "Grant Permissions" in Setup4
   - Click "Grant Permissions" in Setup5

2. **Watch Console for:**
   ```
   ✅ Child device permissions granted successfully
   📍 Location tracking service started for device: [id]
   ✅ Starting location tracking for device: [id]
   💾 Attempting to save location for device: [id]
   📍 Coordinates: [lat], [lng]
   ✅ Location saved successfully
   ```

3. **If you see errors:**
   - `deviceId not found` → Redo device setup from Setup1
   - `Location services disabled` → Allow in browser
   - `Failed to save location` → Check Supabase RLS policies

### Step 5: Test Parent View

1. **Open Parent Dashboard:**
   - Login → Select Mode → Parent Mode
   - Click on child's card
   - Go to "Location Plus" tab

2. **Watch Console for:**
   ```
   🔍 Fetching location data for child: [name]
   📱 Found 1 devices for child: [name]
   ✅ Device ID: [id]
   📍 Found 1 latest locations
   📜 Found [X] location history entries
   ✅ Location data fetch completed
   ```

3. **Pull down to refresh** if needed

### Step 6: Check Database Directly

#### In Supabase Dashboard:

1. **Check locations table:**
   - Go to Table Editor → locations
   - Should see rows with:
     - device_id
     - latitude, longitude
     - address
     - recorded_at (timestamp)

2. **Check devices table:**
   - Go to Table Editor → devices
   - Verify child_name is correct
   - Note the device id

3. **Check RLS policies:**
   - Go to Table Editor → locations → RLS Policies
   - Verify SELECT policy exists and allows reading
   - Verify INSERT policy exists for authenticated users

## 🎯 Expected Flow

### Child Device Setup:
```
Setup5 → Grant Permissions → Browser Asks → User Allows
    ↓
Location Service Checks Permission → Gets Current Position
    ↓
Saves to Supabase locations table
    ↓
Console shows: "✅ Location saved successfully"
```

### Parent View:
```
Open Child's Device → Location Plus Tab → _fetchLocationData()
    ↓
Query devices table by child_name → Get device_id
    ↓
Query locations table by device_id → Get locations
    ↓
Display in UI (Last Known + History)
```

## 📊 Success Indicators

You'll know it's working when you see ALL of these:

### Console Logs:
- ✅ "Location tracking service started"
- ✅ "Location saved successfully"
- ✅ "Found 1 devices for child"
- ✅ "Found X location history entries"

### Database:
- ✅ Rows in `locations` table
- ✅ device_id matches device in `devices` table
- ✅ recent `recorded_at` timestamps

### UI:
- ✅ Last Known Location shows address
- ✅ Location History shows entries
- ✅ Time ago updates correctly
- ✅ Pull to refresh works

## 🚀 Quick Fix: Manual Data Insert

If you want to test the UI immediately without waiting for tracking:

```sql
-- 1. Get your device ID
SELECT id, child_name FROM devices LIMIT 1;

-- 2. Insert test data (replace YOUR_DEVICE_ID)
INSERT INTO locations (device_id, latitude, longitude, address, recorded_at)
VALUES 
  ('YOUR_DEVICE_ID', 37.422, -122.084, 'Home Location', NOW() - INTERVAL '5 minutes'),
  ('YOUR_DEVICE_ID', 37.424, -122.086, 'School', NOW() - INTERVAL '2 hours'),
  ('YOUR_DEVICE_ID', 37.427, -122.170, 'Park', NOW() - INTERVAL '1 day');

-- 3. Verify
SELECT * FROM locations ORDER BY recorded_at DESC LIMIT 5;
```

Then refresh the Location Plus tab in parent view!

## 💡 Pro Tips

1. **Keep DevTools console open** - Logs tell you everything
2. **Check Supabase first** - If data is there, it's a UI issue
3. **Match names exactly** - child_name query is case-sensitive  
4. **Pull to refresh** - UI doesn't auto-update
5. **Test on mobile** - Web has limited location tracking
6. **Check timestamps** - Ensure recent data exists

## ⚠️ Current Limitations on Web

- Location only updates when app is active
- No background tracking
- Requires manual permission grant each session
- Limited accuracy compared to mobile

For full functionality, test on Android device using:
```bash
flutter run -d <android-device-id>
```
