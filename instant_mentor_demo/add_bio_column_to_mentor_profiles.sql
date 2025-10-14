-- Add bio column to mentor_profiles table
-- This migration adds the bio column that's needed for the mentor onboarding flow

-- Add bio column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'mentor_profiles' 
                 AND column_name = 'bio') THEN
    ALTER TABLE mentor_profiles ADD COLUMN bio TEXT;
    RAISE NOTICE 'Added bio column to mentor_profiles table';
  ELSE
    RAISE NOTICE 'Bio column already exists in mentor_profiles table';
  END IF;
END $$;

-- Update existing rows to have empty bio if null
UPDATE mentor_profiles 
SET bio = '' 
WHERE bio IS NULL;

-- Verify the column was added
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'mentor_profiles' 
AND column_name = 'bio';

-- Add comment explaining the column
COMMENT ON COLUMN mentor_profiles.bio IS 'Mentor biography/description text';