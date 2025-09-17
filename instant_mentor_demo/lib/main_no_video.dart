import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/debug/provider_observer.dart';
import 'core/network/network_client.dart';
import 'core/routing/app_router.dart';
import 'core/services/supabase_service.dart';
// Commenting out video call to avoid WebRTC issues on web
// import 'examples/video_call_example.dart';
// import 'features/common/widgets/error_handler_widget.dart';
// import 'features/realtime/realtime_communication_overlay.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app configuration and network client
  await _initializeApp();

  runApp(
    ProviderScope(
      observers: [
        DebugProviderObserver(),
        MemoryLeakObserver(),
      ],
      child: const MyApp(),
    ),
  );
}

/// Initialize application dependencies
Future<void> _initializeApp() async {
  try {
    // Load environment variables first
    await dotenv.load();

    // Initialize app configuration from .env
    await AppConfig.initialize();

    // Initialize Supabase
    await SupabaseService.initialize();

    // Initialize network client with configuration
    NetworkClient.initialize();

    // Only show essential initialization message
    debugPrint('✅ InstantMentor initialized successfully');
  } catch (e, stackTrace) {
    // Enhanced error handling for initialization failures
    debugPrint('❌ Initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');

    // Continue with app launch even if some services fail
    // This ensures the app remains functional in degraded mode
    debugPrint('⚠️  Continuing with reduced functionality...');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'InstantMentor',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB), // Original blue color
          secondary: Color(0xFF0B1C49), // Deep Navy
          onSecondary: Color(0xFFFFFFFF),
          onSurface: Color(0xFF0B1C49),
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF8FAFC), // Light gray background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1C49),
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: const Color(0xFF0B1C49).withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB), // Original blue color
            foregroundColor: const Color(0xFFFFFFFF), // White text
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
