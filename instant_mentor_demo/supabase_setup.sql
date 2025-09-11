-- InstantMentor Supabase Database Setup Script
-- Run this script in your Supabase SQL editor to set up the database schema

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  phone_number TEXT,
  date_of_birth DATE,
  bio TEXT,
  location TEXT,
  timezone TEXT,
  preferred_language TEXT DEFAULT 'en',
  is_mentor BOOLEAN DEFAULT false,
  is_student BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Mentor profiles table
CREATE TABLE IF NOT EXISTS mentor_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  title TEXT,
  subjects TEXT[],
  years_experience INTEGER,
  hourly_rate DECIMAL(10,2),
  average_rating DECIMAL(3,2) DEFAULT 0,
  total_sessions INTEGER DEFAULT 0,
  total_students INTEGER DEFAULT 0,
  is_available BOOLEAN DEFAULT true,
  is_verified BOOLEAN DEFAULT false,
  education TEXT[],
  certifications TEXT[],
  languages TEXT[],
  availability_hours JSONB,
  specializations TEXT[],
  teaching_style TEXT,
  introduction_video_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Student profiles table
CREATE TABLE IF NOT EXISTS student_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  education_level TEXT,
  subjects_of_interest TEXT[],
  learning_goals TEXT,
  preferred_learning_style TEXT,
  total_sessions INTEGER DEFAULT 0,
  favorite_mentors UUID[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Mentoring sessions table
CREATE TABLE IF NOT EXISTS mentoring_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  mentor_id UUID REFERENCES mentor_profiles(id) NOT NULL,
  student_id UUID REFERENCES auth.users(id) NOT NULL,
  scheduled_time TIMESTAMP WITH TIME ZONE NOT NULL,
  duration_minutes INTEGER NOT NULL,
  subject TEXT,
  description TEXT,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show')),
  notes TEXT,
  mentor_notes TEXT,
  student_notes TEXT,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  review TEXT,
  recording_url TEXT,
  session_materials JSONB,
  cost DECIMAL(10,2),
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'refunded', 'failed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Messages table for chat functionality
CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES mentoring_sessions(id),
  sender_id UUID REFERENCES auth.users(id) NOT NULL,
  receiver_id UUID REFERENCES auth.users(id) NOT NULL,
  content TEXT NOT NULL,
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'audio', 'video')),
  file_url TEXT,
  file_name TEXT,
  file_size INTEGER,
  is_read BOOLEAN DEFAULT false,
  is_system_message BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT DEFAULT 'info' CHECK (type IN ('info', 'success', 'warning', 'error', 'session', 'payment', 'system')),
  is_read BOOLEAN DEFAULT false,
  action_url TEXT,
  data JSONB,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Reviews and ratings table
CREATE TABLE IF NOT EXISTS reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES mentoring_sessions(id) NOT NULL,
  reviewer_id UUID REFERENCES auth.users(id) NOT NULL,
  reviewed_id UUID REFERENCES auth.users(id) NOT NULL,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text TEXT,
  is_public BOOLEAN DEFAULT true,
  helpful_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Mentor availability table
