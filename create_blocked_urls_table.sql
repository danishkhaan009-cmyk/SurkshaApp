-- Create blocked_urls table for storing parent-blocked websites
-- Run this in your Supabase SQL editor

-- Drop the table if it exists (for fresh start)
DROP TABLE IF EXISTS public.blocked_urls CASCADE;

-- Create the blocked_urls table
CREATE TABLE IF NOT EXISTS public.blocked_urls (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL,
    url TEXT NOT NULL,
    blocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    blocked_by UUID REFERENCES auth.users(id),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(device_id, url)
);

-- Create search_history table for storing child's browsing history
DROP TABLE IF EXISTS public.search_history CASCADE;

CREATE TABLE IF NOT EXISTS public.search_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL,
    url TEXT NOT NULL,
    title TEXT,
    visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    visit_count INTEGER DEFAULT 1
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_blocked_urls_device_id ON public.blocked_urls(device_id);
CREATE INDEX IF NOT EXISTS idx_blocked_urls_url ON public.blocked_urls(url);
CREATE INDEX IF NOT EXISTS idx_blocked_urls_active ON public.blocked_urls(is_active);
CREATE INDEX IF NOT EXISTS idx_search_history_device_id ON public.search_history(device_id);
CREATE INDEX IF NOT EXISTS idx_search_history_visited_at ON public.search_history(visited_at DESC);

-- Enable Row Level Security
ALTER TABLE public.blocked_urls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for blocked_urls
-- Allow authenticated users to read blocked URLs
CREATE POLICY "Allow authenticated users to read blocked_urls"
    ON public.blocked_urls
    FOR SELECT
    TO authenticated
    USING (true);

-- Allow authenticated users to insert blocked URLs
CREATE POLICY "Allow authenticated users to insert blocked_urls"
    ON public.blocked_urls
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Allow authenticated users to update blocked URLs
CREATE POLICY "Allow authenticated users to update blocked_urls"
    ON public.blocked_urls
    FOR UPDATE
    TO authenticated
    USING (true);

-- Allow authenticated users to delete blocked URLs
CREATE POLICY "Allow authenticated users to delete blocked_urls"
    ON public.blocked_urls
    FOR DELETE
    TO authenticated
    USING (true);

-- RLS Policies for search_history
-- Allow authenticated users to read search history
CREATE POLICY "Allow authenticated users to read search_history"
    ON public.search_history
    FOR SELECT
    TO authenticated
    USING (true);

-- Allow public to insert search history (for child devices)
CREATE POLICY "Allow public to insert search_history"
    ON public.search_history
    FOR INSERT
    TO public
    WITH CHECK (true);

-- Allow public to read search history
CREATE POLICY "Allow public to read search_history"
    ON public.search_history
    FOR SELECT
    TO public
    USING (true);

-- Allow public to update search history (for visit count updates)
CREATE POLICY "Allow public to update search_history"
    ON public.search_history
    FOR UPDATE
    TO public
    USING (true)
    WITH CHECK (true);

-- Grant permissions
GRANT ALL ON public.blocked_urls TO authenticated;
GRANT ALL ON public.search_history TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.search_history TO anon;
GRANT SELECT ON public.blocked_urls TO anon;

-- Verify tables were created
SELECT 'blocked_urls table created successfully' AS status;
SELECT 'search_history table created successfully' AS status;
