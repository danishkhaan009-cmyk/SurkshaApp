-- =====================================================
-- COMPLETE FIX FOR SEARCH HISTORY - Run in Supabase SQL Editor
-- =====================================================

-- Step 1: Ensure the table exists with correct schema
CREATE TABLE IF NOT EXISTS public.search_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL,
    url TEXT NOT NULL,
    title TEXT,
    visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    visit_count INTEGER DEFAULT 1
);

-- Step 2: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_search_history_device_id ON public.search_history(device_id);
CREATE INDEX IF NOT EXISTS idx_search_history_visited_at ON public.search_history(visited_at DESC);

-- Step 3: Enable RLS
ALTER TABLE public.search_history ENABLE ROW LEVEL SECURITY;

-- Step 4: Drop existing policies to recreate them cleanly
DROP POLICY IF EXISTS "Allow authenticated users to read search_history" ON public.search_history;
DROP POLICY IF EXISTS "Allow public to insert search_history" ON public.search_history;
DROP POLICY IF EXISTS "Allow public to read search_history" ON public.search_history;
DROP POLICY IF EXISTS "Allow public to update search_history" ON public.search_history;
DROP POLICY IF EXISTS "Allow anon to insert search_history" ON public.search_history;
DROP POLICY IF EXISTS "Allow anon to update search_history" ON public.search_history;

-- Step 5: Create all necessary policies
-- Allow anyone to SELECT
CREATE POLICY "Allow public to read search_history"
    ON public.search_history
    FOR SELECT
    TO public
    USING (true);

-- Allow anyone to INSERT (for child devices)
CREATE POLICY "Allow public to insert search_history"
    ON public.search_history
    FOR INSERT
    TO public
    WITH CHECK (true);

-- Allow anyone to UPDATE (for visit count updates)
CREATE POLICY "Allow public to update search_history"
    ON public.search_history
    FOR UPDATE
    TO public
    USING (true)
    WITH CHECK (true);

-- Step 6: Grant permissions to anon and authenticated roles
GRANT SELECT, INSERT, UPDATE ON public.search_history TO anon;
GRANT ALL ON public.search_history TO authenticated;

-- Step 7: Verify setup
SELECT 'Policies on search_history:' as info;
SELECT policyname, cmd, roles FROM pg_policies WHERE tablename = 'search_history';

SELECT 'Grants on search_history:' as info;
SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name = 'search_history';

-- Step 8: Test insert (you can run this manually to verify it works)
-- Replace 'test-device-id' with an actual device ID to test
-- INSERT INTO public.search_history (device_id, url, title, visited_at, visit_count)
-- VALUES ('test-device-id', 'https://google.com', 'Google Test', NOW(), 1);

SELECT 'Setup complete! Run this SQL in Supabase SQL Editor.' as status;
