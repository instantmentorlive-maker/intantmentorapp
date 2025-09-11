// Route names for easy navigation
class AppRoutes {
  // Auth routes
  static const login = '/login';
  static const signup = '/signup';
  
  // Student routes
  static const studentHome = '/student/home';
  static const studentBooking = '/student/booking';
  static const studentChat = '/student/chat';
  static const studentProgress = '/student/progress';
  static const studentWallet = '/student/wallet';
  
  // Mentor routes
  static const mentorHome = '/mentor/home';
  static const mentorRequests = '/mentor/requests';
  static const mentorChat = '/mentor/chat';
  static const mentorEarnings = '/mentor/earnings';
  static const mentorAvailability = '/mentor/availability';
  
  // Shared routes
  static const more = '/more';
  static String session(String sessionId) => '/session/$sessionId';
  static String mentorProfile(String mentorId) => '/mentor-profile/$mentorId';
}
