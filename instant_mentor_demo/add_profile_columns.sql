-- Add missing profile columns to user_profiles table
-- This migration adds columns needed for the profile save functionality

-- Add missing columns to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS grade TEXT,
ADD COLUMN IF NOT EXISTS subjects TEXT[],
ADD COLUMN IF NOT EXISTS exam_target TEXT;

-- Update any existing phone_number data to phone column
UPDATE user_profiles 
SET phone = phone_number 
WHERE phone_number IS NOT NULL AND phone IS NULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_grade 
ON user_profiles (grade);

CREATE INDEX IF NOT EXISTS idx_user_profiles_exam_target 
ON user_profiles (exam_target);

CREATE INDEX IF NOT EXISTS idx_user_profiles_subjects 
ON user_profiles USING GIN (subjects);

-- Comment explaining the columns
COMMENT ON COLUMN user_profiles.phone IS 'User phone number (new format)';
COMMENT ON COLUMN user_profiles.grade IS 'Student grade level (e.g., 12th Grade)';
COMMENT ON COLUMN user_profiles.subjects IS 'Array of subjects the user is interested in';
COMMENT ON COLUMN user_profiles.exam_target IS 'Target exam (e.g., JEE, NEET, etc.)';