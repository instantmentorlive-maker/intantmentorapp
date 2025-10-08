# 🔍 Session Persistence After Reload - Debug Guide

## 🎯 Issue Reported

When you reload the page or restart the app, your booked demo sessions disappear from the "Upcoming Sessions" list.

## 🧪 What We Need to Test

### Test 1: Check if Sessions Are Being Saved

**Steps:**
1. Open browser DevTools (F12) → Console tab
2. Book a new session (pick a time **TOMORROW** to avoid time-based issues)
3. Look for these logs:

```
✅ DemoSessionsNotifier: Adding session demo_1728...
   Before: 0 sessions
   After: 1 sessions
💾 Saving 1 demo sessions to SharedPreferences...
✅ Successfully saved to key: demo_sessions_v2_persistent
```

**What to check:**
- ✅ Does it say "Successfully saved"?
- ✅ What's the key name? (should be `demo_sessions_v2_persistent`)

### Test 2: Check if Sessions Are Being Loaded on Reload

**Steps:**
1. After booking a session (from Test 1)
2. Press **F5** to reload the page
3. Look for these logs immediately on page load:

```
🎬 DemoSessionsNotifier: Constructor called - initializing...
🔄 DemoSessionsNotifier: Loading sessions from SharedPreferences...
📦 Raw data from prefs: [{"id":"demo_1728...
📊 Decoded 1 sessions from JSON
   Session demo_1728...: created 0 days ago, isValid: true
✅ DemoSessionsNotifier: Loaded 1 demo sessions
   📅 demo_1728...: 2025-10-08 14:00:00.000 (SessionStatus.pending)
```

**What to check:**
- ✅ Does it find sessions in SharedPreferences?
- ✅ Are sessions decoded successfully?
- ✅ Are sessions marked as valid?
- ❌ Do you see "No demo sessions found"?

### Test 3: Check if Sessions Pass the Time Filter

**Steps:**
1. After reload (from Test 2)
2. Navigate to student home page
3. Look for these logs:

```
📅 DEBUG: Total demo sessions in provider: 1
   Session: demo_1728..., Scheduled: 2025-10-08 14:00:00.000, Status: SessionStatus.pending
📅 DEBUG: Filtered upcoming sessions: 1
📅 simpleUpcomingSessionsProvider: Returning 1 demo sessions for non-authenticated user
```

**What to check:**
- ✅ Total sessions > 0?
- ✅ Filtered sessions > 0?
- ❌ If total > 0 but filtered = 0, the session time has passed!

## 🐛 Common Issues and Solutions

### Issue 1: Sessions Not Being Saved

**Symptom:**
```
❌ Failed to save demo sessions to prefs: ...
```

**Causes:**
- Browser storage quota exceeded
- Browser in private/incognito mode (some browsers restrict storage)
- Browser permissions issue

**Solution:**
1. Clear browser cache and cookies
2. Try a different browser
3. Check browser console for storage errors

### Issue 2: Sessions Not Being Loaded

**Symptom:**
```
⚠️ No demo sessions found in SharedPreferences
```

**Possible Causes:**
1. **Different storage key**: Check if old key was used
2. **Browser cleared storage**: Check Application tab → Local Storage
3. **Different browser/profile**: SharedPreferences is per-browser

**How to verify:**
1. Open DevTools → Application tab
2. Go to Storage → Local Storage → http://localhost:8080
3. Look for key: `flutter.demo_sessions_v2_persistent`
4. Check if it has data

### Issue 3: Sessions Loaded But Filtered Out

**Symptom:**
```
📅 DEBUG: Total demo sessions in provider: 1
📅 DEBUG: Filtered upcoming sessions: 0
```

**Cause:**
The session time is in the **PAST**. The filter removes:
- Sessions with `scheduledTime` before current time
- Sessions with status other than `pending` or `confirmed`

**Solution:**
Book sessions for **TOMORROW** or later, not for today!

### Issue 4: Storage Key Mismatch

**Old key:** `demo_sessions` (without version)
**New key:** `demo_sessions_v2_persistent`

If you have old sessions, they won't load with the new key.

**Solution - Manual Migration:**
1. Open DevTools → Application → Local Storage
2. Find `flutter.demo_sessions` (old key)
3. Copy its value
4. Create new key `flutter.demo_sessions_v2_persistent`
5. Paste the value
6. Reload page

## 📊 Expected Full Flow with Logs

