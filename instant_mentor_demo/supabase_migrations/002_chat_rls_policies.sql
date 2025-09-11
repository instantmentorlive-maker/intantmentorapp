-- Row Level Security (RLS) Policies for Chat System
-- Run this AFTER running 001_chat_system.sql

-- Enable RLS on both tables
ALTER TABLE chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Chat Threads Policies
-- Policy: Users can view threads where they are either student or mentor
CREATE POLICY "Users can view their chat threads" ON chat_threads
    FOR SELECT
    USING (
        auth.uid() = student_id OR 
        auth.uid() = mentor_id
    );

-- Policy: Users can create new threads where they are either student or mentor
CREATE POLICY "Users can create chat threads" ON chat_threads
    FOR INSERT
    WITH CHECK (
        auth.uid() = student_id OR 
        auth.uid() = mentor_id
    );

-- Policy: Users can update threads where they are participants
CREATE POLICY "Users can update their chat threads" ON chat_threads
    FOR UPDATE
    USING (
        auth.uid() = student_id OR 
        auth.uid() = mentor_id
    )
    WITH CHECK (
        auth.uid() = student_id OR 
        auth.uid() = mentor_id
    );

-- Chat Messages Policies
-- Policy: Users can view messages in threads where they are participants
CREATE POLICY "Users can view messages in their threads" ON chat_messages
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM chat_threads 
            WHERE id = chat_messages.chat_id 
            AND (student_id = auth.uid() OR mentor_id = auth.uid())
        )
    );

-- Policy: Users can send messages in threads where they are participants
CREATE POLICY "Users can send messages in their threads" ON chat_messages
    FOR INSERT
    WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM chat_threads 
            WHERE id = chat_messages.chat_id 
            AND (student_id = auth.uid() OR mentor_id = auth.uid())
        )
    );

-- Policy: Users can update their own messages (for read status, editing, etc.)
CREATE POLICY "Users can update their messages" ON chat_messages
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM chat_threads 
            WHERE id = chat_messages.chat_id 
            AND (student_id = auth.uid() OR mentor_id = auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM chat_threads 
            WHERE id = chat_messages.chat_id 
            AND (student_id = auth.uid() OR mentor_id = auth.uid())
        )
    );

-- Policy: Users can delete their own messages
CREATE POLICY "Users can delete their own messages" ON chat_messages
    FOR DELETE
    USING (sender_id = auth.uid());

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON chat_threads TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO authenticated;

-- If using the materialized view, grant access to it
GRANT SELECT ON chat_threads_view TO authenticated;

-- Grant usage on sequences (for UUID generation)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
