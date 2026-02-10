-- Complete migration script for profiles table
-- Run this in your Supabase SQL Editor (https://myxdypywnifdsaorlhsy.supabase.co)

-- 1. Add phone column if it doesn't exist
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS phone TEXT;

-- 2. Add pin column if it doesn't exist
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS pin TEXT;

-- 3. Add full_name column if it doesn't exist (it should already exist)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS full_name TEXT;

-- 4. Update full_name for existing users where it's NULL or empty
-- This sets full_name to the part before @ in the email
UPDATE public.profiles 
SET full_name = SPLIT_PART(email, '@', 1)
WHERE full_name IS NULL OR full_name = '' OR full_name = email;

-- 5. Add comments to columns
COMMENT ON COLUMN public.profiles.phone IS 'User phone number';
COMMENT ON COLUMN public.profiles.pin IS 'User 4-digit PIN for security';
COMMENT ON COLUMN public.profiles.full_name IS 'User full name';

-- 6. Verify all columns exist
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'profiles' 
AND column_name IN ('id', 'email', 'full_name', 'phone', 'pin', 'role')
ORDER BY column_name;
