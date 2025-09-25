-- =========================================================
-- INSTANT MENTOR CHAT SYSTEM SETUP
-- =========================================================
-- Run this script in your Supabase SQL Editor to fix the chat functionality
-- This will create the missing chat_threads and chat_messages tables

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- 1. CREATE CHAT TABLES
-- =========================================================

-- Create chat_threads table
CREATE TABLE IF NOT EXISTS public.chat_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL,
    mentor_id UUID NOT NULL,
    subject TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID REFERENCES public.chat_threads(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    sender_name TEXT,
    message_type TEXT DEFAULT 'text',
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- =========================================================

-- Indexes for chat_threads
CREATE INDEX IF NOT EXISTS chat_threads_student_mentor_idx ON public.chat_threads (student_id, mentor_id);
CREATE INDEX IF NOT EXISTS chat_threads_updated_at_idx ON public.chat_threads (updated_at DESC);

-- Indexes for chat_messages
CREATE INDEX IF NOT EXISTS chat_messages_chat_created_idx ON public.chat_messages (chat_id, created_at);
CREATE INDEX IF NOT EXISTS chat_messages_sender_idx ON public.chat_messages (sender_id);
CREATE INDEX IF NOT EXISTS chat_messages_is_read_idx ON public.chat_messages (is_read);

-- =========================================================
-- 3. CREATE HELPER FUNCTIONS
-- =========================================================

-- Function to automatically update thread updated_at when messages are added
CREATE OR REPLACE FUNCTION public.update_thread_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.chat_threads 
    SET updated_at = NOW() 
    WHERE id = NEW.chat_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to get or create a chat thread between student and mentor
CREATE OR REPLACE FUNCTION public.get_or_create_chat_thread(
    p_student_id UUID,
    p_mentor_id UUID,
    p_subject TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    thread_id UUID;
BEGIN
    -- Try to find existing thread
    SELECT id INTO thread_id
    FROM public.chat_threads
    WHERE student_id = p_student_id AND mentor_id = p_mentor_id
    LIMIT 1;
    
    -- If no thread exists, create one
    IF thread_id IS NULL THEN
        INSERT INTO public.chat_threads (student_id, mentor_id, subject)
        VALUES (p_student_id, p_mentor_id, p_subject)
        RETURNING id INTO thread_id;
    END IF;
    
    RETURN thread_id;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 4. CREATE TRIGGERS
-- =========================================================

-- Trigger to auto-update thread timestamp on new messages
DROP TRIGGER IF EXISTS update_thread_on_new_message ON public.chat_messages;
CREATE TRIGGER update_thread_on_new_message
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.update_thread_updated_at();

-- =========================================================
-- 5. ENABLE ROW LEVEL SECURITY (RLS)
-- =========================================================

-- Enable RLS on both tables
ALTER TABLE public.chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- =========================================================
-- 6. CREATE RLS POLICIES
-- =========================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their chat threads" ON public.chat_threads;
DROP POLICY IF EXISTS "Users can create chat threads" ON public.chat_threads;
DROP POLICY IF EXISTS "Users can update their chat threads" ON public.chat_threads;
DROP POLICY IF EXISTS "Users can view messages in their threads" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can send messages in their threads" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can update their messages" ON public.chat_messages;

-- Chat Threads Policies
CREATE POLICY "Users can view their chat threads" ON public.chat_threads
    FOR SELECT
    USING (
        auth.uid() = student_id OR 
        auth.uid() = mentor_id
    );

CREATE POLICY "Users can create chat threads" ON public.chat_threads
    FOR INSERT
    WITH CHECK (
        auth.uid() = student_id OR 
        auth.uid() = mentor_id
    );

CREATE POLICY "Users can update their chat threads" ON public.chat_threads
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
CREATE POLICY "Users can view messages in their threads" ON public.chat_messages
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.chat_threads 
            WHERE id = chat_messages.chat_id 
            AND (student_id = auth.uid() OR mentor_id = auth.uid())
        )
    );

CREATE POLICY "Users can send messages in their threads" ON public.chat_messages
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.chat_threads 
            WHERE id = chat_messages.chat_id 
            AND (student_id = auth.uid() OR mentor_id = auth.uid())
        )
        AND sender_id = auth.uid()
    );

CREATE POLICY "Users can update their messages" ON public.chat_messages
    FOR UPDATE
    USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());

-- =========================================================
-- 7. INSERT SAMPLE DATA (OPTIONAL - FOR TESTING)
-- =========================================================

-- Uncomment the following lines if you want to insert sample chat data for testing
-- Make sure to replace the UUIDs with actual user IDs from your auth.users table

/*
-- Sample chat thread
INSERT INTO public.chat_threads (id, student_id, mentor_id, subject) 
VALUES (
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    '550e8400-e29b-41d4-a716-446655440000', -- Replace with actual student ID
    '550e8400-e29b-41d4-a716-446655440001', -- Replace with actual mentor ID
    'Mathematics Help'
) ON CONFLICT (id) DO NOTHING;

-- Sample messages
INSERT INTO public.chat_messages (chat_id, sender_id, sender_name, content) VALUES
    ('f47ac10b-58cc-4372-a567-0e02b2c3d479', '550e8400-e29b-41d4-a716-446655440000', 'Student', 'Hi, I need help with calculus.'),
    ('f47ac10b-58cc-4372-a567-0e02b2c3d479', '550e8400-e29b-41d4-a716-446655440001', 'Dr. Sarah', 'Hello! I''d be happy to help you with calculus. What specific topic are you struggling with?')
ON CONFLICT (id) DO NOTHING;
*/

-- =========================================================
-- SETUP COMPLETE
-- =========================================================

-- Verify tables were created
SELECT 
    'chat_threads' as table_name,
    COUNT(*) as row_count
FROM public.chat_threads
UNION ALL
SELECT 
    'chat_messages' as table_name,
    COUNT(*) as row_count
FROM public.chat_messages;

-- Show success message
SELECT 'Chat system setup completed successfully!' as status;