CREATE TABLE IF NOT EXISTS mentor_availability (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  mentor_id UUID REFERENCES mentor_profiles(id) NOT NULL,
  day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0 = Sunday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  timezone TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Documents and materials table
CREATE TABLE IF NOT EXISTS documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES mentoring_sessions(id),
  uploaded_by UUID REFERENCES auth.users(id) NOT NULL,
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_type TEXT,
  file_size INTEGER,
  description TEXT,
  is_public BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Subjects table for categorization
CREATE TABLE IF NOT EXISTS subjects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  category TEXT,
  description TEXT,
  icon TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Payment transactions table
CREATE TABLE IF NOT EXISTS payment_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES mentoring_sessions(id) NOT NULL,
  payer_id UUID REFERENCES auth.users(id) NOT NULL,
  payee_id UUID REFERENCES auth.users(id) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'USD',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  payment_method TEXT,
  transaction_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updating timestamps (with IF NOT EXISTS handling)
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at 
  BEFORE UPDATE ON user_profiles 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_mentor_profiles_updated_at ON mentor_profiles;
CREATE TRIGGER update_mentor_profiles_updated_at 
  BEFORE UPDATE ON mentor_profiles 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_student_profiles_updated_at ON student_profiles;
CREATE TRIGGER update_student_profiles_updated_at 
  BEFORE UPDATE ON student_profiles 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_mentoring_sessions_updated_at ON mentoring_sessions;
CREATE TRIGGER update_mentoring_sessions_updated_at 
  BEFORE UPDATE ON mentoring_sessions 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_payment_transactions_updated_at ON payment_transactions;
CREATE TRIGGER update_payment_transactions_updated_at 
  BEFORE UPDATE ON payment_transactions 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentoring_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentor_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (with proper error handling)

-- User profiles policies
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
CREATE POLICY "Users can view own profile" ON user_profiles 
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile" ON user_profiles 
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
CREATE POLICY "Users can insert own profile" ON user_profiles 
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Mentor profiles policies
CREATE POLICY "Anyone can view mentor profiles" ON mentor_profiles 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Mentors can update own profile" ON mentor_profiles 
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can create mentor profile" ON mentor_profiles 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Student profiles policies
CREATE POLICY "Users can view own student profile" ON student_profiles 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own student profile" ON student_profiles 
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can create student profile" ON student_profiles 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Session policies
CREATE POLICY "Users can view own sessions" ON mentoring_sessions 
  FOR SELECT USING (
    auth.uid() = student_id OR 
    auth.uid() IN (SELECT user_id FROM mentor_profiles WHERE id = mentor_id)
  );

CREATE POLICY "Students can create sessions" ON mentoring_sessions 
  FOR INSERT WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Participants can update sessions" ON mentoring_sessions 
  FOR UPDATE USING (
    auth.uid() = student_id OR 
    auth.uid() IN (SELECT user_id FROM mentor_profiles WHERE id = mentor_id)
  );

-- Messages policies
CREATE POLICY "Users can view own messages" ON messages 
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send messages" ON messages 
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update own messages" ON messages 
  FOR UPDATE USING (auth.uid() = sender_id);

-- Notifications policies
CREATE POLICY "Users can view own notifications" ON notifications 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications 
  FOR UPDATE USING (auth.uid() = user_id);

-- Reviews policies
CREATE POLICY "Users can view public reviews" ON reviews 
  FOR SELECT USING (is_public = true);

CREATE POLICY "Users can view own reviews" ON reviews 
  FOR SELECT USING (auth.uid() = reviewer_id OR auth.uid() = reviewed_id);

CREATE POLICY "Users can create reviews" ON reviews 
  FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

-- Availability policies
CREATE POLICY "Anyone can view mentor availability" ON mentor_availability 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Mentors can manage own availability" ON mentor_availability 
  FOR ALL USING (
    auth.uid() IN (SELECT user_id FROM mentor_profiles WHERE id = mentor_id)
  );

-- Documents policies
CREATE POLICY "Users can view session documents" ON documents 
  FOR SELECT USING (
    is_public = true OR 
    auth.uid() = uploaded_by OR
    auth.uid() IN (
      SELECT student_id FROM mentoring_sessions WHERE id = session_id
      UNION
      SELECT user_id FROM mentor_profiles mp 
      JOIN mentoring_sessions ms ON mp.id = ms.mentor_id 
      WHERE ms.id = session_id
    )
  );

CREATE POLICY "Users can upload documents" ON documents 
  FOR INSERT WITH CHECK (auth.uid() = uploaded_by);

-- Payment transactions policies
CREATE POLICY "Users can view own transactions" ON payment_transactions 
  FOR SELECT USING (auth.uid() = payer_id OR auth.uid() = payee_id);

-- Insert default subjects
INSERT INTO subjects (name, category, description, icon) VALUES
  ('Mathematics', 'STEM', 'Algebra, Calculus, Geometry, Statistics', 'calculate'),
  ('Physics', 'STEM', 'Mechanics, Thermodynamics, Quantum Physics', 'atom'),
  ('Chemistry', 'STEM', 'Organic, Inorganic, Physical Chemistry', 'science'),
  ('Biology', 'STEM', 'Cell Biology, Genetics, Ecology', 'biotech'),
  ('Computer Science', 'Technology', 'Programming, Algorithms, Data Structures', 'computer'),
  ('Web Development', 'Technology', 'HTML, CSS, JavaScript, Frameworks', 'web'),
  ('Mobile Development', 'Technology', 'iOS, Android, Flutter, React Native', 'phone_iphone'),
  ('Data Science', 'Technology', 'Machine Learning, AI, Statistics', 'analytics'),
  ('English Literature', 'Humanities', 'Poetry, Novels, Literary Analysis', 'book'),
  ('History', 'Humanities', 'World History, Ancient Civilizations', 'history_edu'),
  ('Philosophy', 'Humanities', 'Ethics, Logic, Metaphysics', 'psychology'),
  ('Psychology', 'Social Sciences', 'Cognitive, Social, Developmental', 'psychology'),
  ('Economics', 'Social Sciences', 'Micro, Macro, Behavioral Economics', 'trending_up'),
  ('Business', 'Professional', 'Management, Marketing, Finance', 'business'),
  ('Languages', 'Communication', 'Spanish, French, German, Chinese', 'language'),
  ('Music', 'Arts', 'Theory, Composition, Performance', 'music_note'),
  ('Art', 'Arts', 'Drawing, Painting, Digital Art', 'palette'),
  ('Photography', 'Arts', 'Portrait, Landscape, Digital Photography', 'camera_alt')
ON CONFLICT (name) DO NOTHING;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_mentor_profiles_user_id ON mentor_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_mentor_profiles_subjects ON mentor_profiles USING GIN(subjects);
CREATE INDEX IF NOT EXISTS idx_mentor_profiles_available ON mentor_profiles(is_available, is_verified);
CREATE INDEX IF NOT EXISTS idx_mentoring_sessions_mentor_id ON mentoring_sessions(mentor_id);
CREATE INDEX IF NOT EXISTS idx_mentoring_sessions_student_id ON mentoring_sessions(student_id);
CREATE INDEX IF NOT EXISTS idx_mentoring_sessions_scheduled_time ON mentoring_sessions(scheduled_time);
CREATE INDEX IF NOT EXISTS idx_mentoring_sessions_status ON mentoring_sessions(status);
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_receiver ON messages(sender_id, receiver_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewed_id ON reviews(reviewed_id);
CREATE INDEX IF NOT EXISTS idx_mentor_availability_mentor_id ON mentor_availability(mentor_id);

-- Create a function to calculate mentor average rating
CREATE OR REPLACE FUNCTION calculate_mentor_average_rating(mentor_user_id UUID)
RETURNS DECIMAL AS $$
DECLARE
    avg_rating DECIMAL;
BEGIN
    SELECT AVG(rating)::DECIMAL(3,2) INTO avg_rating
    FROM reviews r
    JOIN mentoring_sessions ms ON r.session_id = ms.id
    JOIN mentor_profiles mp ON ms.mentor_id = mp.id
    WHERE mp.user_id = mentor_user_id AND r.rating IS NOT NULL;
    
    RETURN COALESCE(avg_rating, 0);
END;
$$ LANGUAGE plpgsql;

-- Create a function to update mentor statistics
CREATE OR REPLACE FUNCTION update_mentor_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update mentor profile with latest statistics
    UPDATE mentor_profiles SET
        total_sessions = (
            SELECT COUNT(*) 
            FROM mentoring_sessions 
            WHERE mentor_id = NEW.mentor_id AND status = 'completed'
        ),
        total_students = (
            SELECT COUNT(DISTINCT student_id) 
            FROM mentoring_sessions 
            WHERE mentor_id = NEW.mentor_id AND status = 'completed'
        ),
        average_rating = (
            SELECT AVG(rating)::DECIMAL(3,2)
            FROM reviews r
            JOIN mentoring_sessions ms ON r.session_id = ms.id
            WHERE ms.mentor_id = NEW.mentor_id AND r.rating IS NOT NULL
        )
    WHERE id = NEW.mentor_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update mentor stats when session is completed (with IF NOT EXISTS handling)
DROP TRIGGER IF EXISTS update_mentor_stats_trigger ON mentoring_sessions;
CREATE TRIGGER update_mentor_stats_trigger
    AFTER UPDATE OF status ON mentoring_sessions
    FOR EACH ROW
    WHEN (NEW.status = 'completed')
    EXECUTE FUNCTION update_mentor_stats();

-- Create trigger to update mentor stats when review is added (with IF NOT EXISTS handling)
DROP TRIGGER IF EXISTS update_mentor_stats_on_review ON reviews;
CREATE TRIGGER update_mentor_stats_on_review
    AFTER INSERT ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_mentor_stats();

-- ========================================
-- PRIORITY 2 TABLES FOR ADVANCED FEATURES
-- ========================================

-- Content Management Tables

-- Learning modules table
CREATE TABLE IF NOT EXISTS learning_modules (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  description TEXT,
  difficulty TEXT CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  creator_id UUID REFERENCES auth.users(id) NOT NULL,
  topics TEXT[],
  prerequisites TEXT[],
  estimated_duration INTEGER DEFAULT 60, -- minutes
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  is_public BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Module content table
CREATE TABLE IF NOT EXISTS module_content (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  module_id UUID REFERENCES learning_modules(id) ON DELETE CASCADE NOT NULL,
  content_type TEXT NOT NULL CHECK (content_type IN ('text', 'video', 'quiz', 'exercise', 'resource')),
  title TEXT NOT NULL,
  content JSONB NOT NULL,
  order_index INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Module progress tracking
CREATE TABLE IF NOT EXISTS module_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  module_id UUID REFERENCES learning_modules(id) ON DELETE CASCADE NOT NULL,
  student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  progress_percentage DECIMAL(5,2) DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  completed_sections TEXT[],
  started_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(module_id, student_id)
);

-- Quizzes table
CREATE TABLE IF NOT EXISTS quizzes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  difficulty TEXT CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  creator_id UUID REFERENCES auth.users(id) NOT NULL,
  time_limit INTEGER DEFAULT 0, -- 0 = no time limit
  passing_score INTEGER DEFAULT 70,
  total_questions INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active' CHECK (status IN ('draft', 'active', 'archived')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Quiz questions table
CREATE TABLE IF NOT EXISTS quiz_questions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  quiz_id UUID REFERENCES quizzes(id) ON DELETE CASCADE NOT NULL,
  question_text TEXT NOT NULL,
  question_type TEXT NOT NULL CHECK (question_type IN ('multipleChoice', 'trueFalse', 'shortAnswer', 'essay', 'fillInBlank')),
  options TEXT[],
  correct_answer TEXT NOT NULL,
  explanation TEXT,
  points INTEGER DEFAULT 1,
  order_index INTEGER DEFAULT 0
);

-- Quiz attempts table
CREATE TABLE IF NOT EXISTS quiz_attempts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  quiz_id UUID REFERENCES quizzes(id) ON DELETE CASCADE NOT NULL,
  student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  answers JSONB NOT NULL,
  score INTEGER NOT NULL,
  total_questions INTEGER NOT NULL,
  correct_answers INTEGER NOT NULL,
  time_spent INTEGER DEFAULT 0, -- seconds
  passed BOOLEAN DEFAULT false,
  completed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Assignments table
CREATE TABLE IF NOT EXISTS assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  mentor_id UUID REFERENCES auth.users(id) NOT NULL,
  due_date TIMESTAMP WITH TIME ZONE NOT NULL,
  assignment_type TEXT NOT NULL CHECK (assignment_type IN ('essay', 'project', 'presentation', 'research', 'programming', 'creative')),
  requirements JSONB,
  max_points INTEGER DEFAULT 100,
  status TEXT DEFAULT 'active' CHECK (status IN ('draft', 'active', 'closed', 'archived')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Assignment submissions table
CREATE TABLE IF NOT EXISTS assignment_submissions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  assignment_id UUID REFERENCES assignments(id) ON DELETE CASCADE NOT NULL,
  student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  submission_content JSONB NOT NULL,
  attachments TEXT[],
  submitted_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  score INTEGER,
  feedback TEXT,
  detailed_feedback JSONB,
  graded_by UUID REFERENCES auth.users(id),
  graded_at TIMESTAMP WITH TIME ZONE,
  status TEXT DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted', 'graded', 'returned')),
  UNIQUE(assignment_id, student_id)
);

-- Resources table
CREATE TABLE IF NOT EXISTS resources (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  resource_type TEXT NOT NULL CHECK (resource_type IN ('document', 'video', 'link', 'image', 'audio')),
  url TEXT NOT NULL,
  description TEXT,
  creator_id UUID REFERENCES auth.users(id) NOT NULL,
  tags TEXT[],
  difficulty TEXT CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  is_public BOOLEAN DEFAULT true,
  downloads INTEGER DEFAULT 0,
  views INTEGER DEFAULT 0,
  rating DECIMAL(3,2) DEFAULT 0,
  rating_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Advanced Messaging Tables

-- Chat channels table
CREATE TABLE IF NOT EXISTS chat_channels (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  channel_type TEXT NOT NULL CHECK (channel_type IN ('direct', 'group', 'study_group', 'public')),
  creator_id UUID REFERENCES auth.users(id) NOT NULL,
  is_private BOOLEAN DEFAULT false,
  max_members INTEGER DEFAULT 0, -- 0 = unlimited
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Channel members table
CREATE TABLE IF NOT EXISTS channel_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  channel_id UUID REFERENCES chat_channels(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'moderator', 'member')),
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(channel_id, user_id)
);

-- Study groups table
CREATE TABLE IF NOT EXISTS study_groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  subject TEXT NOT NULL,
  description TEXT,
  creator_id UUID REFERENCES auth.users(id) NOT NULL,
  max_members INTEGER DEFAULT 10,
  current_members INTEGER DEFAULT 1,
  is_public BOOLEAN DEFAULT true,
  meeting_schedule JSONB,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Study group members table
CREATE TABLE IF NOT EXISTS study_group_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  study_group_id UUID REFERENCES study_groups(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(study_group_id, user_id)
);

-- Study sessions table
CREATE TABLE IF NOT EXISTS study_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  study_group_id UUID REFERENCES study_groups(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  scheduled_time TIMESTAMP WITH TIME ZONE NOT NULL,
  duration_minutes INTEGER DEFAULT 60,
  location TEXT,
  meeting_url TEXT,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
  notes TEXT,
  attendees UUID[],
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Collaborative workspaces table
CREATE TABLE IF NOT EXISTS collaborative_workspaces (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  workspace_type TEXT DEFAULT 'project' CHECK (workspace_type IN ('project', 'study', 'research')),
  creator_id UUID REFERENCES auth.users(id) NOT NULL,
  is_public BOOLEAN DEFAULT false,
  settings JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Shared documents table
CREATE TABLE IF NOT EXISTS shared_documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  workspace_id UUID REFERENCES collaborative_workspaces(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content JSONB NOT NULL,
  document_type TEXT DEFAULT 'text' CHECK (document_type IN ('text', 'presentation', 'spreadsheet', 'whiteboard')),
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  last_edited_by UUID REFERENCES auth.users(id),
  version INTEGER DEFAULT 1,
  is_locked BOOLEAN DEFAULT false,
  locked_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Gamification Tables

-- User gamification stats table
CREATE TABLE IF NOT EXISTS user_gamification_stats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  total_points INTEGER DEFAULT 0,
  level INTEGER DEFAULT 1,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  achievements_count INTEGER DEFAULT 0,
  challenges_completed INTEGER DEFAULT 0,
  last_activity_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Points transactions table
CREATE TABLE IF NOT EXISTS points_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  points INTEGER NOT NULL,
  reason TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('activity', 'achievement', 'challenge', 'levelUp', 'bonus', 'social')),
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Achievements table
CREATE TABLE IF NOT EXISTS achievements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  icon TEXT,
  points INTEGER DEFAULT 0,
  criteria JSONB NOT NULL,
  is_active BOOLEAN DEFAULT true,
  rarity TEXT DEFAULT 'common' CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- User achievements table
CREATE TABLE IF NOT EXISTS user_achievements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  achievement_id UUID REFERENCES achievements(id) ON DELETE CASCADE NOT NULL,
  unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  metadata JSONB,
  UNIQUE(user_id, achievement_id)
);

-- Challenges table
CREATE TABLE IF NOT EXISTS challenges (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  creator_id UUID REFERENCES auth.users(id) NOT NULL,
  challenge_type TEXT NOT NULL CHECK (challenge_type IN ('individual', 'team', 'global', 'timeLimit', 'milestone')),
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  requirements JSONB NOT NULL,
  rewards JSONB NOT NULL,
  max_participants INTEGER DEFAULT 0, -- 0 = unlimited
  current_participants INTEGER DEFAULT 0,
  tags TEXT[],
  status TEXT DEFAULT 'active' CHECK (status IN ('draft', 'active', 'completed', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Challenge participants table
CREATE TABLE IF NOT EXISTS challenge_participants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  progress DECIMAL(5,2) DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'dropped')),
  data JSONB,
  UNIQUE(challenge_id, user_id)
);

-- Learning activities table
CREATE TABLE IF NOT EXISTS learning_activities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  activity_type TEXT NOT NULL CHECK (activity_type IN ('sessionCompleted', 'quizCompleted', 'assignmentSubmitted', 'moduleCompleted', 'dailyLogin', 'messagesSent', 'studyGroupParticipation', 'videoCallAttended')),
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  duration INTEGER DEFAULT 0, -- minutes
  metadata JSONB
);

-- Rewards table
CREATE TABLE IF NOT EXISTS rewards (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('badge', 'coupon', 'feature', 'merchandise')),
  points_cost INTEGER NOT NULL,
  level_required INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  inventory INTEGER DEFAULT -1, -- -1 = unlimited
  image_url TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Reward redemptions table
CREATE TABLE IF NOT EXISTS reward_redemptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  reward_id UUID REFERENCES rewards(id) ON DELETE CASCADE NOT NULL,
  points_spent INTEGER NOT NULL,
  redeemed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'delivered', 'cancelled')),
  delivery_info JSONB
);

