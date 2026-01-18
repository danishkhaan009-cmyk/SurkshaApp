-- Fix installed_apps table - ensure it has the correct schema
-- Run this in your Supabase SQL Editor

-- Drop and recreate the table with correct schema
DROP TABLE IF EXISTS public.installed_apps CASCADE;

-- Create the table with correct columns
CREATE TABLE public.installed_apps (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE NOT NULL,
  app_name TEXT NOT NULL,
  package_name TEXT NOT NULL,
  version_name TEXT,
  version_code INTEGER,
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  
  -- Unique constraint to prevent duplicate apps per device
  CONSTRAINT unique_device_app UNIQUE(device_id, package_name)
);

-- Create indexes for better performance
CREATE INDEX idx_installed_apps_device_id ON public.installed_apps(device_id);
CREATE INDEX idx_installed_apps_package_name ON public.installed_apps(package_name);
CREATE INDEX idx_installed_apps_synced_at ON public.installed_apps(synced_at);

-- Enable Row Level Security
ALTER TABLE public.installed_apps ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Allow public to read installed apps" ON public.installed_apps;
DROP POLICY IF EXISTS "Allow public to insert installed apps" ON public.installed_apps;
DROP POLICY IF EXISTS "Allow public to update installed apps" ON public.installed_apps;
DROP POLICY IF EXISTS "Allow public to delete installed apps" ON public.installed_apps;

-- Create RLS Policies
CREATE POLICY "Allow public to read installed apps"
ON public.installed_apps FOR SELECT
TO public
USING (true);

CREATE POLICY "Allow public to insert installed apps"
ON public.installed_apps FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "Allow public to update installed apps"
ON public.installed_apps FOR UPDATE
TO public
USING (true);

CREATE POLICY "Allow public to delete installed apps"
ON public.installed_apps FOR DELETE
TO public
USING (true);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.installed_apps;
