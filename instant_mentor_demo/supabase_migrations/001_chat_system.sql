-- Chat System Database Setup
-- Run this in Supabase SQL Editor

-- Create chat_threads table
CREATE TABLE chat_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL,
    mentor_id UUID NOT NULL,
    subject TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create chat_messages table
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID REFERENCES chat_threads(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    sender_name TEXT,
    type TEXT DEFAULT 'text',
    content TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX chat_threads_student_mentor_idx ON chat_threads (student_id, mentor_id);
CREATE INDEX chat_threads_updated_at_idx ON chat_threads (updated_at DESC);
CREATE INDEX chat_messages_chat_created_idx ON chat_messages (chat_id, created_at);
CREATE INDEX chat_messages_sender_idx ON chat_messages (sender_id);

-- Create materialized view for chat threads with user info and unread counts
CREATE MATERIALIZED VIEW chat_threads_view AS
SELECT 
    ct.id,
    ct.student_id,
    COALESCE(student_profile.display_name, student_auth.email, 'Student') as student_name,
    ct.mentor_id,
    COALESCE(mentor_profile.display_name, mentor_auth.email, 'Mentor') as mentor_name,
    ct.subject,
    ct.updated_at,
    COALESCE(unread_counts.unread_count, 0) as unread_count
FROM chat_threads ct
-- Join with auth.users to get user emails as fallback
LEFT JOIN auth.users student_auth ON ct.student_id = student_auth.id
LEFT JOIN auth.users mentor_auth ON ct.mentor_id = mentor_auth.id
-- Join with profiles table if you have one (adjust table name as needed)
LEFT JOIN profiles student_profile ON ct.student_id = student_profile.id
LEFT JOIN profiles mentor_profile ON ct.mentor_id = mentor_profile.id
-- Calculate unread message counts
LEFT JOIN (
    SELECT 
        chat_id,
        COUNT(*) as unread_count
    FROM chat_messages 
    WHERE is_read = FALSE 
    GROUP BY chat_id
) unread_counts ON ct.id = unread_counts.chat_id;

-- Create index on the materialized view
CREATE INDEX chat_threads_view_student_idx ON chat_threads_view (student_id);
CREATE INDEX chat_threads_view_mentor_idx ON chat_threads_view (mentor_id);

-- Function to refresh the materialized view when chat data changes
CREATE OR REPLACE FUNCTION refresh_chat_threads_view()
RETURNS TRIGGER AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY chat_threads_view;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-refresh the view
CREATE TRIGGER refresh_chat_threads_view_on_thread_change
    AFTER INSERT OR UPDATE OR DELETE ON chat_threads
    FOR EACH STATEMENT
    EXECUTE FUNCTION refresh_chat_threads_view();

CREATE TRIGGER refresh_chat_threads_view_on_message_change
    AFTER INSERT OR UPDATE OR DELETE ON chat_messages
    FOR EACH STATEMENT
    EXECUTE FUNCTION refresh_chat_threads_view();

-- Function to automatically update thread updated_at when messages are added
CREATE OR REPLACE FUNCTION update_thread_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chat_threads 
    SET updated_at = NOW() 
    WHERE id = NEW.chat_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update thread timestamp on new messages
CREATE TRIGGER update_thread_on_new_message
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_thread_updated_at();
