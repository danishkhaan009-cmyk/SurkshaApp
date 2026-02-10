-- ========================================
-- DIAGNOSTIC & FIX FOR LOCATION TRACKING
-- ========================================
-- This script will show current policies and fix them if needed

-- ========================================
-- STEP 1: CHECK CURRENT POLICIES
-- ========================================
-- Run this first to see what policies exist:
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'locations'
ORDER BY policyname;

-- ========================================
-- STEP 2: DROP ALL EXISTING POLICIES
-- ========================================
-- This removes ALL policies so we can start fresh
DO $$ 
DECLARE 
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'locations' 
        AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.locations', pol.policyname);
    END LOOP;
END $$;

-- ========================================
-- STEP 3: CREATE PERMISSIVE POLICIES
-- ========================================
-- Allow public to read all locations (needed for parent dashboard)
CREATE POLICY "Allow public to read locations"
ON public.locations FOR SELECT
TO public
USING (true);

-- Allow public to insert locations (CRITICAL: needed for automatic location tracking)
CREATE POLICY "Allow public to insert locations"
ON public.locations FOR INSERT
TO public
WITH CHECK (true);

-- Allow public to update locations (for future features)
CREATE POLICY "Allow public to update locations"
ON public.locations FOR UPDATE
TO public
USING (true)
WITH CHECK (true);

-- ========================================
-- STEP 4: GRANT PERMISSIONS
-- ========================================
GRANT ALL ON public.locations TO anon;
GRANT ALL ON public.locations TO authenticated;
GRANT ALL ON public.locations TO service_role;

-- ========================================
-- STEP 5: VERIFY THE FIX
-- ========================================
-- Run this to confirm policies are correct:
SELECT 
    policyname,
    cmd as operation,
    CASE 
        WHEN qual = 'true' OR qual IS NULL THEN '✅ ALLOWS ALL'
        ELSE '❌ RESTRICTED: ' || qual
    END as who_can_access,
    CASE 
        WHEN with_check = 'true' OR with_check IS NULL THEN '✅ ALLOWS ALL'
        ELSE '❌ RESTRICTED: ' || with_check
    END as who_can_modify
FROM pg_policies 
WHERE tablename = 'locations'
ORDER BY cmd, policyname;

-- ========================================
-- STEP 6: TEST INSERT
-- ========================================
-- Try to insert a test location (use a real device_id from your devices table)
-- Replace 'YOUR-DEVICE-ID-HERE' with an actual device ID
/*
INSERT INTO public.locations (device_id, latitude, longitude, address)
VALUES ('d0b7b0f6-ef4a-4253-a570-7b9855494339', 37.4219999, -122.0840575, 'Test Location');

-- If the above works, delete the test:
DELETE FROM public.locations WHERE address = 'Test Location';
*/
