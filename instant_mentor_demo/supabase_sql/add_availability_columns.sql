-- Add availability columns to mentor_profiles table
-- This allows persistent storage of mentor availability settings

-- Add is_available column (default: true - available)
ALTER TABLE mentor_profiles 
ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;

-- Add weekly_schedule column (stores the weekly availability schedule)
ALTER TABLE mentor_profiles 
ADD COLUMN IF NOT EXISTS weekly_schedule JSONB DEFAULT '{
  "Monday": true,
  "Tuesday": true,
  "Wednesday": true,
  "Thursday": true,
  "Friday": true,
  "Saturday": true,
  "Sunday": false
}'::jsonb;

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_mentor_profiles_is_available 
ON mentor_profiles(is_available);

-- Add comment for documentation
COMMENT ON COLUMN mentor_profiles.is_available IS 'Current availability status of the mentor';
COMMENT ON COLUMN mentor_profiles.weekly_schedule IS 'Weekly availability schedule as JSON object with day names as keys and boolean values';

-- Update existing records to have default values if NULL
UPDATE mentor_profiles 
SET is_available = true 
WHERE is_available IS NULL;

UPDATE mentor_profiles 
SET weekly_schedule = '{
  "Monday": true,
  "Tuesday": true,
  "Wednesday": true,
  "Thursday": true,
  "Friday": true,
  "Saturday": true,
  "Sunday": false
}'::jsonb
WHERE weekly_schedule IS NULL;

-- Verify the changes
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'mentor_profiles' 
AND column_name IN ('is_available', 'weekly_schedule');
