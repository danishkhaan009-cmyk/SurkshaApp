-- Sample Location Data for Testing
-- Run this in Supabase SQL Editor to add test location data
-- Make sure to replace 'YOUR_DEVICE_ID' with an actual device ID from your devices table

-- First, let's get a device ID (replace with your actual device ID)
-- You can find your device ID by running: SELECT id, child_name FROM devices;

-- Insert sample location history (replace 'YOUR_DEVICE_ID' with actual device ID)
INSERT INTO public.locations (device_id, latitude, longitude, address, recorded_at) VALUES
  -- Most recent location (Home)
  ('YOUR_DEVICE_ID', 28.5355, 77.3910, 'Home - Sector 14, Noida', NOW() - INTERVAL '5 minutes'),
  
  -- School location
  ('YOUR_DEVICE_ID', 28.5470, 77.2700, 'School - DPS RK Puram', NOW() - INTERVAL '3 hours'),
  
  -- Previous home visit
  ('YOUR_DEVICE_ID', 28.5355, 77.3910, 'Home - Sector 14, Noida', NOW() - INTERVAL '5 hours'),
  
  -- Park
  ('YOUR_DEVICE_ID', 28.5450, 77.3850, 'Park - Sector 18 Park', NOW() - INTERVAL '7 hours'),
  
  -- Friend's house
  ('YOUR_DEVICE_ID', 28.5320, 77.3980, 'Friend House - Sector 15', NOW() - INTERVAL '1 day'),
  
  -- School (previous day)
  ('YOUR_DEVICE_ID', 28.5470, 77.2700, 'School - DPS RK Puram', NOW() - INTERVAL '1 day 4 hours'),
  
  -- Mall
  ('YOUR_DEVICE_ID', 28.5680, 77.3220, 'Mall - DLF Mall of India', NOW() - INTERVAL '2 days'),
  
  -- Home (2 days ago)
  ('YOUR_DEVICE_ID', 28.5355, 77.3910, 'Home - Sector 14, Noida', NOW() - INTERVAL '2 days 3 hours'),
  
  -- Playground
  ('YOUR_DEVICE_ID', 28.5400, 77.3900, 'Playground - Community Center', NOW() - INTERVAL '3 days'),
  
  -- Home (3 days ago)
  ('YOUR_DEVICE_ID', 28.5355, 77.3910, 'Home - Sector 14, Noida', NOW() - INTERVAL '3 days 2 hours');

-- Verify the data was inserted
SELECT 
  address, 
  latitude, 
  longitude, 
  recorded_at,
  NOW() - recorded_at as time_ago
FROM public.locations 
WHERE device_id = 'YOUR_DEVICE_ID'
ORDER BY recorded_at DESC
LIMIT 10;
