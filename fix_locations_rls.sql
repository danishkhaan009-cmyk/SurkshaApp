-- Fix Row Level Security (RLS) for locations table
-- This allows the location tracking service to insert location data

-- Enable RLS on locations table
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Allow public to insert locations" ON public.locations;
DROP POLICY IF EXISTS "Allow public to read locations" ON public.locations;
DROP POLICY IF EXISTS "Allow users to insert locations" ON public.locations;
DROP POLICY IF EXISTS "Allow users to read locations" ON public.locations;

-- Allow anyone to insert locations (child devices need this to track location)
CREATE POLICY "Allow public to insert locations"
ON public.locations
FOR INSERT
TO public
WITH CHECK (true);

-- Allow anyone to read locations (parent app needs this to view child locations)
CREATE POLICY "Allow public to read locations"
ON public.locations
FOR SELECT
TO public
USING (true);

-- Optional: Allow authenticated users to insert locations
CREATE POLICY "Allow authenticated to insert locations"
ON public.locations
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Optional: Allow authenticated users to read all locations
CREATE POLICY "Allow authenticated to read locations"
ON public.locations
FOR SELECT
TO authenticated
USING (true);

-- Grant necessary permissions
GRANT ALL ON public.locations TO anon;
GRANT ALL ON public.locations TO authenticated;
GRANT ALL ON public.locations TO service_role;

-- Verify the policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'locations';
