import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/signup/signup_screen.dart';
import '../../features/auth/login/login_screen.dart';
import '../../features/auth/models/auth_state.dart';

import '../../features/student/home/student_home_screen.dart';
import '../../features/student/booking/book_session_screen.dart';
import '../../features/student/chat/student_chat_screen.dart';
import '../../features/student/progress/progress_screen.dart';
import '../../features/student/wallet/enhanced_wallet_screen.dart';
import '../../features/mentor/home/mentor_home_screen.dart';
import '../../features/mentor/requests/session_requests_screen.dart';
import '../../features/mentor/chat/mentor_chat_screen.dart';
import '../../features/mentor/earnings/earnings_screen.dart';
import '../../features/mentor/availability/availability_screen.dart';
import '../../features/shared/live_session/live_session_screen.dart';
import '../../features/shared/more/more_menu_screen.dart';
import '../../features/shared/profile/mentor_profile_screen.dart';
import '../../main_navigation.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainNavigation(child: child),
        routes: [
          GoRoute(
            path: '/student/home',
            builder: (context, state) => const StudentHomeScreen(),
          ),
          GoRoute(
            path: '/student/booking',
            builder: (context, state) => const BookSessionScreen(),
          ),
          GoRoute(
            path: '/student/chat',
            builder: (context, state) => const StudentChatScreen(),
          ),
          GoRoute(
            path: '/student/progress',
            builder: (context, state) => const ProgressScreen(),
          ),
          GoRoute(
            path: '/student/wallet',
            builder: (context, state) => const EnhancedWalletScreen(),
          ),
          GoRoute(
            path: '/mentor/home',
            builder: (context, state) => const MentorHomeScreen(),
          ),
          GoRoute(
            path: '/mentor/requests',
            builder: (context, state) => const SessionRequestsScreen(),
          ),
          GoRoute(
            path: '/mentor/chat',
            builder: (context, state) => const MentorChatScreen(),
          ),
          GoRoute(
            path: '/mentor/earnings',
            builder: (context, state) => const EarningsScreen(),
          ),
          GoRoute(
            path: '/mentor/availability',
            builder: (context, state) => const AvailabilityScreen(),
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const MoreMenuScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/session/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return LiveSessionScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/mentor-profile/:mentorId',
        builder: (context, state) {
          final mentorId = state.pathParameters['mentorId']!;
          return MentorProfileScreen(mentorId: mentorId);
        },
      ),
    ],
    redirect: (context, state) {
      final location = state.uri.path;
      debugPrint(
          'GoRouter: Redirect check - Location: $location, Auth: ${authState.status}');

      // Always redirect to login if not authenticated (except for login/signup pages)
      if (authState.status != AuthStatus.authenticated) {
        if (location != '/login' && location != '/signup') {
          debugPrint('GoRouter: Not authenticated, redirecting to login');
          return '/login';
        }
        return null;
      }

      // Handle authenticated users
      if (location == '/login' || location == '/signup' || location == '/') {
        final homePath = authState.isStudent ? '/student/home' : '/mentor/home';
        debugPrint(
            'GoRouter: Authenticated user on auth page, redirecting to $homePath');
        return homePath;
      }

      // Prevent access to wrong role paths
      if (authState.isStudent && location.startsWith('/mentor/')) {
        debugPrint(
            'GoRouter: Student accessing mentor path, redirecting to student home');
        return '/student/home';
      }

      if (!authState.isStudent && location.startsWith('/student/')) {
        debugPrint(
            'GoRouter: Mentor accessing student path, redirecting to mentor home');
        return '/mentor/home';
      }

      debugPrint('GoRouter: No redirect needed');
      return null;
    },
  );
});