-- ========================================
-- TRIGGERS FOR NEW TABLES
-- ========================================

-- Add triggers for updated_at columns (with IF NOT EXISTS handling)
DROP TRIGGER IF EXISTS update_learning_modules_updated_at ON learning_modules;
CREATE TRIGGER update_learning_modules_updated_at 
  BEFORE UPDATE ON learning_modules 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_module_progress_updated_at ON module_progress;
CREATE TRIGGER update_module_progress_updated_at 
  BEFORE UPDATE ON module_progress 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_shared_documents_updated_at ON shared_documents;
CREATE TRIGGER update_shared_documents_updated_at 
  BEFORE UPDATE ON shared_documents 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_gamification_stats_updated_at ON user_gamification_stats;
CREATE TRIGGER update_user_gamification_stats_updated_at 
  BEFORE UPDATE ON user_gamification_stats 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- ROW LEVEL SECURITY FOR NEW TABLES
-- ========================================

-- Enable RLS on new tables
ALTER TABLE learning_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE module_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE module_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignment_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE collaborative_workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_gamification_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE points_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;

-- ========================================
-- RLS POLICIES FOR NEW TABLES
-- ========================================

-- Learning modules policies
CREATE POLICY "Anyone can view public modules" ON learning_modules 
  FOR SELECT TO authenticated USING (is_public = true);

