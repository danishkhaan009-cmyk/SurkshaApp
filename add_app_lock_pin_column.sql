-- Migration: add app_lock_pin column to device_rules
-- Run this in Supabase SQL editor or via psql

ALTER TABLE public.device_rules
ADD COLUMN IF NOT EXISTS app_lock_pin text;

-- Optional: create an index if you plan to query by this column (not necessary for hashed PINs)
-- CREATE INDEX IF NOT EXISTS idx_device_rules_app_lock_pin ON public.device_rules (app_lock_pin);

