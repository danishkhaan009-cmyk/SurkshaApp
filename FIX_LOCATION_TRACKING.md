# Fix Location Tracking - Database Setup

## Problem
Location data is not showing in the parent dashboard because Supabase Row Level Security (RLS) policies are blocking the INSERT operations.

## Solution
Run the SQL script to add proper RLS policies that allow:
1. Child devices to INSERT location data
2. Parent app to READ location data

## Steps to Fix

### 1. Open Supabase Dashboard
- Go to: https://supabase.com/dashboard
- Select your project: `myxdypywnifdsaorlhsy`

### 2. Run the SQL Script
- Click on "SQL Editor" in the left sidebar
- Click "New Query"
- Copy and paste the contents of `fix_all_rls_policies.sql`
- Click "Run" button

### 3. Verify the Fix
The script will show you all the policies at the end. You should see:

**LOCATIONS table policies:**
- `Allow public to insert locations` - FOR INSERT
- `Allow public to read locations` - FOR SELECT

**DEVICES table policies:**
- `Allow public to read devices` - FOR SELECT
- `Allow public to insert devices` - FOR INSERT

### 4. Test the App
After running the SQL:
1. Uninstall the current APK from child device
2. Install `ParentControl-v1.3-auto-tracking-fix.apk`
3. Complete child device setup
4. Grant location permissions
5. Wait 2-3 minutes
6. Check parent dashboard → Child → Location Plus tab

### 5. Expected Logs (if working)
On child device you should see in console:
```
🚀 Starting location tracking for device: xxx
✅ Initial location saved
📍 Location update #1 received
💾 Location saved successfully
📍 Location update #2 received
💾 Location saved successfully
```

On parent dashboard:
```
📍 Found 1 latest locations
✅ Latest location: Lat: 37.421999, Lng: -122.084058
📜 Found 10 location history entries
```

## Why This Happens
Supabase has Row Level Security (RLS) enabled by default. Without explicit policies:
- All INSERT operations are blocked
- All SELECT operations are blocked
- Tables are protected by default

The fix adds "Allow public" policies which allow:
- Anonymous users (child devices) to insert location data
- Anonymous users (parent app) to read location data

## Alternative (More Secure)
If you want stricter security, you can modify the policies to require authentication, but this adds complexity to the child device setup.

## Files Created
- `fix_locations_rls.sql` - Simple fix for locations table only
- `fix_all_rls_policies.sql` - Complete fix for all tables (RECOMMENDED)
