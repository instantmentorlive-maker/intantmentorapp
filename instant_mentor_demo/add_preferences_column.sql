-- Migration: Add preferences column to user_profiles table
-- Run this in your Supabase SQL editor

-- Add preferences column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'user_profiles' 
                 AND column_name = 'preferences') THEN
    ALTER TABLE user_profiles ADD COLUMN preferences JSONB DEFAULT '{}';
    RAISE NOTICE 'Added preferences column to user_profiles table';
  ELSE
    RAISE NOTICE 'Preferences column already exists in user_profiles table';
  END IF;
END $$;

-- Update existing rows to have empty preferences if null
UPDATE user_profiles 
SET preferences = '{}' 
WHERE preferences IS NULL;

-- Verify the column was added
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name = 'preferences';