CREATE POLICY "Users can view own modules" ON learning_modules 
  FOR SELECT USING (auth.uid() = creator_id);

CREATE POLICY "Users can create modules" ON learning_modules 
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Users can update own modules" ON learning_modules 
  FOR UPDATE USING (auth.uid() = creator_id);

-- Module content policies
CREATE POLICY "Users can view module content" ON module_content 
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM learning_modules 
      WHERE id = module_id AND (is_public = true OR creator_id = auth.uid())
    )
  );

CREATE POLICY "Module creators can manage content" ON module_content 
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM learning_modules 
      WHERE id = module_id AND creator_id = auth.uid()
    )
  );

-- Module progress policies
CREATE POLICY "Users can view own progress" ON module_progress 
  FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY "Users can update own progress" ON module_progress 
  FOR ALL USING (auth.uid() = student_id);

-- Quiz policies
CREATE POLICY "Anyone can view active quizzes" ON quizzes 
  FOR SELECT TO authenticated USING (status = 'active');

CREATE POLICY "Users can create quizzes" ON quizzes 
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Users can update own quizzes" ON quizzes 
  FOR UPDATE USING (auth.uid() = creator_id);

-- Quiz questions policies
CREATE POLICY "Users can view quiz questions" ON quiz_questions 
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM quizzes 
      WHERE id = quiz_id AND status = 'active'
    )
  );

