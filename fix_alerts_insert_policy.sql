-- Fix alerts table - Add missing INSERT policy
-- Run this in Supabase SQL Editor

-- Add INSERT policy for alerts table
CREATE POLICY "Users can insert alerts for own devices" ON public.alerts
  FOR INSERT WITH CHECK (
    device_id IN (
      SELECT id FROM public.devices WHERE user_id = auth.uid()
    )
  );

-- Verify the policy was created
SELECT schemaname, tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename = 'alerts';
