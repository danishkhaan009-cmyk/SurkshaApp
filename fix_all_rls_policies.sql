-- Complete RLS Fix for All Tables
-- Run this in your Supabase SQL Editor

-- ==========================================
-- 1. DEVICES TABLE
-- ==========================================
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow public to read devices" ON public.devices;
DROP POLICY IF EXISTS "Allow public to insert devices" ON public.devices;
DROP POLICY IF EXISTS "Allow authenticated to read devices" ON public.devices;
DROP POLICY IF EXISTS "Allow authenticated to insert devices" ON public.devices;

-- Allow anyone to read devices (parent needs to find child devices)
CREATE POLICY "Allow public to read devices"
ON public.devices
FOR SELECT
TO public
USING (true);

-- Allow anyone to insert devices (child device setup needs this)
CREATE POLICY "Allow public to insert devices"
ON public.devices
FOR INSERT
TO public
WITH CHECK (true);

-- Allow authenticated users to update their devices
CREATE POLICY "Allow authenticated to update devices"
ON public.devices
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- ==========================================
-- 2. LOCATIONS TABLE
-- ==========================================
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow public to insert locations" ON public.locations;
DROP POLICY IF EXISTS "Allow public to read locations" ON public.locations;
DROP POLICY IF EXISTS "Allow authenticated to insert locations" ON public.locations;
DROP POLICY IF EXISTS "Allow authenticated to read locations" ON public.locations;

-- Allow anyone to insert locations (child devices tracking)
CREATE POLICY "Allow public to insert locations"
ON public.locations
FOR INSERT
TO public
WITH CHECK (true);

-- Allow anyone to read locations (parent viewing child locations)
CREATE POLICY "Allow public to read locations"
ON public.locations
FOR SELECT
TO public
USING (true);

-- ==========================================
-- 3. ALERTS TABLE
-- ==========================================
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow public to read alerts" ON public.alerts;
DROP POLICY IF EXISTS "Allow public to insert alerts" ON public.alerts;

-- Allow anyone to read alerts
CREATE POLICY "Allow public to read alerts"
ON public.alerts
FOR SELECT
TO public
USING (true);

-- Allow anyone to insert alerts
CREATE POLICY "Allow public to insert alerts"
ON public.alerts
FOR INSERT
TO public
WITH CHECK (true);

-- Allow authenticated users to update alerts (mark as read)
CREATE POLICY "Allow authenticated to update alerts"
ON public.alerts
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- ==========================================
-- 4. PROFILES TABLE
-- ==========================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow public to read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow public to insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- Allow anyone to read profiles
CREATE POLICY "Allow public to read profiles"
ON public.profiles
FOR SELECT
TO public
USING (true);

-- Allow anyone to insert profiles (signup)
CREATE POLICY "Allow public to insert profiles"
ON public.profiles
FOR INSERT
TO public
WITH CHECK (true);

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ==========================================
-- 5. GRANT PERMISSIONS
-- ==========================================
GRANT ALL ON public.devices TO anon;
GRANT ALL ON public.devices TO authenticated;
GRANT ALL ON public.devices TO service_role;

GRANT ALL ON public.locations TO anon;
GRANT ALL ON public.locations TO authenticated;
GRANT ALL ON public.locations TO service_role;

GRANT ALL ON public.alerts TO anon;
GRANT ALL ON public.alerts TO authenticated;
GRANT ALL ON public.alerts TO service_role;

GRANT ALL ON public.profiles TO anon;
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;

-- ==========================================
-- 6. VERIFY POLICIES
-- ==========================================
-- Check devices policies
SELECT 'DEVICES:' as table_name, policyname, roles, cmd 
FROM pg_policies 
WHERE tablename = 'devices'
UNION ALL
-- Check locations policies
SELECT 'LOCATIONS:' as table_name, policyname, roles, cmd 
FROM pg_policies 
WHERE tablename = 'locations'
UNION ALL
-- Check alerts policies
SELECT 'ALERTS:' as table_name, policyname, roles, cmd 
FROM pg_policies 
WHERE tablename = 'alerts'
UNION ALL
-- Check profiles policies
SELECT 'PROFILES:' as table_name, policyname, roles, cmd 
FROM pg_policies 
WHERE tablename = 'profiles';
