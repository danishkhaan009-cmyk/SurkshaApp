-- Test Location Data Insert
-- Replace 'YOUR_DEVICE_ID' with actual device_id from the devices table

-- First, check what devices exist
SELECT id, child_name, device_name FROM devices ORDER BY paired_at DESC;

-- Then insert test location data (replace the device_id below)
INSERT INTO locations (device_id, latitude, longitude, address, recorded_at)
VALUES 
  ('YOUR_DEVICE_ID', 37.4219999, -122.0840575, 'Home - 1600 Amphitheatre Parkway, Mountain View, CA', NOW() - INTERVAL '5 minutes'),
  ('YOUR_DEVICE_ID', 37.4224082, -122.0856086, 'School - Nearby area', NOW() - INTERVAL '2 hours'),
  ('YOUR_DEVICE_ID', 37.4273334, -122.1700490, 'Park - Recreation area', NOW() - INTERVAL '1 day');

-- Verify the data was inserted
SELECT * FROM locations ORDER BY recorded_at DESC LIMIT 10;
