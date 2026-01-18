-- Additional fields for child device setup
-- Run this SQL in your Supabase SQL Editor to add new columns

-- Add pairing_code, child_name, child_age, and permissions to devices table
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS pairing_code TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS child_name TEXT,
ADD COLUMN IF NOT EXISTS child_age TEXT,
ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '{}'::jsonb;

-- Create index on pairing_code for faster lookups
CREATE INDEX IF NOT EXISTS idx_devices_pairing_code ON public.devices(pairing_code);

-- Drop existing policy if it exists and recreate it
DROP POLICY IF EXISTS "Devices can be found by pairing code" ON public.devices;

-- Create RLS policy to allow devices to be found by pairing code (for child device pairing)
CREATE POLICY "Devices can be found by pairing code" ON public.devices
  FOR SELECT USING (pairing_code IS NOT NULL);

-- CRITICAL: Reload the schema cache so PostgREST recognizes the new columns
NOTIFY pgrst, 'reload schema';

