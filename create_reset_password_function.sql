-- =============================================================
-- Supabase Function: reset_user_password
-- 
-- This function:
-- 1. Checks if a user with the given email exists
-- 2. Updates their password directly in auth.users
-- 3. Returns success or error
--
-- PREREQUISITES:
--   Make sure pgcrypto extension is enabled (it is by default in Supabase)
--
-- Run this SQL in your Supabase SQL Editor (Dashboard > SQL Editor)
-- =============================================================

-- Ensure pgcrypto is available
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.reset_user_password(
  user_email TEXT,
  new_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  target_user_id UUID;
BEGIN
  -- 1. Find the user by email (case insensitive)
  SELECT id INTO target_user_id
  FROM auth.users
  WHERE email = lower(trim(user_email))
  LIMIT 1;

  IF target_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No account found with this email address.');
  END IF;

  -- 2. Update the user's password directly
  UPDATE auth.users
  SET encrypted_password = crypt(new_password, gen_salt('bf')),
      updated_at = now()
  WHERE id = target_user_id;

  -- 3. Return success
  RETURN jsonb_build_object('success', true, 'message', 'Password updated successfully.');
END;
$$;

-- Grant execute to anon (user is NOT logged in when resetting password)
GRANT EXECUTE ON FUNCTION public.reset_user_password(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.reset_user_password(TEXT, TEXT) TO authenticated;