CREATE POLICY "Quiz creators can manage questions" ON quiz_questions 
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM quizzes 
      WHERE id = quiz_id AND creator_id = auth.uid()
    )
  );

-- Quiz attempts policies
CREATE POLICY "Users can view own attempts" ON quiz_attempts 
  FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY "Users can create attempts" ON quiz_attempts 
  FOR INSERT WITH CHECK (auth.uid() = student_id);

-- Assignment policies
CREATE POLICY "Students can view assignments" ON assignments 
  FOR SELECT TO authenticated USING (status = 'active');

CREATE POLICY "Mentors can create assignments" ON assignments 
  FOR INSERT WITH CHECK (auth.uid() = mentor_id);

CREATE POLICY "Mentors can update own assignments" ON assignments 
  FOR UPDATE USING (auth.uid() = mentor_id);

-- Assignment submission policies
CREATE POLICY "Users can view own submissions" ON assignment_submissions 
  FOR SELECT USING (auth.uid() = student_id OR auth.uid() IN (
    SELECT mentor_id FROM assignments WHERE id = assignment_id
  ));

CREATE POLICY "Students can create submissions" ON assignment_submissions 
  FOR INSERT WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Students can update own submissions" ON assignment_submissions 
  FOR UPDATE USING (auth.uid() = student_id);

