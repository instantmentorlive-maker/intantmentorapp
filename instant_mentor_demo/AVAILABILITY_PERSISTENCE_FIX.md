# Availability Settings Persistence Fix

## Problem
Availability settings were not being saved to the database, causing them to reset after logout/login.

## Solution Implemented

### 1. Database Schema Changes
Added two new columns to `mentor_profiles` table:
- `is_available` (BOOLEAN) - Stores current availability status
- `weekly_schedule` (JSONB) - Stores weekly availability schedule

### 2. Code Changes
Updated `availability_screen.dart`:
- Added database persistence using Supabase
- Added `_loadSavedSettings()` to load settings on screen init
- Updated `_saveAvailabilitySettings()` to save to database
- Settings now persist across logout/login sessions

### 3. Migration Instructions

#### Run SQL Migration:
1. Open Supabase Dashboard (https://app.supabase.com)
2. Select your project
3. Go to SQL Editor
4. Run the SQL file: `supabase_sql/add_availability_columns.sql`

OR run directly:
```sql
-- Add columns
ALTER TABLE mentor_profiles 
ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;

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

-- Add index
CREATE INDEX IF NOT EXISTS idx_mentor_profiles_is_available 
ON mentor_profiles(is_available);
```

## Testing

### Test Steps:
1. Run the SQL migration in Supabase
2. Restart your Flutter app
3. Login as a mentor
4. Go to Availability screen
5. Change some availability settings
6. Click "Save Availability Settings"
7. Verify success message appears
8. Logout
9. Login again
10. Go to Availability screen
11. ✅ Verify your settings are still there!

## Data Flow

### Save Flow:
```
User changes settings
    ↓
Click "Save Availability Settings"
    ↓
1. Save to Supabase database (PERSISTENT)
    ↓
2. Update local state provider
    ↓
3. Sync via WebSocket (real-time)
    ↓
Show success message
```

### Load Flow:
```
User opens Availability screen
    ↓
Load from Supabase database
    ↓
Update UI with saved settings
    ↓
Sync with mentor status provider
```

## Files Modified

1. **lib/features/mentor/availability/availability_screen.dart**
   - Added Supabase imports
   - Added `_loadSavedSettings()` method
   - Updated `_saveAvailabilitySettings()` to persist to database
   - Added proper error handling

2. **supabase_sql/add_availability_columns.sql**
   - New SQL migration file
   - Adds required database columns
   - Includes default values and indexes

## Benefits

✅ **Persistent Storage**: Settings saved in database
✅ **Auto-Load**: Settings load automatically on screen open
✅ **Real-Time Sync**: WebSocket updates for connected clients
✅ **Backward Compatible**: Existing data remains intact
✅ **Error Handling**: Graceful fallback on errors
✅ **Performance**: Indexed column for fast queries

## Troubleshooting

### Settings still not saving?
1. Verify SQL migration ran successfully
2. Check console logs for error messages
3. Verify user is authenticated
4. Check Supabase table permissions

### Console Logs to Look For:
- `✅ Availability settings saved to database`
- `✅ Availability settings synced via WebSocket`
- `⚠️ Error loading saved settings: [error]`

## Database Structure

```sql
mentor_profiles:
  - user_id (UUID, FK)
  - is_available (BOOLEAN) -- NEW
  - weekly_schedule (JSONB) -- NEW
  - updated_at (TIMESTAMP)
  - ... other columns
```

## Default Schedule
```json
{
  "Monday": true,
  "Tuesday": true,
  "Wednesday": true,
  "Thursday": true,
  "Friday": true,
  "Saturday": true,
  "Sunday": false
}
```
