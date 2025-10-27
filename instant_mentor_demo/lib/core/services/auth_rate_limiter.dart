import 'dart:collection';

/// Simple in-memory rate limiter
class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Map<String, Queue<DateTime>> _requests = {};

  RateLimiter({
    required this.maxRequests,
    required this.window,
  });

  /// Check if a request is allowed for the given key
  bool isAllowed(String key) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Initialize queue if not exists
    _requests.putIfAbsent(key, () => Queue<DateTime>());

    final queue = _requests[key]!;

    // Remove old requests outside the window
    while (queue.isNotEmpty && queue.first.isBefore(windowStart)) {
      queue.removeFirst();
    }

    // Check if under limit
    if (queue.length < maxRequests) {
      queue.add(now);
      return true;
    }

    return false;
  }

  /// Get remaining requests for a key
  int getRemainingRequests(String key) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    final queue = _requests[key];
    if (queue == null) return maxRequests;

    // Remove old requests
    while (queue.isNotEmpty && queue.first.isBefore(windowStart)) {
      queue.removeFirst();
    }

    return maxRequests - queue.length;
  }

  /// Get time until next request is allowed
  Duration? getTimeUntilNextAllowed(String key) {
    if (isAllowed(key)) return null;

    final queue = _requests[key];
    if (queue == null || queue.isEmpty) return null;

    final oldestRequest = queue.first;
    final windowStart = DateTime.now().subtract(window);
    final timeUntilReset = oldestRequest.difference(windowStart);

    return timeUntilReset;
  }

  /// Clear all rate limit data
  void clear() {
    _requests.clear();
  }
}

/// Authentication rate limiter with different limits for different operations
class AuthRateLimiter {
  static final AuthRateLimiter _instance = AuthRateLimiter._internal();
  static AuthRateLimiter get instance => _instance;

  AuthRateLimiter._internal();

  // Rate limiters for different auth operations
  final _loginLimiter = RateLimiter(
    maxRequests: 5, // 5 login attempts
    window: const Duration(minutes: 15), // per 15 minutes
  );

  final _signupLimiter = RateLimiter(
    maxRequests: 3, // 3 signup attempts
    window: const Duration(hours: 1), // per hour
  );

  final _passwordResetLimiter = RateLimiter(
    maxRequests: 3, // 3 password reset requests
    window: const Duration(hours: 1), // per hour
  );

  final _emailVerificationLimiter = RateLimiter(
    maxRequests: 5, // 5 verification requests
    window: const Duration(hours: 1), // per hour
  );

  /// Check if login is allowed for the given identifier (email/IP)
  bool isLoginAllowed(String identifier) {
    return _loginLimiter.isAllowed('login:$identifier');
  }

  /// Check if signup is allowed for the given identifier
  bool isSignupAllowed(String identifier) {
    return _signupLimiter.isAllowed('signup:$identifier');
  }

  /// Check if password reset is allowed for the given identifier
  bool isPasswordResetAllowed(String identifier) {
    return _passwordResetLimiter.isAllowed('reset:$identifier');
  }

  /// Check if email verification is allowed for the given identifier
  bool isEmailVerificationAllowed(String identifier) {
    return _emailVerificationLimiter.isAllowed('verify:$identifier');
  }

  /// Get rate limit info for login
  Map<String, dynamic> getLoginLimitInfo(String identifier) {
    return {
      'allowed': _loginLimiter.isAllowed('login:$identifier'),
      'remaining': _loginLimiter.getRemainingRequests('login:$identifier'),
      'resetTime': _loginLimiter.getTimeUntilNextAllowed('login:$identifier'),
    };
  }

  /// Get rate limit info for signup
  Map<String, dynamic> getSignupLimitInfo(String identifier) {
    return {
      'allowed': _signupLimiter.isAllowed('signup:$identifier'),
      'remaining': _signupLimiter.getRemainingRequests('signup:$identifier'),
      'resetTime': _signupLimiter.getTimeUntilNextAllowed('signup:$identifier'),
    };
  }

  /// Get rate limit info for password reset
  Map<String, dynamic> getPasswordResetLimitInfo(String identifier) {
    return {
      'allowed': _passwordResetLimiter.isAllowed('reset:$identifier'),
      'remaining':
          _passwordResetLimiter.getRemainingRequests('reset:$identifier'),
      'resetTime':
          _passwordResetLimiter.getTimeUntilNextAllowed('reset:$identifier'),
    };
  }

  /// Get rate limit info for email verification
  Map<String, dynamic> getEmailVerificationLimitInfo(String identifier) {
    return {
      'allowed': _emailVerificationLimiter.isAllowed('verify:$identifier'),
      'remaining':
          _emailVerificationLimiter.getRemainingRequests('verify:$identifier'),
      'resetTime': _emailVerificationLimiter
          .getTimeUntilNextAllowed('verify:$identifier'),
    };
  }
}
