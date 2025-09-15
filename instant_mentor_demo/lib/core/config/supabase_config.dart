import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get supabaseServiceRoleKey =>
      dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Database table names
  static const String userProfilesTable = 'user_profiles';
  static const String mentorProfilesTable = 'mentor_profiles';
  static const String studentProfilesTable = 'student_profiles';
  static const String mentoringSessionsTable = 'mentoring_sessions';
  static const String messagesTable = 'messages';
  static const String notificationsTable = 'notifications';
  static const String reviewsTable = 'reviews';
  static const String availabilityTable = 'mentor_availability';
  static const String documentsTable = 'documents';

  /// Storage bucket names
  static const String profileImagesBucket = 'profile-images';
  static const String documentsBucket = 'documents';
  static const String sessionRecordingsBucket = 'session-recordings';
  static const String certificatesBucket = 'certificates';

  /// Edge function names
  static const String sendEmailFunction = 'send-email';
  static const String sendNotificationFunction = 'send-notification';
  static const String generateCertificateFunction = 'generate-certificate';
  static const String processPaymentFunction = 'process-payment';
  static const String matchMentorFunction = 'match-mentor';

  /// Database schemas for table creation

  /// User profiles table schema
  static const String userProfilesSchema = '''
    CREATE TABLE IF NOT EXISTS user_profiles (
      id UUID REFERENCES auth.users(id) PRIMARY KEY,
      email TEXT,
      full_name TEXT,
      avatar_url TEXT,
      phone_number TEXT,
      date_of_birth DATE,
      bio TEXT,
      location TEXT,
      timezone TEXT,
      preferred_language TEXT DEFAULT 'en',
      created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
    );
  ''';

  /// Mentor profiles table schema
  static const String mentorProfilesSchema = '''
    CREATE TABLE IF NOT EXISTS mentor_profiles (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      user_id UUID REFERENCES auth.users(id) NOT NULL,
      title TEXT,
      subjects TEXT[],
      years_experience INTEGER,
      hourly_rate DECIMAL(10,2),
      average_rating DECIMAL(3,2) DEFAULT 0,
      total_sessions INTEGER DEFAULT 0,
      is_available BOOLEAN DEFAULT true,
      is_verified BOOLEAN DEFAULT false,
      education TEXT[],
      certifications TEXT[],
      languages TEXT[],
      availability_hours JSONB,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
    );
  ''';

  /// Mentoring sessions table schema
  static const String mentoringSessionsSchema = '''
    CREATE TABLE IF NOT EXISTS mentoring_sessions (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      mentor_id UUID REFERENCES mentor_profiles(id) NOT NULL,
      student_id UUID REFERENCES auth.users(id) NOT NULL,
      scheduled_time TIMESTAMP WITH TIME ZONE NOT NULL,
      duration_minutes INTEGER NOT NULL,
      subject TEXT,
      description TEXT,
      status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled')),
      notes TEXT,
      rating INTEGER CHECK (rating >= 1 AND rating <= 5),
      review TEXT,
      recording_url TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
    );
  ''';

  /// Messages table schema
  static const String messagesSchema = '''
    CREATE TABLE IF NOT EXISTS messages (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      session_id UUID REFERENCES mentoring_sessions(id),
      sender_id UUID REFERENCES auth.users(id) NOT NULL,
      receiver_id UUID REFERENCES auth.users(id) NOT NULL,
      content TEXT NOT NULL,
      message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'audio')),
      file_url TEXT,
      is_read BOOLEAN DEFAULT false,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
    );
  ''';

  /// Notifications table schema
  static const String notificationsSchema = '''
    CREATE TABLE IF NOT EXISTS notifications (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      user_id UUID REFERENCES auth.users(id) NOT NULL,
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      type TEXT DEFAULT 'info' CHECK (type IN ('info', 'success', 'warning', 'error')),
      is_read BOOLEAN DEFAULT false,
      action_url TEXT,
      data JSONB,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
    );
  ''';

  /// Row Level Security (RLS) policies

  /// Enable RLS on all tables
  static const List<String> enableRLSCommands = [
    'ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;',
    'ALTER TABLE mentor_profiles ENABLE ROW LEVEL SECURITY;',
    'ALTER TABLE mentoring_sessions ENABLE ROW LEVEL SECURITY;',
    'ALTER TABLE messages ENABLE ROW LEVEL SECURITY;',
    'ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;',
  ];

  /// Create RLS policies
  static const List<String> createPolicies = [
    // User profiles policies
    '''CREATE POLICY "Users can view own profile" ON user_profiles 
       FOR SELECT USING (auth.uid() = id);''',
    '''CREATE POLICY "Users can update own profile" ON user_profiles 
       FOR UPDATE USING (auth.uid() = id);''',
    '''CREATE POLICY "Users can insert own profile" ON user_profiles 
       FOR INSERT WITH CHECK (auth.uid() = id);''',

    // Mentor profiles policies
    '''CREATE POLICY "Anyone can view mentor profiles" ON mentor_profiles 
       FOR SELECT TO authenticated USING (true);''',
    '''CREATE POLICY "Mentors can update own profile" ON mentor_profiles 
       FOR UPDATE USING (auth.uid() = user_id);''',
    '''CREATE POLICY "Users can create mentor profile" ON mentor_profiles 
       FOR INSERT WITH CHECK (auth.uid() = user_id);''',

    // Session policies
    '''CREATE POLICY "Users can view own sessions" ON mentoring_sessions 
       FOR SELECT USING (auth.uid() = student_id OR 
                        auth.uid() IN (SELECT user_id FROM mentor_profiles WHERE id = mentor_id));''',
    '''CREATE POLICY "Students can create sessions" ON mentoring_sessions 
       FOR INSERT WITH CHECK (auth.uid() = student_id);''',
    '''CREATE POLICY "Participants can update sessions" ON mentoring_sessions 
       FOR UPDATE USING (auth.uid() = student_id OR 
                        auth.uid() IN (SELECT user_id FROM mentor_profiles WHERE id = mentor_id));''',

    // Messages policies
    '''CREATE POLICY "Users can view own messages" ON messages 
       FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);''',
    '''CREATE POLICY "Users can send messages" ON messages 
       FOR INSERT WITH CHECK (auth.uid() = sender_id);''',
    '''CREATE POLICY "Users can update own messages" ON messages 
       FOR UPDATE USING (auth.uid() = sender_id);''',

    // Notifications policies
    '''CREATE POLICY "Users can view own notifications" ON notifications 
       FOR SELECT USING (auth.uid() = user_id);''',
    '''CREATE POLICY "Users can update own notifications" ON notifications 
       FOR UPDATE USING (auth.uid() = user_id);''',
  ];

  /// Database functions
  static const String updateTimestampFunction = '''
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS \$\$
    BEGIN
        NEW.updated_at = TIMEZONE('utc'::text, NOW());
        RETURN NEW;
    END;
    \$\$ language 'plpgsql';
  ''';

  /// Triggers for updating timestamps
  static const List<String> createTriggers = [
    '''CREATE TRIGGER update_user_profiles_updated_at 
       BEFORE UPDATE ON user_profiles 
       FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();''',
    '''CREATE TRIGGER update_mentor_profiles_updated_at 
       BEFORE UPDATE ON mentor_profiles 
       FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();''',
    '''CREATE TRIGGER update_mentoring_sessions_updated_at 
       BEFORE UPDATE ON mentoring_sessions 
       FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();''',
  ];
}
