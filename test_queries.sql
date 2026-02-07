-- ============================================
-- STEP 1: First run this SQL in Supabase SQL Editor
-- ============================================
-- This creates the recording_sessions table and updates devices table
-- Copy and paste the entire create_recording_sessions_table.sql file

-- ============================================
-- STEP 2: After app is running, test with these queries
-- ============================================

-- Check if recording_sessions table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'recording_sessions';

-- View all recording sessions
SELECT 
    id,
    device_id,
    session_type,
    status,
    started_by,
    trigger_event,
    started_at,
    stopped_at,
    total_duration_seconds,
    segments_count
FROM recording_sessions
ORDER BY started_at DESC
LIMIT 10;

-- View active recording sessions
SELECT 
    device_id,
    started_by,
    trigger_event,
    started_at,
    total_duration_seconds,
    segments_count
FROM recording_sessions
WHERE status = 'active'
ORDER BY started_at DESC;

-- View recordings for a specific device
-- Replace 'YOUR_DEVICE_ID' with actual device ID
SELECT 
    id,
    started_by,
    trigger_event,
    started_at,
    stopped_at,
    total_duration_seconds
FROM recording_sessions
WHERE device_id = 'YOUR_DEVICE_ID'
ORDER BY started_at DESC;

-- Count recordings by trigger type
SELECT 
    started_by,
    COUNT(*) as count,
    SUM(total_duration_seconds) as total_seconds
FROM recording_sessions
GROUP BY started_by
ORDER BY count DESC;

-- Check device auto-recording settings
SELECT 
    id,
    auto_recording_enabled,
    auto_recording_trigger
FROM devices
WHERE auto_recording_enabled = true;

-- View screen recordings (uploaded segments)
SELECT 
    device_id,
    file_name,
    duration_seconds,
    recorded_at,
    status,
    drive_link
FROM screen_recordings
ORDER BY recorded_at DESC
LIMIT 10;
