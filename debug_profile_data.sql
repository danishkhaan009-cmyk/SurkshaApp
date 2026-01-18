-- Debug and fix profile data issues
-- Run this in your Supabase SQL Editor

-- 1. First, let's see what data currently exists in profiles table
SELECT id, email, full_name, phone, pin, role 
FROM public.profiles 
LIMIT 10;

-- 2. Check if full_name column contains email values (which would be wrong)
SELECT id, email, full_name,
       CASE 
           WHEN full_name = email THEN 'ISSUE: full_name equals email'
           WHEN full_name IS NULL THEN 'ISSUE: full_name is NULL'
           ELSE 'OK'
       END as status
FROM public.profiles;

-- 3. If you need to fix full_name column that has email values,
--    you can extract the name from email or set a default
-- Uncomment and modify this if needed:
-- UPDATE public.profiles 
-- SET full_name = SPLIT_PART(email, '@', 1)
-- WHERE full_name IS NULL OR full_name = email OR full_name = '';
