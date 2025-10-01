import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/debug/provider_observer.dart';
import 'core/logging/app_logger.dart';
import 'core/network/network_client.dart';
import 'core/providers/websocket_provider.dart';
import 'core/routing/routing.dart';
import 'core/services/payment_service.dart';
import 'core/services/supabase_service.dart';
import 'core/widgets/global_back_button_handler.dart';
import 'examples/video_call_example.dart';
import 'features/common/widgets/error_handler_widget.dart';
import 'features/realtime/realtime_communication_overlay.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app configuration and network client
  await _initializeApp();

  const bool kDisableObserversForWebDebug = true; // set false to restore

  runApp(
    ProviderScope(
      observers: kDisableObserversForWebDebug
          ? const []
          : [
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

    // Initialize Payment Service (Stripe)
    try {
      await PaymentService.initialize();
      AppLogger.info('Payment service initialized successfully');
    } catch (e) {
      AppLogger.error(
          'Payment service initialization failed, continuing without payment features',
          e);
    }

    // Initialize network client with configuration
    NetworkClient.initialize();

    // Only show essential initialization message
    AppLogger.info('InstantMentor initialized successfully');
  } catch (e, stackTrace) {
    AppLogger.error('App initialization failed', e, stackTrace);
    // Continue execution - app can still work with default settings
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    // Initialize WebSocket connection management
    ref.watch(webSocketConnectionManagerProvider);

    // MaterialApp must be the ancestor providing Directionality.
    // Wrap MaterialApp with overlays that depend on Directionality by
    // placing RealtimeCommunicationOverlay ABOVE its navigator via builder.
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
          shadowColor: const Color(0xFF0B1C49).withValues(alpha: 0.1),
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
      builder: (context, child) {
        // Wrap with GlobalBackButtonHandler to handle video call minimization
        return GlobalBackButtonHandler(
          child: ErrorHandlerWidget(
            child: RealtimeCommunicationOverlay(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  int _currentIndex = 0;
  final bool _isStudent = true;

  final List<String> _studentTabs = [
    'Home',
    'Book Session',
    'Chat',
    'Progress',
    'Wallet'
  ];
  final List<String> _mentorTabs = [
    'Dashboard',
    'Requests',
    'Chat',
    'Earnings',
    'Availability'
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _isStudent ? _studentTabs : _mentorTabs;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${_isStudent ? 'Student' : 'Mentor'} - ${tabs[_currentIndex]}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreMenu(context),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: tabs
            .map((tab) => BottomNavigationBarItem(
                  icon: Icon(_getIconForTab(tab)),
                  label: tab,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isStudent) {
      return _buildStudentBody();
    } else {
      return _buildMentorBody();
    }
  }

  Widget _buildStudentBody() {
    switch (_currentIndex) {
      case 0:
        return _buildStudentHome();
      case 1:
        return _buildBookSession();
      case 2:
        return _buildChat('Student Chat');
      case 3:
        return _buildProgress();
      case 4:
        return _buildWallet();
      default:
        return _buildComingSoon();
    }
  }

  Widget _buildMentorBody() {
    switch (_currentIndex) {
      case 0:
        return _buildMentorHome();
      case 1:
        return _buildRequests();
      case 2:
        return _buildChat('Mentor Chat');
      case 3:
        return _buildEarnings();
      case 4:
        return _buildAvailability();
      default:
        return _buildComingSoon();
    }
  }

  Widget _buildStudentHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, Alex!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ready to learn something new today?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Text('Quick Actions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _QuickActionCard(
                      icon: Icons.book_online,
                      title: 'Book Session',
                      color: Colors.blue,
                      onTap: () => setState(() => _currentIndex = 1))),
              const SizedBox(width: 12),
              Expanded(
                  child: _QuickActionCard(
                      icon: Icons.help_outline,
                      title: 'Ask Doubt',
                      color: Colors.orange,
                      onTap: () => _showComingSoon())),
            ],
          ),

          const SizedBox(height: 24),

          // Upcoming Sessions
          Text('Upcoming Sessions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Card(
            child: Column(
              children: [
                _UpcomingSessionTile(
                  mentorName: 'Dr. Sarah Smith',
                  subject: 'Mathematics',
                  time: 'Today, 3:00 PM',
                  duration: '60 min',
                ),
                Divider(height: 1),
                _UpcomingSessionTile(
                  mentorName: 'Prof. Raj Kumar',
                  subject: 'Physics',
                  time: 'Tomorrow, 10:00 AM',
                  duration: '45 min',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Top Mentors - Made more compact
          Text('Top Mentors',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180, // Reduced from 200 to make it more compact
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                final mentors = [
                  'Dr. Sarah Smith',
                  'Prof. Raj Kumar',
                  'Dr. Priya Sharma',
                  'Mr. Vikash Singh',
                  'Dr. Anjali Gupta'
                ];
                final subjects = [
                  'Mathematics',
                  'Physics',
                  'Chemistry',
                  'English',
                  'Biology'
                ];
                final ratings = [4.8, 4.9, 4.7, 4.6, 4.9];
                final prices = [50, 45, 40, 35, 55];
                return _MentorCard(
                  name: mentors[index],
                  subject: subjects[index],
                  rating: ratings[index],
                  price: prices[index],
                );
              },
            ),
          ),

          // Add some bottom padding to prevent overlap with floating widgets
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMentorHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Dr. Sarah!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ready to help students today?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.9),
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Status changed to Available'),
                              backgroundColor: Colors.green),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Go Available'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Stats
          Text('Today\'s Overview',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                  child: _StatCard(
                      title: 'Sessions',
                      value: '5',
                      icon: Icons.school,
                      color: Colors.blue)),
              SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      title: 'Earnings',
                      value: '\$250',
                      icon: Icons.monetization_on,
                      color: Colors.green)),
              SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      title: 'Rating',
                      value: '4.8',
                      icon: Icons.star,
                      color: Colors.amber)),
            ],
          ),

          const SizedBox(height: 24),

          // Upcoming Sessions
          Text('Upcoming Sessions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Card(
            child: Column(
              children: [
                _MentorSessionTile(
                  studentName: 'Alex Johnson',
                  subject: 'Mathematics',
                  time: 'In 30 minutes',
                  duration: '60 min',
                  amount: '\$50',
                ),
                Divider(height: 1),
                _MentorSessionTile(
                  studentName: 'Maria Garcia',
                  subject: 'Mathematics',
                  time: '2:00 PM',
                  duration: '45 min',
                  amount: '\$37.5',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookSession() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filters',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Exam',
                            prefixIcon: Icon(Icons.school),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'JEE', child: Text('JEE')),
                            DropdownMenuItem(
                                value: 'NEET', child: Text('NEET')),
                            DropdownMenuItem(
                                value: 'IELTS', child: Text('IELTS')),
                          ],
                          onChanged: (value) {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            prefixIcon: Icon(Icons.book),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'Math', child: Text('Mathematics')),
                            DropdownMenuItem(
                                value: 'Physics', child: Text('Physics')),
                            DropdownMenuItem(
                                value: 'Chemistry', child: Text('Chemistry')),
                          ],
                          onChanged: (value) {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Mentors List
          Text('Available Mentors',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ...List.generate(5, (index) {
            final mentors = [
              'Dr. Sarah Smith',
              'Prof. Raj Kumar',
              'Dr. Priya Sharma',
              'Mr. Vikash Singh',
              'Dr. Anjali Gupta'
            ];
            final subjects = [
              'Mathematics',
              'Physics',
              'Chemistry',
              'English',
              'Biology'
            ];
            final ratings = [4.8, 4.9, 4.7, 4.6, 4.9];
            final prices = [50, 45, 40, 35, 55];
            final available = [true, true, false, true, true];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child:
                      Text(mentors[index].split(' ').map((n) => n[0]).join()),
                ),
                title: Text(mentors[index]),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${subjects[index]} • JEE'),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber[600]),
                        Text(' ${ratings[index]} • '),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: available[index]
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            available[index] ? 'Available' : 'Busy',
                            style: TextStyle(
                              color:
                                  available[index] ? Colors.green : Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('\$${prices[index]}/hr',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 4),
                    ElevatedButton(
                      onPressed: available[index]
                          ? () =>
                              _showBookingDialog(mentors[index], prices[index])
                          : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(60, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Book', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChat(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Real-time chat functionality\nwill be implemented here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showComingSoon,
            icon: const Icon(Icons.add),
            label: const Text('Start New Chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress Overview',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                  child: _ProgressCard(
                      title: 'Completed', value: 15, color: Colors.green)),
              SizedBox(width: 12),
              Expanded(
                  child: _ProgressCard(
                      title: 'In Progress', value: 5, color: Colors.orange)),
              SizedBox(width: 12),
              Expanded(
                  child: _ProgressCard(
                      title: 'Pending', value: 8, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Subject Progress',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...['Mathematics', 'Physics', 'Chemistry'].map((subject) {
            final progress = subject == 'Mathematics'
                ? 0.75
                : subject == 'Physics'
                    ? 0.60
                    : 0.45;
            final sessions = subject == 'Mathematics'
                ? 12
                : subject == 'Physics'
                    ? 8
                    : 6;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(subject,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${(progress * 100).toInt()}%'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text('Sessions Completed: $sessions',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWallet() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wallet Balance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.9))),
                  const SizedBox(height: 8),
                  Text('\$125.50',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showAddCreditsDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text('Add Credits'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text('Recent Transactions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          const Card(
            child: Column(
              children: [
                _TransactionTile(
                    title: 'Session with Dr. Sarah Smith',
                    subtitle: 'Mathematics • 1 hour',
                    amount: -50.0,
                    date: 'Today, 3:00 PM'),
                Divider(height: 1),
                _TransactionTile(
                    title: 'Wallet Top-up',
                    subtitle: 'Payment via Credit Card',
                    amount: 100.0,
                    date: 'Yesterday, 2:30 PM'),
                Divider(height: 1),
                _TransactionTile(
                    title: 'Session with Prof. Raj Kumar',
                    subtitle: 'Physics • 45 minutes',
                    amount: -37.5,
                    date: '2 days ago'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequests() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Incoming Requests',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...List.generate(3, (index) {
            final students = ['Alex Johnson', 'Maria Garcia', 'James Wilson'];
            final subjects = ['Mathematics', 'Physics', 'Mathematics'];
            final times = ['Now', '30 min', '1 hour'];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child:
                      Text(students[index].split(' ').map((n) => n[0]).join()),
                ),
                title: Text('${subjects[index]} Session'),
                subtitle:
                    Text('${students[index]} • Requested ${times[index]} ago'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          _showRequestResponse(students[index], false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () =>
                          _showRequestResponse(students[index], true),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (true) // Show empty state when no requests
            const Center(
              child: Column(
                children: [
                  SizedBox(height: 50),
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No new requests',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEarnings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Earnings Overview
          const Row(
            children: [
              Expanded(
                  child: _EarningsCard(
                      title: 'Today', amount: '\$250', color: Colors.green)),
              SizedBox(width: 12),
              Expanded(
                  child: _EarningsCard(
                      title: 'This Week',
                      amount: '\$1,250',
                      color: Colors.blue)),
              SizedBox(width: 12),
              Expanded(
                  child: _EarningsCard(
                      title: 'This Month',
                      amount: '\$4,800',
                      color: Colors.purple)),
            ],
          ),

          const SizedBox(height: 24),
          Text('Recent Earnings',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          const Card(
            child: Column(
              children: [
                _TransactionTile(
                    title: 'Session with Alex Johnson',
                    subtitle: 'Mathematics • 1 hour',
                    amount: 50.0,
                    date: 'Today, 2:00 PM'),
                Divider(height: 1),
                _TransactionTile(
                    title: 'Session with Maria Garcia',
                    subtitle: 'Mathematics • 45 min',
                    amount: 37.5,
                    date: 'Today, 10:00 AM'),
                Divider(height: 1),
                _TransactionTile(
                    title: 'Session with James Wilson',
                    subtitle: 'Mathematics • 1 hour',
                    amount: 50.0,
                    date: 'Yesterday, 4:00 PM'),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showComingSoon,
              icon: const Icon(Icons.account_balance),
              label: const Text('Withdraw Earnings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailability() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Status',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 32),
                              SizedBox(height: 8),
                              Text('Available',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.do_not_disturb,
                                  color: Colors.grey, size: 32),
                              SizedBox(height: 8),
                              Text('Busy',
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text('Weekly Schedule',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ...[
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday'
          ].map((day) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(day),
                subtitle: const Text('9:00 AM - 6:00 PM'),
                trailing: Switch(
                  value: day != 'Sunday',
                  onChanged: (value) => _showComingSoon(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Coming Soon',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          SizedBox(height: 8),
          Text('This feature will be available soon!',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  IconData _getIconForTab(String tab) {
    switch (tab) {
      case 'Home':
        return Icons.home;
      case 'Dashboard':
        return Icons.dashboard;
      case 'Book Session':
        return Icons.book_online;
      case 'Chat':
        return Icons.chat;
      case 'Progress':
        return Icons.trending_up;
      case 'Wallet':
        return Icons.account_balance_wallet;
      case 'Requests':
        return Icons.notifications_active;
      case 'Earnings':
        return Icons.monetization_on;
      case 'Availability':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  void _showMoreMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('More Options - ${_isStudent ? 'Student' : 'Mentor'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.of(context).pop();
                _showComingSoon();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                _showComingSoon();
              },
            ),
            ListTile(
              leading: const Icon(Icons.support),
              title: const Text('Support & Help'),
              onTap: () {
                Navigator.of(context).pop();
                _showComingSoon();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_call),
              title: const Text('Video Call Demo'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToVideoCallDemo();
              },
            ),
            if (_isStudent) ...[
              ListTile(
                leading: const Icon(Icons.leaderboard),
                title: const Text('Leaderboard'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showComingSoon();
                },
              ),
              ListTile(
                leading: const Icon(Icons.note),
                title: const Text('Session Notes'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showComingSoon();
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Profile Management'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showComingSoon();
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('Performance Analytics'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showComingSoon();
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Coming soon! This feature will be available in the next update.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToVideoCallDemo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const VideoCallExample(),
      ),
    );
  }

  void _showBookingDialog(String mentorName, int price) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Book Session with $mentorName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate: \$$price/hour'),
            const SizedBox(height: 16),
            const Text('Select Duration:'),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Duration'),
              items: [
                DropdownMenuItem(
                    value: '30', child: Text('30 minutes - \$${price ~/ 2}')),
                DropdownMenuItem(value: '60', child: Text('1 hour - \$$price')),
                DropdownMenuItem(
                    value: '90',
                    child: Text('1.5 hours - \$${(price * 1.5).toInt()}')),
              ],
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Session booked with $mentorName!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Book Now'),
          ),
        ],
      ),
    );
  }

  void _showAddCreditsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Credits'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select amount to add:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [25, 50, 100, 200].map((amount) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('\$$amount added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text('\$$amount'),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRequestResponse(String studentName, bool accepted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${accepted ? 'Accepted' : 'Declined'} request from $studentName'),
        backgroundColor: accepted ? Colors.green : Colors.red,
      ),
    );
  }
}

// Custom Widgets
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentorCard extends StatelessWidget {
  final String name;
  final String subject;
  final double rating;
  final int price;

  const _MentorCard(
      {required this.name,
      required this.subject,
      required this.rating,
      required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(name.split(' ').map((n) => n[0]).join()),
              ),
              const SizedBox(height: 8),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(subject,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber[600]),
                  const SizedBox(width: 2),
                  Text('$rating', style: const TextStyle(fontSize: 12)),
                ],
              ),
              const Spacer(),
              Text('\$$price/hr',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;

  const _ProgressCard(
      {required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;

  const _EarningsCard(
      {required this.title, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(amount,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSessionTile extends StatelessWidget {
  final String mentorName;
  final String subject;
  final String time;
  final String duration;

  const _UpcomingSessionTile({
    required this.mentorName,
    required this.subject,
    required this.time,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(mentorName.split(' ').map((n) => n[0]).join()),
      ),
      title: Text('$subject with $mentorName'),
      subtitle: Text('$time • $duration'),
      trailing: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(minimumSize: const Size(60, 32)),
        child: const Text('Join', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _MentorSessionTile extends StatelessWidget {
  final String studentName;
  final String subject;
  final String time;
  final String duration;
  final String amount;

  const _MentorSessionTile({
    required this.studentName,
    required this.subject,
    required this.time,
    required this.duration,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(studentName.split(' ').map((n) => n[0]).join()),
      ),
      title: Text('$subject with $studentName'),
      subtitle: Text('$time • $duration • $amount'),
      trailing: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(minimumSize: const Size(60, 32)),
        child: const Text('Start', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final String date;

  const _TransactionTile(
      {required this.title,
      required this.subtitle,
      required this.amount,
      required this.date});

  @override
  Widget build(BuildContext context) {
    final isPositive = amount > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isPositive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        child: Icon(
          isPositive ? Icons.add : Icons.remove,
          color: isPositive ? Colors.green : Colors.red,
        ),
      ),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: Text(
        '${isPositive ? '+' : ''}\$${amount.abs().toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isPositive ? Colors.green : Colors.red,
          fontSize: 16,
        ),
      ),
    );
  }
}