-- Resources policies
CREATE POLICY "Anyone can view public resources" ON resources 
  FOR SELECT TO authenticated USING (is_public = true);

CREATE POLICY "Users can view own resources" ON resources 
  FOR SELECT USING (auth.uid() = creator_id);

CREATE POLICY "Users can create resources" ON resources 
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Users can update own resources" ON resources 
  FOR UPDATE USING (auth.uid() = creator_id);

-- Chat channels policies
CREATE POLICY "Users can view channels they're members of" ON chat_channels 
  FOR SELECT USING (
    auth.uid() = creator_id OR 
    auth.uid() IN (
      SELECT user_id FROM channel_members WHERE channel_id = id
    )
  );

CREATE POLICY "Users can create channels" ON chat_channels 
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Channel creators can update channels" ON chat_channels 
  FOR UPDATE USING (auth.uid() = creator_id);

-- Channel members policies
CREATE POLICY "Users can view channel members" ON channel_members 
  FOR SELECT USING (
    auth.uid() = user_id OR 
    auth.uid() IN (
      SELECT user_id FROM channel_members WHERE channel_id = channel_members.channel_id
    )
  );

CREATE POLICY "Channel admins can manage members" ON channel_members 
  FOR ALL USING (
    auth.uid() IN (
      SELECT cc.creator_id FROM chat_channels cc WHERE cc.id = channel_id
    ) OR
    auth.uid() IN (
      SELECT cm.user_id FROM channel_members cm 
      WHERE cm.channel_id = channel_members.channel_id AND cm.role = 'admin'
    )
  );

-- Study groups policies
CREATE POLICY "Anyone can view public study groups" ON study_groups 
  FOR SELECT TO authenticated USING (is_public = true);

CREATE POLICY "Users can view groups they're members of" ON study_groups 
  FOR SELECT USING (
    auth.uid() = creator_id OR 
    auth.uid() IN (
      SELECT user_id FROM study_group_members WHERE study_group_id = id
    )
  );

