-- Comprehensive Database Migration for SurakshaApp
-- Run this in your Supabase SQL Editor to add missing columns
-- ===============================================================

-- Step 1: Add PIN column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'pin'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN pin TEXT;
        COMMENT ON COLUMN public.profiles.pin IS '4-digit PIN for authentication';
    END IF;
END $$;

-- Step 2: Add phone column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'phone'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN phone TEXT;
        COMMENT ON COLUMN public.profiles.phone IS 'User phone number';
    END IF;
END $$;

-- Step 3: Update full_name for users where it's NULL or equals email
-- This extracts the username part from email as a temporary name
UPDATE public.profiles 
SET full_name = SPLIT_PART(email, '@', 1)
WHERE full_name IS NULL OR full_name = '' OR full_name = email;

-- Step 4: Verify the changes
SELECT 
    column_name, 
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'profiles' 
AND column_name IN ('id', 'email', 'full_name', 'phone', 'pin', 'role')
ORDER BY ordinal_position;

-- Step 5: View current data to confirm
SELECT 
    id,
    email,
    full_name,
    phone,
    pin,
    role,
    created_at
FROM public.profiles 
ORDER BY created_at DESC
LIMIT 5;
