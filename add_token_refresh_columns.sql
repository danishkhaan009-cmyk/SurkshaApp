-- Add token refresh request columns to devices table
-- The child device writes these when it needs the parent to refresh the Google Drive token
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS token_refresh_requested BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS token_refresh_requested_at TIMESTAMP WITH TIME ZONE;
