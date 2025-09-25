# Profile Photo in Video Call - Fix Documentation

## Problem Description
The user's profile photo was not showing in video calls even though the photo upload functionality was working correctly.

## Root Cause Analysis
The issue was that the video call widget (`video_call_widget.dart`) was trying to retrieve the avatar URL from the Supabase auth user's metadata:

```dart
final userMeta = user?.userMetadata ?? {};
final avatarUrl = (userMeta['avatar_url'] ?? userMeta['avatarUrl'] ?? '')
    .toString()
    .trim();
```

However, when users uploaded their profile photos through the profile screen, the code only updated the `user_profiles` table in the database but did not sync this information back to the Supabase auth user's metadata.

## Solution Implemented

### 1. Updated SupabaseService.upsertUserProfile()
Modified the `upsertUserProfile` method in `lib/core/services/supabase_service.dart` to:
- Update the `user_profiles` table as before
- Additionally sync key profile data (full_name, avatar_url) to the Supabase auth user's metadata using `client.auth.updateUser()`

```dart
// Update auth user metadata with key profile data for video calls
try {
  final userMetadata = <String, dynamic>{};
  
  // Include key fields that video call widget expects
  if (profileData['full_name'] != null) {
    userMetadata['full_name'] = profileData['full_name'];
  }
  if (profileData['avatar_url'] != null) {
    userMetadata['avatar_url'] = profileData['avatar_url'];
  }
  
  if (userMetadata.isNotEmpty) {
    await client.auth.updateUser(
      UserAttributes(data: userMetadata),
    );
  }
} catch (e) {
  // Don't fail the entire operation if metadata update fails
}
```

### 2. Updated AuthProvider.updateProfile()
Modified the `updateProfile` method in `lib/core/providers/auth_provider.dart` to:
- Call the updated upsertUserProfile method
- Refresh the auth state to immediately reflect the updated metadata

```dart
await _supabaseService.upsertUserProfile(profileData: profileData);

// Refresh user data to get updated metadata
final currentUser = _supabaseService.currentUser;
if (currentUser != null) {
  state = state.copyWith(user: currentUser);
  await _syncDomainUser(currentUser);
}
```

## Testing Instructions

### Prerequisites
1. Make sure you have a Supabase account set up
2. Ensure the app is running (`flutter run -d chrome`)
3. Have an image file ready for upload

### Test Steps
1. **Sign up/Login** to the app
2. **Navigate to Profile Screen**
3. **Upload a Profile Photo**:
   - Tap the camera icon or profile photo area
   - Select an image from your device
   - Wait for the upload to complete
4. **Save Profile**: Make sure to tap the "Save Profile" button
5. **Start a Video Call**:
   - Navigate to the calling feature
   - Start a video call
   - Your profile photo should now be visible in the video call interface

### Expected Results
- ✅ Profile photo uploads successfully
- ✅ Profile data saves without errors
- ✅ Profile photo appears in video calls immediately after saving
- ✅ Avatar URL is available in `user.userMetadata['avatar_url']`

### Debug Information
To verify the fix is working, check the debug console for these messages:
- `🔵 SupabaseService: Updating auth user metadata: {full_name: ..., avatar_url: ...}`
- `🟢 SupabaseService: Auth user metadata updated successfully`

## Files Modified
1. `lib/core/services/supabase_service.dart` - Added auth metadata sync to upsertUserProfile()
2. `lib/core/providers/auth_provider.dart` - Added user state refresh to updateProfile()

## Technical Notes
- The fix ensures backward compatibility - old code continues to work
- Metadata update failures don't prevent profile updates from completing
- The auth user state is refreshed immediately to reflect changes
- Both `avatar_url` and `avatarUrl` are supported for maximum compatibility

## Future Improvements
Consider implementing:
1. Image compression before upload for better performance
2. Image caching for faster video call loading
3. Fallback to initials when no avatar is available
4. Real-time avatar updates across all active sessions