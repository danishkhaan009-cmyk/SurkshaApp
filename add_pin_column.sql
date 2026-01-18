-- Add PIN column to profiles table
-- Run this in your Supabase SQL Editor

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS pin TEXT;

-- Add comment to describe the column
COMMENT ON COLUMN public.profiles.pin IS '4-digit security PIN for app access';
