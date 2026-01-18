-- Fix paired_at column to allow NULL values
-- This allows devices to be created before they are actually paired

ALTER TABLE public.devices 
ALTER COLUMN paired_at DROP NOT NULL;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
