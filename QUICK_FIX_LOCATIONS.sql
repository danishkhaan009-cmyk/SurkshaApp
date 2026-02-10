-- ========================================
-- QUICK FIX FOR LOCATION TRACKING
-- ========================================
-- This script ONLY fixes the RLS policies blocking location tracking
-- Run this in your Supabase SQL Editor

-- ========================================
-- STEP 1: Drop Existing Restrictive Policies
-- ========================================
DROP POLICY IF EXISTS "Users can view device locations" ON public.locations;
DROP POLICY IF EXISTS "Users can insert device locations" ON public.locations;
DROP POLICY IF EXISTS "Users can update device locations" ON public.locations;
DROP POLICY IF EXISTS "Users can delete device locations" ON public.locations;

-- ========================================
-- STEP 2: Create Permissive Policies for Locations
-- ========================================
-- Drop the policies we're about to create (in case they exist)
DROP POLICY IF EXISTS "Allow public to read locations" ON public.locations;
DROP POLICY IF EXISTS "Allow public to insert locations" ON public.locations;

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

-- ========================================
-- STEP 3: Grant Permissions
-- ========================================
GRANT ALL ON public.locations TO anon;
GRANT ALL ON public.locations TO authenticated;
GRANT ALL ON public.locations TO service_role;

-- ========================================
-- DONE! 🎉
-- ========================================
-- After running this script:
-- 1. Automatic location tracking will work immediately
-- 2. Parent dashboard will show child locations correctly
-- 3. No APK rebuild needed - existing app will work!