CREATE POLICY "Users can create study groups" ON study_groups 
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Group creators can update groups" ON study_groups 
  FOR UPDATE USING (auth.uid() = creator_id);

-- Study group members policies
CREATE POLICY "Users can view group members" ON study_group_members 
  FOR SELECT USING (
    auth.uid() = user_id OR 
    auth.uid() IN (
      SELECT user_id FROM study_group_members WHERE study_group_id = study_group_members.study_group_id
    )
  );

CREATE POLICY "Group admins can manage members" ON study_group_members 
  FOR ALL USING (
    auth.uid() IN (
      SELECT sg.creator_id FROM study_groups sg WHERE sg.id = study_group_id
    ) OR
    auth.uid() IN (
      SELECT sgm.user_id FROM study_group_members sgm 
      WHERE sgm.study_group_id = study_group_members.study_group_id AND sgm.role = 'admin'
    )
  );

-- Study sessions policies
CREATE POLICY "Group members can view sessions" ON study_sessions 
  FOR SELECT USING (
    auth.uid() = created_by OR 
    auth.uid() IN (
      SELECT user_id FROM study_group_members WHERE study_group_id = study_sessions.study_group_id
    )
  );

CREATE POLICY "Group members can create sessions" ON study_sessions 
  FOR INSERT WITH CHECK (
    auth.uid() = created_by AND
    auth.uid() IN (
      SELECT user_id FROM study_group_members WHERE study_group_id = study_sessions.study_group_id
    )
  );

-- Collaborative workspaces policies
CREATE POLICY "Users can view own workspaces" ON collaborative_workspaces 
  FOR SELECT USING (auth.uid() = creator_id);

CREATE POLICY "Users can create workspaces" ON collaborative_workspaces 
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Users can update own workspaces" ON collaborative_workspaces 
  FOR UPDATE USING (auth.uid() = creator_id);

-- Shared documents policies
CREATE POLICY "Workspace creators can view documents" ON shared_documents 
  FOR SELECT USING (
    auth.uid() = created_by OR 
    auth.uid() IN (
      SELECT creator_id FROM collaborative_workspaces WHERE id = workspace_id
    )
  );

CREATE POLICY "Users can create documents" ON shared_documents 
  FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Document creators can update documents" ON shared_documents 
  FOR UPDATE USING (auth.uid() = created_by);

-- Gamification policies
CREATE POLICY "Users can view own stats" ON user_gamification_stats 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own stats" ON user_gamification_stats 
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own points" ON points_transactions 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view achievements" ON achievements 
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "Users can view own achievements" ON user_achievements 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can unlock achievements" ON user_achievements 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Anyone can view active challenges" ON challenges 
  FOR SELECT TO authenticated USING (status = 'active');

CREATE POLICY "Users can create challenges" ON challenges 
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Users can view challenge participation" ON challenge_participants 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can join challenges" ON challenge_participants 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own participation" ON challenge_participants 
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own activities" ON learning_activities 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can record activities" ON learning_activities 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Anyone can view rewards" ON rewards 
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "Users can view own redemptions" ON reward_redemptions 
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can redeem rewards" ON reward_redemptions 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ========================================
-- INDEXES FOR PERFORMANCE
-- ========================================

