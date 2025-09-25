-- COMPREHENSIVE DATABASE FIX
-- This script fixes all missing columns and ensures proper functionality
-- Run this entire script in your Supabase SQL Editor

-- 1. First, let's check and create the preferences column
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'user_profiles' 
                 AND column_name = 'preferences') THEN
    ALTER TABLE user_profiles ADD COLUMN preferences JSONB DEFAULT '{}';
    RAISE NOTICE 'Added preferences column to user_profiles table';
  ELSE
    RAISE NOTICE 'Preferences column already exists';
  END IF;
END $$;

-- 2. Add all missing profile columns
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS grade TEXT,
ADD COLUMN IF NOT EXISTS subjects TEXT[],
ADD COLUMN IF NOT EXISTS exam_target TEXT;

-- 3. Update existing rows to have proper defaults
UPDATE user_profiles 
SET preferences = '{}' 
WHERE preferences IS NULL;

-- 4. Copy phone_number to phone if needed
UPDATE user_profiles 
SET phone = phone_number 
WHERE phone_number IS NOT NULL AND (phone IS NULL OR phone = '');

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_grade 
ON user_profiles (grade);

CREATE INDEX IF NOT EXISTS idx_user_profiles_exam_target 
ON user_profiles (exam_target);

CREATE INDEX IF NOT EXISTS idx_user_profiles_subjects 
ON user_profiles USING GIN (subjects);

CREATE INDEX IF NOT EXISTS idx_user_profiles_preferences 
ON user_profiles USING GIN (preferences);

-- 6. Verify the table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
ORDER BY ordinal_position;

-- 7. Show some sample data to verify
SELECT id, 
       CASE WHEN preferences IS NOT NULL THEN 'HAS_PREFERENCES' ELSE 'NO_PREFERENCES' END as pref_status,
       CASE WHEN phone IS NOT NULL THEN 'HAS_PHONE' ELSE 'NO_PHONE' END as phone_status,
       CASE WHEN grade IS NOT NULL THEN 'HAS_GRADE' ELSE 'NO_GRADE' END as grade_status
FROM user_profiles 
LIMIT 5;

RAISE NOTICE 'Database schema fix completed successfully!';