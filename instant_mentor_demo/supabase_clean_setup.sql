-- InstantMentor Supabase Clean Database Setup Script
-- This script safely handles existing objects and won't throw errors on re-runs

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
  preferences JSONB DEFAULT '{}',
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
  currency TEXT DEFAULT 'INR',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  payment_method TEXT,
  transaction_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create or replace function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create function to validate email domain (only @student.com allowed)
CREATE OR REPLACE FUNCTION validate_student_email()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if email ends with @student.com
    IF NEW.email IS NOT NULL AND NOT NEW.email ILIKE '%@student.com' THEN
        RAISE EXCEPTION 'Only @student.com email addresses are allowed for registration.'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Enable Row Level Security (RLS) on core tables
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

-- Add basic RLS policies (these will recreate if they exist)
DO $$ BEGIN
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
  DROP POLICY IF EXISTS "Anyone can view mentor profiles" ON mentor_profiles;
  CREATE POLICY "Anyone can view mentor profiles" ON mentor_profiles 
    FOR SELECT TO authenticated USING (true);

  DROP POLICY IF EXISTS "Mentors can update own profile" ON mentor_profiles;
  CREATE POLICY "Mentors can update own profile" ON mentor_profiles 
    FOR UPDATE USING (auth.uid() = user_id);

  DROP POLICY IF EXISTS "Users can create mentor profile" ON mentor_profiles;
  CREATE POLICY "Users can create mentor profile" ON mentor_profiles 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Some policies already exist, continuing...';
END $$;

-- Insert default subjects if they don't exist
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
  ('History', 'Humanities', 'World History, Ancient Civilizations', 'history_edu')
ON CONFLICT (name) DO NOTHING;

-- Create basic indexes for performance
CREATE INDEX IF NOT EXISTS idx_mentor_profiles_user_id ON mentor_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_mentoring_sessions_mentor_id ON mentoring_sessions(mentor_id);
CREATE INDEX IF NOT EXISTS idx_mentoring_sessions_student_id ON mentoring_sessions(student_id);
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id, created_at DESC);

-- Safely create triggers
DO $$ BEGIN
  -- Drop existing triggers first
  DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
  DROP TRIGGER IF EXISTS update_mentor_profiles_updated_at ON mentor_profiles;
  DROP TRIGGER IF EXISTS update_student_profiles_updated_at ON student_profiles;
  DROP TRIGGER IF EXISTS update_mentoring_sessions_updated_at ON mentoring_sessions;
  DROP TRIGGER IF EXISTS update_payment_transactions_updated_at ON payment_transactions;
  DROP TRIGGER IF EXISTS validate_email_domain_trigger ON user_profiles;

  -- Create new triggers
  CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_mentor_profiles_updated_at 
    BEFORE UPDATE ON mentor_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_student_profiles_updated_at 
    BEFORE UPDATE ON student_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_mentoring_sessions_updated_at 
    BEFORE UPDATE ON mentoring_sessions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_payment_transactions_updated_at 
    BEFORE UPDATE ON payment_transactions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  -- Create email validation trigger
  CREATE TRIGGER validate_email_domain_trigger
    BEFORE INSERT OR UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION validate_student_email();

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Some triggers already exist, continuing...';
END $$;

-- Success message
SELECT 'InstantMentor database core setup completed successfully!' as status;

-- IMPORTANT: Configure Supabase Auth Settings
-- Run these commands in your Supabase Dashboard > Authentication > Settings

-- 1. Disable Allow new users to sign up (if you want manual approval)
-- 2. Enable Confirm email before sign-in
-- 3. Set up email domain restrictions

-- Create a function to handle email domain validation during auth
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  -- Validate email domain during signup
  IF NEW.email IS NOT NULL AND NOT NEW.email ILIKE '%@student.com' THEN
    RAISE EXCEPTION 'Only @student.com email addresses are allowed for registration.'
      USING ERRCODE = 'check_violation';
  END IF;
  
  -- Create user profile automatically
  INSERT INTO public.user_profiles (id, email, full_name, is_student, is_mentor)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE((NEW.raw_user_meta_data->>'is_student')::boolean, true),
    COALESCE((NEW.raw_user_meta_data->>'is_mentor')::boolean, false)
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add preferences column if it doesn't exist (for existing databases)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'user_profiles' 
                 AND column_name = 'preferences') THEN
    ALTER TABLE user_profiles ADD COLUMN preferences JSONB DEFAULT '{}';
  END IF;
END $$;

-- Create trigger for new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
