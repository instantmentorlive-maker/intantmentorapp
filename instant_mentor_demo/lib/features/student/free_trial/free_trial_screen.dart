import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Removed unused user_provider import

// Free trial state providers
final hasUsedFreeTrialProvider = StateProvider<bool>((ref) => false);
final selectedMentorProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);
final selectedSubjectProvider = StateProvider<String>((ref) => 'Mathematics');
final selectedDateProvider = StateProvider<DateTime?>((ref) => null);
final selectedTimeProvider = StateProvider<TimeOfDay?>((ref) => null);

class FreeTrialSessionScreen extends ConsumerStatefulWidget {
  const FreeTrialSessionScreen({super.key});

  @override
  ConsumerState<FreeTrialSessionScreen> createState() =>
      _FreeTrialSessionScreenState();
}

class _FreeTrialSessionScreenState extends ConsumerState<FreeTrialSessionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final PageController _pageController = PageController();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final hasUsedTrial = ref.watch(hasUsedFreeTrialProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Free Trial Session'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: hasUsedTrial ? _buildTrialUsedView() : _buildTrialFlow(),
    );
  }

  Widget _buildTrialUsedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Trial Already Used',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You have already used your free trial session. We hope you had a great experience!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.all(16),
                ),
                icon: const Icon(Icons.book_online, color: Colors.white),
                label: const Text('Book Paid Session',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialFlow() {
    return Column(
      children: [
        // Progress Indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepIndicator(
                      isActive: _currentStep >= 0,
                      isCompleted: _currentStep > 0),
                  _StepConnector(),
                  _StepIndicator(
                      isActive: _currentStep >= 1,
                      isCompleted: _currentStep > 1),
                  _StepConnector(),
                  _StepIndicator(
                      isActive: _currentStep >= 2,
                      isCompleted: _currentStep > 2),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _getStepTitle(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentStep = index),
            children: [
              _buildWelcomeStep(),
              _buildMentorSelectionStep(),
              _buildSchedulingStep(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school,
                  size: 80,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome to Your Free Trial!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Get a 30-minute session with our expert mentors absolutely free. No credit card required!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Benefits List
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What you get:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      _BenefitItem(
                          icon: Icons.timer,
                          text: '30 minutes of personalized tutoring'),
                      _BenefitItem(
                          icon: Icons.person_outline,
                          text: 'Choose from 50+ expert mentors'),
                      _BenefitItem(
                          icon: Icons.video_call,
                          text: 'HD video call with screen sharing'),
                      _BenefitItem(
                          icon: Icons.note, text: 'Session recording & notes'),
                      _BenefitItem(
                          icon: Icons.quiz,
                          text: 'Personalized learning assessment'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text('Get Started',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMentorSelectionStep() {
    final availableMentors = _getAvailableMentors();
    final selectedMentor = ref.watch(selectedMentorProvider);
    final selectedSubject = ref.watch(selectedSubjectProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Subject & Mentor',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your preferred subject and mentor for the session',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Subject Selection
          const Text('Subject',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSubject,
                isExpanded: true,
                items: [
                  'Mathematics',
                  'Physics',
                  'Chemistry',
                  'Biology',
                  'English',
                  'Computer Science'
                ]
                    .map((subject) => DropdownMenuItem(
                          value: subject,
                          child: Text(subject),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(selectedSubjectProvider.notifier).state = value;
                    ref.read(selectedMentorProvider.notifier).state =
                        null; // Reset mentor selection
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Mentor Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Available Mentors',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${availableMentors.length} mentors',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView.builder(
              itemCount: availableMentors.length,
              itemBuilder: (context, index) {
                final mentor = availableMentors[index];
                final isSelected = selectedMentor?['id'] == mentor['id'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected ? Colors.green.withOpacity(0.1) : null,
                  child: InkWell(
                    onTap: () => ref
                        .read(selectedMentorProvider.notifier)
                        .state = mentor,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.green.withOpacity(0.2),
                                child: Text(
                                  mentor['name']
                                      .toString()
                                      .split(' ')
                                      .map((n) => n[0])
                                      .join(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mentor['name'].toString(),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  mentor['qualification'].toString(),
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.star,
                                        color: Colors.amber[600], size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                        '${mentor['rating']} • ${mentor['experience']}'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mentor['expertise'].toString(),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Available',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: selectedMentor != null ? _nextStep : null,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Continue',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulingStep() {
    final selectedMentor = ref.watch(selectedMentorProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedTime = ref.watch(selectedTimeProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule Your Session',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a convenient time for your free trial session',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Selected Mentor Summary
              if (selectedMentor != null) ...[
                Card(
                  color: Colors.green.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green.withOpacity(0.2),
                          child: Text(selectedMentor['name']
                              .toString()
                              .split(' ')
                              .map((n) => n[0])
                              .join()),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedMentor['name'].toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${ref.watch(selectedSubjectProvider)} • ${selectedMentor['experience']}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Date Selection
              const Text('Select Date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final date = DateTime.now().add(Duration(days: index));
                    final isSelected = selectedDate?.day == date.day;

                    return GestureDetector(
                      onTap: () =>
                          ref.read(selectedDateProvider.notifier).state = date,
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getDayName(date),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Time Selection (scrollable section to avoid overflow)
              const Text('Select Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  // leave room for buttons at bottom
                  maxHeight: constraints.maxHeight * 0.40,
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _getAvailableTimeSlots().length,
                    itemBuilder: (context, index) {
                      final timeSlot = _getAvailableTimeSlots()[index];
                      final isSelected = selectedTime?.hour == timeSlot.hour &&
                          selectedTime?.minute == timeSlot.minute;
                      return GestureDetector(
                        onTap: () => ref
                            .read(selectedTimeProvider.notifier)
                            .state = timeSlot,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              timeSlot.format(context),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (selectedDate != null && selectedTime != null)
                          ? _bookTrialSession
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Book Free Session',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getAvailableMentors() {
    final selectedSubject = ref.watch(selectedSubjectProvider);

    return [
      {
        'id': '1',
        'name': 'Dr. Sarah Smith',
        'qualification': 'PhD Mathematics - MIT',
        'rating': 4.9,
        'experience': '8 years',
        'expertise': 'Calculus, Linear Algebra, Statistics',
        'subjects': ['Mathematics', 'Statistics'],
      },
      {
        'id': '2',
        'name': 'Prof. Raj Kumar',
        'qualification': 'PhD Physics - IIT Delhi',
        'rating': 4.8,
        'experience': '12 years',
        'expertise': 'Quantum Physics, Mechanics, Thermodynamics',
        'subjects': ['Physics', 'Mathematics'],
      },
      {
        'id': '3',
        'name': 'Dr. Priya Sharma',
        'qualification': 'PhD Chemistry - Delhi University',
        'rating': 4.7,
        'experience': '6 years',
        'expertise': 'Organic Chemistry, Biochemistry',
        'subjects': ['Chemistry', 'Biology'],
      },
      {
        'id': '4',
        'name': 'Mr. James Wilson',
        'qualification': 'MA English Literature - Oxford',
        'rating': 4.6,
        'experience': '5 years',
        'expertise': 'Literature, Grammar, Creative Writing',
        'subjects': ['English', 'Literature'],
      },
    ]
        .where(
            (mentor) => (mentor['subjects'] as List).contains(selectedSubject))
        .toList();
  }

  List<TimeOfDay> _getAvailableTimeSlots() {
    return [
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 10, minute: 0),
      const TimeOfDay(hour: 11, minute: 0),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 15, minute: 0),
      const TimeOfDay(hour: 16, minute: 0),
      const TimeOfDay(hour: 17, minute: 0),
      const TimeOfDay(hour: 18, minute: 0),
      const TimeOfDay(hour: 19, minute: 0),
    ];
  }

  String _getDayName(DateTime date) {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[date.weekday % 7];
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Welcome';
      case 1:
        return 'Choose Mentor';
      case 2:
        return 'Schedule Session';
      default:
        return '';
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _bookTrialSession() {
    final selectedMentor = ref.read(selectedMentorProvider);
    final selectedDate = ref.read(selectedDateProvider);
    final selectedTime = ref.read(selectedTimeProvider);
    final selectedSubject = ref.read(selectedSubjectProvider);

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Your Free Trial'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject: $selectedSubject'),
            Text('Mentor: ${selectedMentor!['name']}'),
            Text(
                'Date: ${selectedDate!.day}/${selectedDate.month}/${selectedDate.year}'),
            Text('Time: ${selectedTime!.format(context)}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a FREE 30-minute session. No charges will be applied.',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Mark trial as used
              ref.read(hasUsedFreeTrialProvider.notifier).state = true;

              Navigator.pop(context);
              _showSuccessDialog();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Booking',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Session Booked Successfully!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your free trial session has been confirmed. You will receive a confirmation email shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child:
                    const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

// Helper Widgets
class _StepIndicator extends StatelessWidget {
  final bool isActive;
  final bool isCompleted;

  const _StepIndicator({required this.isActive, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.white
            : (isActive ? Colors.white : Colors.white.withOpacity(0.3)),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isCompleted ? Icons.check : Icons.circle,
        color: isCompleted
            ? Colors.green
            : (isActive ? Colors.green : Colors.white.withOpacity(0.5)),
        size: 16,
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 2,
      color: Colors.white.withOpacity(0.3),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
