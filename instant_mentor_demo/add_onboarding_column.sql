-- Add onboarding_completed column to user_profiles table
-- This enables the mentor onboarding flow functionality

-- First, add the column if it doesn't exist
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE;

-- Verify the column was added
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND column_name = 'onboarding_completed';

-- Update existing mentors to have completed onboarding (optional)
-- Uncomment the line below if you want existing mentors to skip onboarding
-- UPDATE user_profiles SET onboarding_completed = TRUE WHERE role = 'mentor';