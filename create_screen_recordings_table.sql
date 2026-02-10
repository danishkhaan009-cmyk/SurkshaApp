-- Table to store screen recording settings per device
CREATE TABLE IF NOT EXISTS screen_recording_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL UNIQUE,
    recording_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table to store recorded video metadata
CREATE TABLE IF NOT EXISTS screen_recordings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    file_name TEXT NOT NULL,
    drive_file_id TEXT,
    drive_link TEXT,
    file_size BIGINT,
    duration_seconds INTEGER,
    recorded_at TIMESTAMPTZ NOT NULL,
    uploaded_at TIMESTAMPTZ,
    status TEXT DEFAULT 'pending', -- pending, uploading, uploaded, failed
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE screen_recording_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE screen_recordings ENABLE ROW LEVEL SECURITY;

-- Policies for screen_recording_settings
CREATE POLICY "Allow all for screen_recording_settings" ON screen_recording_settings FOR ALL USING (true);

-- Policies for screen_recordings  
CREATE POLICY "Allow all for screen_recordings" ON screen_recordings FOR ALL USING (true);

-- Index for faster queries
CREATE INDEX idx_screen_recordings_device_id ON screen_recordings(device_id);
CREATE INDEX idx_screen_recordings_recorded_at ON screen_recordings(recorded_at DESC);
CREATE INDEX idx_screen_recording_settings_device_id ON screen_recording_settings(device_id);
