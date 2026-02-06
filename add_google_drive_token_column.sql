-- Add Google Drive token columns to devices table
-- This allows parent to share their Google Drive credentials with child devices
-- Run this SQL in your Supabase SQL Editor

-- Add columns for Google Drive authentication
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS google_drive_email TEXT,
ADD COLUMN IF NOT EXISTS google_drive_token TEXT,
ADD COLUMN IF NOT EXISTS google_drive_token_updated_at TIMESTAMP WITH TIME ZONE;

-- Add comment explaining the purpose
COMMENT ON COLUMN public.devices.google_drive_email IS 'Google Drive email set by parent for video uploads';
COMMENT ON COLUMN public.devices.google_drive_token IS 'Google Drive OAuth token shared from parent device';
COMMENT ON COLUMN public.devices.google_drive_token_updated_at IS 'When the token was last updated';

-- Verify columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'devices' 
AND column_name LIKE 'google_drive%';
