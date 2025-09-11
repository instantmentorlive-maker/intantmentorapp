You are building a mobile-first responsive app in Flutter for an instant 1-on-1 competitive exam mentoring platform. 
The app must support BOTH STUDENT and MENTOR roles, each with their own role-based footer navigation and feature set.

## Core Requirements:
- Role-based UI: Show different footer & "More" menu based on the logged-in role.
- Mobile-first design but responsive for tablets.
- All features must have their own dedicated screen/window (StatefulWidget/StatelessWidget).
- Placeholder/mock data must be used where backend is not yet integrated.
- Navigation should use named routes.
- State management with Riverpod or Provider (your choice).
- UI style: modern, Material 3, primary color #3F51B5.
- Footer for high-priority features; "More" menu for secondary features.
- Ready for future integration with REST API or Supabase.

---

## ROLE: Student

### Footer Navigation (High Priority Student Actions)
Fixed BottomNavigationBar with 5 tabs:
1. **Home**
   - AI mentor recommendations (cards with name, subject, rating, "Book Now").
   - Upcoming sessions list.
   - Quick actions: "Book Session" & "Ask a Doubt".
   - Tap mentor card → Mentor Profile screen.

2. **Book Session**
   - Filter: Exam, Subject, Price, Availability.
   - List of filtered mentors.
   - Booking flow: Select mentor → Profile → "Book Session" → Payment placeholder → Success screen.

3. **CHAT FEATURES**
   - Real-time chat with mentors.
   - File sharing (documents, images).
   - Chat history and search.

4. **Progress**
   - Progress chart (dummy data): completed, pending, weak areas.
   - "View Detailed Progress" → topic breakdown list.

5. **Wallet**
   - Current credits, transaction history (dummy).
   - "Add Credits" → payment placeholder.

### More Menu (Student Secondary Features)
- Mentor Profiles & Ratings – Search/sort mentors.
- Session Notes & Resources – List past notes/files/recordings.
- Daily Quick Doubt Sessions – 5–10 min calls.
- Leaderboard – Top students (dummy ranking).
- Free Trial/Doubt – One free session (redirect to booking).
- Settings & Support – Preferences, helpdesk placeholder.

---

## ROLE: Mentor

### Footer Navigation (High Priority Mentor Actions)
Fixed BottomNavigationBar with 5 tabs:
1. **Home**
   - Dashboard: upcoming booked sessions, earnings summary.
   - Quick action: "Go Available" toggle.

2. **Accept Requests**
   - Real-time list of incoming session requests (dummy).
   - Accept/Reject buttons → opens session placeholder.

3. **CHAT FEATURES**
   - Real-time chat with students.
   - File sharing (documents, images).
   - Chat history and search.

4. **Earnings**
   - Earnings dashboard with total, weekly, monthly income (dummy data).
   - Withdrawal request button → placeholder.

5. **Availability**
   - Toggle availability status.
   - Set weekly schedule (time slots placeholder).

### More Menu (Mentor Secondary Features)
- Profile Management – Edit bio, subjects, pricing, qualifications.
- Student History & Notes – Past sessions & notes.
- Performance & Ratings – View feedback & improve profile visibility.
- Leaderboard – Top mentors & badges.
- Incentives & Bonuses – Rewards for peak hours (dummy data).
- Settings & Support – Preferences, helpdesk placeholder.

---

## Functional Requirements (Both Roles)
- All menu items/screens navigable with placeholder data.
- Role detection at login → show correct footer/menu.
- Placeholder mentor/student data should be realistic (names, subjects, ratings).
- Wallet/earnings data should look real (amounts, dates, descriptions).
- Footer icons: use Material Icons (role-appropriate).
- More menu icons: relevant Material Icons.
- Mobile-friendly UI (scrollable lists, large touch targets).
- Role switch possible in dev mode for testing.

---

## Technical Implementation Notes
- Use a feature-based folder structure (`/features/student/home/`, `/features/mentor/home/`, etc.).
- Use Material 3 theme, consistent spacing, responsive layout.
- Dummy assets/images for mentor/student profile pics in `/assets/`.
- Smooth navigation with animations.
- Prepare for API integration: keep data fetching logic separate from UI.

Deliver a clean, well-commented Flutter codebase that compiles and runs on both Android and iOS with role-based navigation and placeholder workflows ready for backend connection.