### When Booking a Session:

```
1. User clicks "Book Session"
   ↓
2. Session created
   ✅ Session booked successfully: demo_1728345678901
   ↓
3. Added to provider
   ✅ DemoSessionsNotifier: Adding session demo_1728345678901
      Before: 0 sessions
      After: 1 sessions
   ↓
4. Saved to storage
   💾 Saving 1 demo sessions to SharedPreferences...
   ✅ Successfully saved to key: demo_sessions_v2_persistent
   ↓
5. Providers invalidated
   📅 DEBUG: Total demo sessions in provider: 1
   📅 DEBUG: Filtered upcoming sessions: 1
   📅 simpleUpcomingSessionsProvider: Returning 1 demo sessions
   ↓
6. UI updates
   ✅ Session appears in "Upcoming Sessions"
```

### When Reloading Page:

```
1. Page loads
   ↓
2. Provider initializes
   🎬 DemoSessionsNotifier: Constructor called - initializing...
   ↓
3. Load from storage
   🔄 DemoSessionsNotifier: Loading sessions from SharedPreferences...
   📦 Raw data from prefs: [{"id":"demo_...
   ↓
4. Decode sessions
   📊 Decoded 1 sessions from JSON
   ✅ DemoSessionsNotifier: Loaded 1 demo sessions
   ↓
5. Filter for display
   📅 DEBUG: Total demo sessions in provider: 1
   📅 DEBUG: Filtered upcoming sessions: 1
   ↓
6. UI shows sessions
   ✅ Session appears in "Upcoming Sessions"
```

## 🔧 Manual Browser Storage Check

### How to Check Storage Manually:

1. **Open DevTools** (F12)
2. Go to **Application** tab (Chrome) or **Storage** tab (Firefox)
3. Expand **Local Storage** in sidebar
4. Click on `http://localhost:8080`
5. Look for key: `flutter.demo_sessions_v2_persistent`

### What You Should See:

**Key:** `flutter.demo_sessions_v2_persistent`

**Value (example):**
```json
[
  {
    "id": "demo_1728345678901",
    "studentId": "demo_student_1728345678902",
    "mentorId": "mentor_1",
    "subject": "General",
    "scheduledTime": "2025-10-08T14:00:00.000",
    "durationMinutes": 60,
    "amount": 50.0,
    "status": "pending",
    "createdAt": "2025-10-07T10:30:00.000"
  }
]
```

### If Key Is Missing:

- Sessions were never saved (check Test 1)
- Browser cleared storage
- Using different browser/profile

### If Key Exists But Sessions Don't Appear:

- Check the `scheduledTime` - is it in the future?
- Check the `status` - is it "pending" or "confirmed"?
- Check console logs for filtering information

## 🎯 Action Items

### Step 1: Clear Everything and Start Fresh

```javascript
// Run this in browser console to clear all demo sessions:
localStorage.removeItem('flutter.demo_sessions_v2_persistent');
```

Then reload the page.

### Step 2: Book a Test Session

1. Book a session for **TOMORROW** at 2:00 PM
2. Copy ALL console logs
3. Check if it appears in "Upcoming Sessions"

### Step 3: Test Persistence

1. Press **F5** to reload
2. Copy ALL console logs (especially the load logs)
3. Check if session still appears

### Step 4: Share Results

If sessions still disappear after reload, share:
1. ✅ All console logs from booking
2. ✅ All console logs from reload
3. ✅ Screenshot of Application → Local Storage
4. ✅ The scheduled time you picked

## 🔍 Debug Checklist

Use this checklist to diagnose the issue:

**After Booking:**
- [ ] Console shows "Successfully saved" message
- [ ] Console shows "Returning X demo sessions"
- [ ] Session appears in UI
- [ ] Application → Local Storage has the key
- [ ] Local Storage value looks valid (JSON array)

**After Reload:**
- [ ] Console shows "DemoSessionsNotifier: Constructor called"
- [ ] Console shows "Loading sessions from SharedPreferences"
- [ ] Console shows "Loaded X demo sessions" (X > 0)
- [ ] Console shows "Total demo sessions in provider: X" (X > 0)
- [ ] Console shows "Filtered upcoming sessions: X" (X > 0)
- [ ] Session appears in UI

**If any checkbox is ❌, that's where the problem is!**

---

**Next Steps:** Run the tests above and share the console logs. The logs will tell us exactly where the persistence is breaking!
