import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login/login_screen.dart';
import '../../features/auth/otp_verification/otp_verification_screen.dart';
import '../../features/auth/signup/signup_screen.dart';
import '../../features/mentor/availability/availability_screen.dart';
import '../../features/mentor/chat/mentor_chat_screen.dart';
import '../../features/mentor/earnings/earnings_screen.dart';
import '../../features/mentor/home/mentor_home_screen.dart';
import '../../features/mentor/requests/session_requests_screen.dart';
import '../../features/shared/live_session/live_session_screen.dart';
import '../../features/shared/more/more_menu_screen.dart';
import '../../features/shared/profile/mentor_profile_screen.dart';
import '../../features/student/booking/book_session_screen.dart';
import '../../features/student/chat/student_chat_screen.dart';
import '../../features/student/home/student_home_screen.dart';
import '../../features/student/progress/progress_screen.dart';
import '../../features/student/wallet/wallet_screen.dart';
import '../../features/websocket/websocket_demo_screen.dart';
import '../../main_navigation.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

// Custom ChangeNotifier to listen to auth changes
class AuthStateNotifier extends ChangeNotifier {
  final Ref ref;
  late final ProviderSubscription subscription;

  AuthStateNotifier(this.ref) {
    subscription = ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    subscription.close();
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable:
        AuthStateNotifier(ref), // This ensures router refreshes on auth changes
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          final phone = state.uri.queryParameters['phone'];
          final verificationType = state.uri.queryParameters['type'] ?? 'email';
          final isSignup = state.uri.queryParameters['signup'] == 'true';
          final password = state.uri.queryParameters['password'];
          final name = state.uri.queryParameters['name'];
          final role = state.uri.queryParameters['role'];

          return OTPVerificationScreen(
            email: email ?? '',
            phoneNumber: phone,
            verificationType: verificationType,
            isSignup: isSignup,
            signupPassword: password,
            signupName: name,
            signupRole: role,
          );
        },
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
            builder: (context, state) => const WalletScreen(),
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
          GoRoute(
            path: '/websocket-demo',
            builder: (context, state) => const WebSocketDemoScreen(),
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
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;

      // Reduce debug noise - only log actual redirects
      // debugPrint('GoRouter: Redirect check - Location: $location, Authenticated: $isAuthenticated');

      // Skip redirect during loading to prevent flashing
      if (authState.isLoading) {
        // debugPrint('GoRouter: Auth loading, no redirect');
        return null;
      }

      // Handle unauthenticated users
      if (!isAuthenticated) {
        // Allow access to auth pages
        if (location == '/login' || location == '/signup') {
          debugPrint(
              'GoRouter: Unauthenticated user on auth page, no redirect');
          return null;
        }
        // Redirect to login for any other page
        debugPrint(
            'GoRouter: Unauthenticated user at $location, redirecting to login');
        return '/login';
      }

      // Handle authenticated users
      if (isAuthenticated) {
        // Redirect from auth pages to appropriate home based on user role
        if (location == '/login' || location == '/signup' || location == '/') {
          try {
            final user = ref.read(userProvider);
            if (user != null) {
              final isMentor = user.role == UserRole.mentor;
              final targetRoute = isMentor ? '/mentor/home' : '/student/home';
              debugPrint(
                  'GoRouter: Authenticated user on auth/root page, redirecting to $targetRoute');
              return targetRoute;
            } else {
              // User is authenticated but domain user not yet synced, default to mentor home
              // The auth provider will sync the correct role shortly
              debugPrint(
                  'GoRouter: User not yet synced, defaulting to mentor home while auth provider syncs user data');
              return '/mentor/home';
            }
          } catch (e) {
            // Handle any provider read errors during initialization
            debugPrint(
                'GoRouter: Error reading user provider, defaulting to student home: $e');
            return '/student/home';
          }
        }
      }

      // debugPrint('GoRouter: No redirect needed');
      return null;
    },
  );
});
