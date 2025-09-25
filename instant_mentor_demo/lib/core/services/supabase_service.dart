import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  static bool _initialized = false;
  bool get isInitialized => _initialized;
  Future<void> init() => SupabaseService.initialize();

  /// Initialize Supabase
  static Future<void> initialize() async {
    var supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
    }

    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) {
      throw Exception('SUPABASE_URL or SUPABASE_ANON_KEY is empty in .env');
    }

    // Normalize common misconfigurations that lead to 404/empty responses
    supabaseUrl = supabaseUrl.trim();
    if (supabaseUrl.endsWith('/')) {
      supabaseUrl = supabaseUrl.substring(0, supabaseUrl.length - 1);
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
        // Set explicit flow to avoid platform default inconsistencies
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        // A tiny header helps trace traffic in logs/dashboards
        headers: const {'X-Client-Info': 'instant-mentor-demo/1.0.0'},
      );
      _initialized = true;
    } on AuthException catch (e) {
      debugPrint('❌ Supabase initialize AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Supabase initialize error: $e');
      rethrow;
    }
  }

  /// Lightweight health check (configuration + basic client available)
  Future<bool> healthCheck() async {
    try {
      // Touch a lightweight property; if not initialized this will throw
      // or return null user but that's fine
      Supabase.instance.client.auth.currentUser;
      return _initialized;
    } catch (_) {
      return false;
    }
  }

  /// Authentication Methods

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('🔵 SupabaseService: Starting signup...');
    debugPrint('🔵 Email: $email');

    // Validate input
    if (email.isEmpty) {
      debugPrint('🔴 SupabaseService: Empty email');
      throw const AuthException('Please enter your email address.');
    }

    if (password.isEmpty) {
      debugPrint('🔴 SupabaseService: Empty password');
      throw const AuthException('Please enter a password.');
    }

    if (!email.contains('@')) {
      debugPrint('🔴 SupabaseService: Invalid email format');
      throw const AuthException('Please enter a valid email address.');
    }

    // Validate password strength
    if (password.length < 6) {
      debugPrint('🔴 SupabaseService: Password too short');
      throw const AuthException('Password must be at least 6 characters long.');
    }

    try {
      debugPrint('🔵 SupabaseService: Calling Supabase auth.signUp...');

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      debugPrint('🟢 SupabaseService: Supabase response received');
      debugPrint('🟢 User: ${response.user?.email}');
      debugPrint(
          '🟢 Session: ${response.session != null ? "Present" : "Null"}');

      return response;
    } on AuthApiException catch (e) {
      debugPrint('🔴 SupabaseService: Auth API error: ${e.message}');

      // Handle specific signup errors
      switch (e.message.toLowerCase()) {
        case 'user already registered':
        case 'email address already registered':
          throw const AuthException(
              'An account with this email already exists. Please sign in instead.');
        case 'signup is disabled':
          throw const AuthException(
              'New account registration is currently disabled.');
        case 'password is too weak':
          throw const AuthException(
              'Password is too weak. Please use a stronger password with at least 6 characters.');
        case 'email rate limit exceeded':
        case 'for security purposes, you can only request this after':
          throw const AuthException(
              'Too many signup attempts. Please wait a few minutes before trying again.');
        default:
          if (e.message.contains('password')) {
            throw const AuthException(
                'Password does not meet requirements. Please use at least 6 characters.');
          } else if (e.message.contains('email')) {
            throw const AuthException(
                'Invalid email address or email already in use.');
          } else {
            throw AuthException('Signup failed: ${e.message}');
          }
      }
    } on AuthUnknownException catch (e) {
      // Common when the Supabase URL is wrong or blocked, surfaces as 404 empty
      debugPrint(
          '🔴 SupabaseService: Unknown auth error (likely misconfig): ${e.message}');
      throw const AuthException(
        'Auth service not reachable (404). Please check your Supabase URL and network connection.',
      );
    } on AuthException {
      // Re-throw other AuthExceptions as-is
      rethrow;
    } catch (e) {
      debugPrint('🔴 SupabaseService: Unexpected signup error: $e');

      // Handle network or other errors
      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw const AuthException(
            'Network error. Please check your internet connection and try again.');
      } else {
        throw const AuthException('Signup failed. Please try again.');
      }
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    debugPrint('🔵 SupabaseService: Starting login...');
    debugPrint('🔵 Email: $email');

    // Validate input
    if (email.isEmpty) {
      debugPrint('🔴 SupabaseService: Empty email');
      throw const AuthException('Please enter your email address.');
    }

    if (password.isEmpty) {
      debugPrint('🔴 SupabaseService: Empty password');
      throw const AuthException('Please enter your password.');
    }

    if (!email.contains('@')) {
      debugPrint('🔴 SupabaseService: Invalid email format');
      throw const AuthException('Please enter a valid email address.');
    }

    try {
      debugPrint(
          '🔵 SupabaseService: Calling Supabase auth.signInWithPassword...');

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('🟢 SupabaseService: Supabase login response received');
      debugPrint('🟢 User: ${response.user?.email}');
      debugPrint(
          '🟢 Session: ${response.session != null ? "Present" : "Null"}');

      return response;
    } on AuthApiException catch (e) {
      debugPrint('🔴 SupabaseService: Auth API error: ${e.message}');

      // Handle specific authentication errors
      switch (e.message.toLowerCase()) {
        case 'invalid login credentials':
          throw const AuthException(
              'Invalid email or password. Please check your credentials and try again.');
        case 'email not confirmed':
          throw const AuthException(
              'Please verify your email address before signing in.');
        case 'too many requests':
          throw const AuthException(
              'Too many login attempts. Please wait a few minutes before trying again.');
        case 'user not found':
          throw const AuthException(
              'No account found with this email address. Please sign up first.');
        default:
          if (e.message.contains('password')) {
            throw const AuthException('Incorrect password. Please try again.');
          } else if (e.message.contains('email')) {
            throw const AuthException(
                'No account found with this email address.');
          } else {
            throw AuthException('Login failed: ${e.message}');
          }
      }
    } on AuthUnknownException catch (e) {
      // Common when the Supabase URL is wrong or blocked, surfaces as 404 empty
      debugPrint(
          '🔴 SupabaseService: Unknown auth error (likely misconfig): ${e.message}');
      throw const AuthException(
        'Auth service not reachable (404). Please check your Supabase URL and network connection.',
      );
    } on AuthException {
      // Re-throw other AuthExceptions as-is
      rethrow;
    } catch (e) {
      debugPrint('🔴 SupabaseService: Unexpected login error: $e');

      // Handle network or other errors
      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw const AuthException(
            'Network error. Please check your internet connection and try again.');
      } else {
        throw const AuthException('Login failed. Please try again.');
      }
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  /// Get current user
  User? get currentUser => client.auth.currentUser;

  /// OTP Methods for Email and Phone Verification

  /// Send OTP to email for verification
  Future<void> sendEmailOTP(String email) async {
    try {
      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      debugPrint('🔵 SupabaseService: Email OTP sent to $email');
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('🔴 SupabaseService: Failed to send email OTP: $e');
      throw AuthException('Failed to send verification code: ${e.toString()}');
    }
  }

  /// Verify email OTP
  Future<AuthResponse> verifyEmailOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await client.auth.verifyOTP(
        type: OtpType.email,
        token: otp,
        email: email,
      );

      debugPrint('🔵 SupabaseService: Email OTP verified for $email');
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('🔴 SupabaseService: Failed to verify email OTP: $e');
      throw const AuthException('Invalid verification code. Please try again.');
    }
  }

  /// Resend email OTP
  Future<void> resendEmailOTP(String email) async {
    try {
      await client.auth.resend(
        type: OtpType.email,
        email: email,
      );
      debugPrint('🔵 SupabaseService: Email OTP resent to $email');
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('🔴 SupabaseService: Failed to resend email OTP: $e');
      throw AuthException(
          'Failed to resend verification code: ${e.toString()}');
    }
  }

  /// Send OTP to phone for verification
  Future<void> sendPhoneOTP(String phoneNumber) async {
    try {
      await client.auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: false,
      );
      debugPrint('🔵 SupabaseService: Phone OTP sent to $phoneNumber');
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('🔴 SupabaseService: Failed to send phone OTP: $e');
      throw AuthException('Failed to send verification code: ${e.toString()}');
    }
  }

  /// Verify phone OTP
  Future<AuthResponse> verifyPhoneOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await client.auth.verifyOTP(
        type: OtpType.sms,
        token: otp,
        phone: phone,
      );

      debugPrint('🔵 SupabaseService: Phone OTP verified for $phone');
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('🔴 SupabaseService: Failed to verify phone OTP: $e');
      throw const AuthException('Invalid verification code. Please try again.');
    }
  }

  /// Resend phone OTP
  Future<void> resendPhoneOTP(String phoneNumber) async {
    try {
      await client.auth.resend(
        type: OtpType.sms,
        phone: phoneNumber,
      );
      debugPrint('🔵 SupabaseService: Phone OTP resent to $phoneNumber');
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('🔴 SupabaseService: Failed to resend phone OTP: $e');
      throw AuthException(
          'Failed to resend verification code: ${e.toString()}');
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Database Methods

  /// Insert data into a table
  Future<List<Map<String, dynamic>>> insertData({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    final response = await client.from(table).insert(data).select();
    return response;
  }

  /// Update data in a table
  Future<List<Map<String, dynamic>>> updateData({
    required String table,
    required Map<String, dynamic> data,
    required String column,
    required dynamic value,
  }) async {
    final response =
        await client.from(table).update(data).eq(column, value).select();
    return response;
  }

  /// Delete data from a table
  Future<void> deleteData({
    required String table,
    required String column,
    required dynamic value,
  }) async {
    await client.from(table).delete().eq(column, value);
  }

  /// Fetch data from a table
  Future<List<Map<String, dynamic>>> fetchData({
    required String table,
    String? orderBy,
    bool ascending = true,
    int? limit,
    Map<String, dynamic>? filters,
  }) async {
    var query = client.from(table).select();

    // Apply filters
    if (filters != null) {
      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }
    }

    final result = query;

    // Apply ordering and limit
    if (orderBy != null && limit != null) {
      return await result.order(orderBy, ascending: ascending).limit(limit);
    } else if (orderBy != null) {
      return await result.order(orderBy, ascending: ascending);
    } else if (limit != null) {
      return await result.limit(limit);
    }

    return await result;
  }

  /// Real-time subscription to a table
  RealtimeChannel subscribeToTable({
    required String table,
    required void Function(PostgresChangePayload) onData,
    void Function(dynamic)? onError,
  }) {
    final channel = client
        .channel('public:$table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: onData,
        )
        .subscribe();

    // Note: onError method might not be available in current version
    // Error handling can be done through try-catch in the callback

    return channel;
  }

  /// Storage Methods

  /// Upload file to storage
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> fileBytes,
    String? contentType,
  }) async {
    await client.storage
        .from(bucket)
        .uploadBinary(path, Uint8List.fromList(fileBytes),
            fileOptions: FileOptions(
              contentType: contentType,
            ));

    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Download file from storage
  Future<List<int>> downloadFile({
    required String bucket,
    required String path,
  }) async {
    return await client.storage.from(bucket).download(path);
  }

  /// Delete file from storage
  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await client.storage.from(bucket).remove([path]);
  }

  /// Email and Messaging Methods

  /// Send email using Supabase Edge Functions
  Future<void> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
    String? textContent,
    List<String>? cc,
    List<String>? bcc,
  }) async {
    await client.functions.invoke('send-email', body: {
      'to': to,
      'subject': subject,
      'html': htmlContent,
      'text': textContent,
      'cc': cc,
      'bcc': bcc,
    });
  }

  /// Send notification using Supabase Edge Functions
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    await client.functions.invoke('send-notification', body: {
      'userId': userId,
      'title': title,
      'message': message,
      'data': data,
    });
  }

  /// User Profile Methods

  /// Create or update user profile
  Future<Map<String, dynamic>> upsertUserProfile({
    required Map<String, dynamic> profileData,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    profileData['id'] = userId;
    profileData['updated_at'] = DateTime.now().toIso8601String();

    try {
      debugPrint('🔵 SupabaseService: Upserting user profile...');
      debugPrint('🔵 Data: $profileData');

      final response = await client
          .from('user_profiles')
          .upsert(profileData)
          .select()
          .single();

      debugPrint('🟢 SupabaseService: Profile upserted successfully');

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
          debugPrint(
              '🔵 SupabaseService: Updating auth user metadata: $userMetadata');
          await client.auth.updateUser(
            UserAttributes(data: userMetadata),
          );
          debugPrint(
              '🟢 SupabaseService: Auth user metadata updated successfully');
        }
      } catch (e) {
        debugPrint(
            '⚠️ SupabaseService: Failed to update auth user metadata: $e');
        // Don't fail the entire operation if metadata update fails
      }

      return response;
    } catch (e) {
      debugPrint('🔴 SupabaseService: Profile upsert failed: $e');

      // Check for specific database schema errors
      if (e.toString().contains('column') &&
          e.toString().contains('does not exist')) {
        final missingColumn = _extractMissingColumn(e.toString());
        debugPrint('🚨 Database schema error: Missing column "$missingColumn"');
        throw Exception(
            'Database not properly migrated. Missing column: $missingColumn. Please run the database migration script.');
      }

      rethrow;
    }
  }

  String _extractMissingColumn(String error) {
    // Try to extract column name from error message
    final match = RegExp(r'column "([^"]+)" does not exist').firstMatch(error);
    return match?.group(1) ?? 'unknown';
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    try {
      final response =
          await client.from('user_profiles').select().eq('id', userId).single();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Update user preference flags (stored in user_profiles.preferences JSONB)
  Future<void> updateUserPreferences(Map<String, dynamic> patch) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    try {
      debugPrint('🔵 SupabaseService: Updating preferences for user $userId');
      debugPrint('🔵 Patch data: $patch');

      // First, ensure the user profile exists with default preferences
      await client
          .from('user_profiles')
          .upsert({
            'id': userId,
            'preferences': patch,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'id')
          .select()
          .maybeSingle();

      debugPrint('🟢 SupabaseService: User preferences updated successfully');
    } catch (e) {
      debugPrint('🔴 SupabaseService: Error updating user preferences: $e');

      // Check if it's a column missing error
      if (e.toString().contains('column "preferences" does not exist')) {
        debugPrint('🚨 Database schema error: preferences column missing!');
        throw Exception(
            'Database not properly migrated. Please run the database migration script first.');
      }

      // If the above fails, try the merge approach
      try {
        debugPrint('🔵 Trying merge approach for preferences...');

        // Fetch current preferences
        final existing = await client
            .from('user_profiles')
            .select('preferences')
            .eq('id', userId)
            .maybeSingle();

        final current =
            (existing?['preferences'] as Map?)?.cast<String, dynamic>() ?? {};
        final merged = {...current, ...patch};

        await client.from('user_profiles').update({
          'preferences': merged,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);

        debugPrint('🟢 SupabaseService: User preferences merged successfully');
      } catch (e2) {
        debugPrint('🔴 SupabaseService: Error merging user preferences: $e2');
        if (e2.toString().contains('column') &&
            e2.toString().contains('does not exist')) {
          throw Exception(
              'Database schema error: Missing columns. Please run the database migration script.');
        }
        throw Exception('Failed to update preferences: $e2');
      }
    }
  }

  /// Mentor-Student Matching Methods

  /// Create mentor profile
  Future<Map<String, dynamic>> createMentorProfile({
    required Map<String, dynamic> mentorData,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    mentorData['user_id'] = userId;
    mentorData['created_at'] = DateTime.now().toIso8601String();

    final response = await client
        .from('mentor_profiles')
        .insert(mentorData)
        .select()
        .single();

    return response;
  }

  /// Find mentors based on criteria
  Future<List<Map<String, dynamic>>> findMentors({
    String? subject,
    String? experience,
    double? rating,
    bool? isAvailable,
  }) async {
    var query = client.from('mentor_profiles').select('''
      *,
      profiles(*)
    ''');

    if (subject != null) {
      query = query.contains('subjects', [subject]);
    }

    if (experience != null) {
      query = query.gte('years_experience', experience);
    }

    if (rating != null) {
      query = query.gte('average_rating', rating);
    }

    if (isAvailable != null) {
      query = query.eq('is_available', isAvailable);
    }

    return await query;
  }

  /// Session Management Methods

  /// Create mentoring session
  Future<Map<String, dynamic>> createSession({
    required String mentorId,
    required String studentId,
    required DateTime scheduledTime,
    required Duration duration,
    String? subject,
    String? description,
  }) async {
    final sessionData = {
      'mentor_id': mentorId,
      'student_id': studentId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'duration_minutes': duration.inMinutes,
      'subject': subject,
      'description': description,
      'status': 'scheduled',
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await client
        .from('mentoring_sessions')
        .insert(sessionData)
        .select()
        .single();

    return response;
  }

  /// Update session status
  Future<void> updateSessionStatus({
    required String sessionId,
    required String status,
    String? notes,
  }) async {
    await client.from('mentoring_sessions').update({
      'status': status,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  /// Upload profile image to Supabase Storage
  Future<String?> uploadProfileImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('User must be authenticated');

      // Create a unique file path for the user
      final filePath = 'profiles/$userId/$fileName';

      // Upload to Supabase Storage
      await client.storage.from('avatars').uploadBinary(filePath, imageBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ));

      // Get the public URL
      final publicUrl = client.storage.from('avatars').getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error uploading profile image: $e');
      rethrow;
    }
  }
}