-- Content Management indexes
CREATE INDEX IF NOT EXISTS idx_learning_modules_creator ON learning_modules(creator_id);
CREATE INDEX IF NOT EXISTS idx_learning_modules_subject ON learning_modules(subject);
CREATE INDEX IF NOT EXISTS idx_learning_modules_public ON learning_modules(is_public, status);
CREATE INDEX IF NOT EXISTS idx_module_content_module ON module_content(module_id, order_index);
CREATE INDEX IF NOT EXISTS idx_module_progress_student ON module_progress(student_id);
CREATE INDEX IF NOT EXISTS idx_module_progress_module ON module_progress(module_id);
CREATE INDEX IF NOT EXISTS idx_quizzes_creator ON quizzes(creator_id);
CREATE INDEX IF NOT EXISTS idx_quizzes_subject ON quizzes(subject, status);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz ON quiz_questions(quiz_id, order_index);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_student ON quiz_attempts(student_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_quiz ON quiz_attempts(quiz_id);
CREATE INDEX IF NOT EXISTS idx_assignments_mentor ON assignments(mentor_id);
CREATE INDEX IF NOT EXISTS idx_assignments_subject ON assignments(subject, status);
CREATE INDEX IF NOT EXISTS idx_assignment_submissions_student ON assignment_submissions(student_id);
CREATE INDEX IF NOT EXISTS idx_assignment_submissions_assignment ON assignment_submissions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_resources_creator ON resources(creator_id);
CREATE INDEX IF NOT EXISTS idx_resources_subject ON resources(subject, is_public);
CREATE INDEX IF NOT EXISTS idx_resources_tags ON resources USING GIN(tags);

-- Messaging indexes
CREATE INDEX IF NOT EXISTS idx_chat_channels_creator ON chat_channels(creator_id);
CREATE INDEX IF NOT EXISTS idx_channel_members_channel ON channel_members(channel_id);
CREATE INDEX IF NOT EXISTS idx_channel_members_user ON channel_members(user_id);
CREATE INDEX IF NOT EXISTS idx_study_groups_creator ON study_groups(creator_id);
CREATE INDEX IF NOT EXISTS idx_study_groups_subject ON study_groups(subject, is_public);
CREATE INDEX IF NOT EXISTS idx_study_group_members_group ON study_group_members(study_group_id);
CREATE INDEX IF NOT EXISTS idx_study_group_members_user ON study_group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_study_sessions_group ON study_sessions(study_group_id);
CREATE INDEX IF NOT EXISTS idx_study_sessions_time ON study_sessions(scheduled_time);
CREATE INDEX IF NOT EXISTS idx_collaborative_workspaces_creator ON collaborative_workspaces(creator_id);
CREATE INDEX IF NOT EXISTS idx_shared_documents_workspace ON shared_documents(workspace_id);
CREATE INDEX IF NOT EXISTS idx_shared_documents_creator ON shared_documents(created_by);

-- Gamification indexes
CREATE INDEX IF NOT EXISTS idx_user_gamification_stats_user ON user_gamification_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_user_gamification_stats_points ON user_gamification_stats(total_points DESC);
CREATE INDEX IF NOT EXISTS idx_user_gamification_stats_level ON user_gamification_stats(level DESC);
CREATE INDEX IF NOT EXISTS idx_points_transactions_user ON points_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement ON user_achievements(achievement_id);
CREATE INDEX IF NOT EXISTS idx_challenges_dates ON challenges(start_date, end_date, status);
CREATE INDEX IF NOT EXISTS idx_challenge_participants_challenge ON challenge_participants(challenge_id);
CREATE INDEX IF NOT EXISTS idx_challenge_participants_user ON challenge_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_learning_activities_user ON learning_activities(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_learning_activities_type ON learning_activities(activity_type, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_reward_redemptions_user ON reward_redemptions(user_id, redeemed_at DESC);

-- ========================================
-- DEFAULT DATA FOR GAMIFICATION
-- ========================================

-- Insert default achievements
INSERT INTO achievements (name, description, icon, points, criteria, rarity) VALUES
  ('First Steps', 'Complete your first mentoring session', '🎯', 50, '{"total_sessions": 1}', 'common'),
  ('Dedicated Learner', 'Complete 10 mentoring sessions', '📚', 200, '{"total_sessions": 10}', 'common'),
  ('Session Master', 'Complete 50 mentoring sessions', '🏆', 500, '{"total_sessions": 50}', 'rare'),
  ('Quiz Whiz', 'Complete 5 quizzes with 80%+ score', '🧠', 150, '{"quiz_completions": 5, "min_score": 80}', 'common'),
  ('Streak Champion', 'Maintain a 7-day learning streak', '🔥', 300, '{"streak_days": 7}', 'rare'),
  ('Social Butterfly', 'Join 3 study groups', '👥', 100, '{"study_groups_joined": 3}', 'common'),
  ('Level Up!', 'Reach level 5', '⭐', 250, '{"level": 5}', 'common'),
  ('High Achiever', 'Reach level 10', '🌟', 500, '{"level": 10}', 'rare'),
  ('Point Collector', 'Earn 1000 total points', '💎', 100, '{"total_points": 1000}', 'common'),
  ('Elite Learner', 'Earn 5000 total points', '👑', 1000, '{"total_points": 5000}', 'epic')
ON CONFLICT (name) DO NOTHING;

-- Insert default rewards
INSERT INTO rewards (name, description, type, points_cost, level_required, image_url) VALUES
  ('Profile Badge: Star Student', 'Display a star badge on your profile', 'badge', 100, 1, null),
  ('Profile Badge: Dedicated Learner', 'Show your commitment with this badge', 'badge', 250, 3, null),
  ('15% Discount Coupon', 'Get 15% off your next session', 'coupon', 300, 2, null),
  ('25% Discount Coupon', 'Get 25% off your next session', 'coupon', 500, 5, null),
  ('Priority Support', 'Get priority customer support for 30 days', 'feature', 400, 3, null),
  ('Custom Profile Theme', 'Unlock custom profile themes', 'feature', 600, 4, null),
  ('InstantMentor T-Shirt', 'Official InstantMentor branded t-shirt', 'merchandise', 1000, 5, null),
  ('Video Call Background', 'Exclusive branded video call backgrounds', 'feature', 200, 2, null)
ON CONFLICT (name) DO NOTHING;
