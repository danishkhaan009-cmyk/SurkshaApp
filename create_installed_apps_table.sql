-- Create installed_apps table for tracking apps on child devices
-- Run this in your Supabase SQL Editor

-- Create the table
CREATE TABLE IF NOT EXISTS public.installed_apps (
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
CREATE INDEX IF NOT EXISTS idx_installed_apps_device_id ON public.installed_apps(device_id);
CREATE INDEX IF NOT EXISTS idx_installed_apps_package_name ON public.installed_apps(package_name);
CREATE INDEX IF NOT EXISTS idx_installed_apps_synced_at ON public.installed_apps(synced_at);

-- Enable Row Level Security
ALTER TABLE public.installed_apps ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies

-- Allow public to read all installed apps (needed for parent dashboard)
CREATE POLICY "Allow public to read installed apps"
ON public.installed_apps FOR SELECT
TO public
USING (true);

-- Allow public to insert installed apps (needed for child device sync)
CREATE POLICY "Allow public to insert installed apps"
ON public.installed_apps FOR INSERT
TO public
WITH CHECK (true);

-- Allow public to update installed apps (needed for app version updates)
CREATE POLICY "Allow public to update installed apps"
ON public.installed_apps FOR UPDATE
TO public
USING (true);

-- Allow public to delete installed apps (needed for cleanup)
CREATE POLICY "Allow public to delete installed apps"
ON public.installed_apps FOR DELETE
TO public
USING (true);

-- Add comment
COMMENT ON TABLE public.installed_apps IS 'Stores installed applications for each child device';

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
