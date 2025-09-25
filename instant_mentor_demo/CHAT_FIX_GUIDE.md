# 🔧 Fix Chat Functionality - "Send Message" Error

## Problem
When clicking "Send Message" on mentor profiles, you get this error:
```
Failed to start chat: PostgrestException(message: {"code":"PGRST205","details":null,"hint":null,"message":"Could not find the table 'public.chat_threads' in the schema cache"}, code: 404, details: , hint: null)
```

## Root Cause
The chat system database tables (`chat_threads` and `chat_messages`) haven't been created in your Supabase database yet.

## 🚀 Quick Fix Solution

### Step 1: Access Supabase Dashboard
1. Go to [supabase.com](https://supabase.com) and log into your project
2. Navigate to your InstantMentor project dashboard
3. Click on "SQL Editor" in the left sidebar

### Step 2: Run the Setup Script
1. Copy the entire contents of `SUPABASE_CHAT_SETUP.sql` (created above)
2. Paste it into the Supabase SQL Editor
3. Click "Run" to execute the script

### Step 3: Verify Setup
After running the script, you should see:
- ✅ `chat_threads` table created
- ✅ `chat_messages` table created  
- ✅ Indexes and triggers set up
- ✅ Row Level Security policies configured
- ✅ Success message: "Chat system setup completed successfully!"

### Step 4: Test the Fix
1. Go back to your Flutter app (refresh if needed)
2. Navigate to any mentor profile
3. Click "Send Message" 
4. The chat interface should now open without errors

## 📝 What the Script Does

### Creates Tables:
- **`chat_threads`**: Stores conversations between students and mentors
- **`chat_messages`**: Stores individual messages within threads

### Sets Up Security:
- **Row Level Security (RLS)**: Ensures users can only see their own conversations
- **Policies**: Controls who can read/write messages and threads

### Adds Performance Features:
- **Indexes**: Fast lookups for messages and threads
- **Triggers**: Auto-updates thread timestamps when new messages arrive
- **Helper Functions**: Easy creation of chat threads

### Database Schema:
```sql
chat_threads:
- id (UUID, Primary Key)
- student_id (UUID)
- mentor_id (UUID) 
- subject (TEXT)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

chat_messages:
- id (UUID, Primary Key)
- chat_id (UUID, Foreign Key)
- sender_id (UUID)
- sender_name (TEXT)
- message_type (TEXT)
- content (TEXT)
- is_read (BOOLEAN)
- created_at (TIMESTAMP)
```

## 🔍 Alternative: Check Existing Tables

If you want to verify what tables already exist in your database:

```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('chat_threads', 'chat_messages');
```

## 🎯 Expected Result

After running the setup script:
1. ✅ "Send Message" button works
2. ✅ Chat interface opens
3. ✅ Messages can be sent and received
4. ✅ No more PostgrestException errors

## 📞 If You Still Have Issues

1. **Check Supabase URL/Key**: Ensure your `.env` file has correct Supabase credentials
2. **Check Authentication**: Make sure you're logged in to the app
3. **Check Network**: Ensure your app can connect to Supabase
4. **Check Console**: Look for any additional error messages in browser developer tools

The chat functionality should work perfectly after running this setup script!