-- Quick Test: Insert location data for pappu's device
-- Copy and paste this into Supabase SQL Editor

INSERT INTO locations (device_id, latitude, longitude, address, recorded_at)
VALUES 
  ('7db57d7c-8379-4577-bb72-5cfd515c18a7', 37.4219999, -122.0840575, 'Google Campus - Mountain View, CA', NOW() - INTERVAL '5 minutes'),
  ('7db57d7c-8379-4577-bb72-5cfd515c18a7', 37.4224082, -122.0856086, 'Nearby School Area', NOW() - INTERVAL '2 hours'),
  ('7db57d7c-8379-4577-bb72-5cfd515c18a7', 37.4273334, -122.1700490, 'Local Park', NOW() - INTERVAL '4 hours');

-- After running this, go to your app and pull down to refresh on Location Plus tab
