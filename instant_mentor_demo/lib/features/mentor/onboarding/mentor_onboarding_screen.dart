import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';

// Provider to track onboarding completion
final mentorOnboardingProvider =
    StateNotifierProvider<MentorOnboardingNotifier, MentorOnboardingState>(
        (ref) {
  return MentorOnboardingNotifier();
});

class MentorOnboardingState {
  final bool isLoading;
  final bool isCompleted;
  final String? error;
  final Map<String, dynamic> formData;

  const MentorOnboardingState({
    this.isLoading = false,
    this.isCompleted = false,
    this.error,
    this.formData = const {},
  });

  MentorOnboardingState copyWith({
    bool? isLoading,
    bool? isCompleted,
    String? error,
    Map<String, dynamic>? formData,
  }) {
    return MentorOnboardingState(
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error,
      formData: formData ?? this.formData,
    );
  }
}

class MentorOnboardingNotifier extends StateNotifier<MentorOnboardingState> {
  MentorOnboardingNotifier() : super(const MentorOnboardingState());

  void updateFormData(String key, dynamic value) {
    final newFormData = {...state.formData, key: value};
    state = state.copyWith(formData: newFormData);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(isLoading: true);

    try {
      // Save mentor profile data to Supabase
      await SupabaseService.instance.upsertUserProfile(
        profileData: {
          'teaching_subjects': state.formData['subjects'] ?? [],
          'experience_years': state.formData['experience'] ?? 0,
          'bio': state.formData['bio'] ?? '',
          'qualifications': state.formData['qualifications'] ?? '',
          'phone': state.formData['phone'] ?? '',
          'onboarding_completed': true,
          'profile_completed_at': DateTime.now().toIso8601String(),
        },
      );

      state = state.copyWith(
        isLoading: false,
        isCompleted: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

class MentorOnboardingScreen extends ConsumerStatefulWidget {
  const MentorOnboardingScreen({super.key});

  @override
  ConsumerState<MentorOnboardingScreen> createState() =>
      _MentorOnboardingScreenState();
}

class _MentorOnboardingScreenState
    extends ConsumerState<MentorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form controllers
  final _bioController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _phoneController = TextEditingController();

  // Form data
  final List<String> _selectedSubjects = [];
  int _experienceYears = 1;

  // Available subjects
  final List<String> _availableSubjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'English',
    'History',
    'Geography',
    'Economics',
    'Accounting',
    'Business Studies',
    'Psychology',
    'Art',
    'Music',
    'Other',
  ];

  @override
  void dispose() {
    _bioController.dispose();
    _qualificationsController.dispose();
    _phoneController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    // Update form data in provider
    final notifier = ref.read(mentorOnboardingProvider.notifier);
    notifier.updateFormData('subjects', _selectedSubjects);
    notifier.updateFormData('experience', _experienceYears);
    notifier.updateFormData('bio', _bioController.text.trim());
    notifier.updateFormData(
        'qualifications', _qualificationsController.text.trim());
    notifier.updateFormData('phone', _phoneController.text.trim());

    await notifier.completeOnboarding();

    final state = ref.read(mentorOnboardingProvider);
    if (state.isCompleted && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome! Your mentor profile is now complete.'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear the new mentor signup flag
      ref.read(authProvider.notifier).clearNewMentorSignupFlag();

      // Navigate to mentor home
      context.go('/mentor/home');
    } else if (state.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${state.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _skipOnboarding() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Onboarding?'),
        content: const Text(
          'You can complete your profile later in the settings, but having a complete profile will help students find and trust you more.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Setup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear the new mentor signup flag
              ref.read(authProvider.notifier).clearNewMentorSignupFlag();
              context.go('/mentor/home');
            },
            child: const Text('Skip for Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(mentorOnboardingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Mentor Profile'),
        backgroundColor: const Color(0xFF0B1C49),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _skipOnboarding,
            child: const Text(
              'Skip',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1C49),
              Color(0xFF1E3A8A),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress indicator
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 4,
                        decoration: BoxDecoration(
                          color: index <= _currentPage
                              ? Colors.white
                              : Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildSubjectsPage(),
                    _buildExperiencePage(),
                    _buildBioPage(),
                    _buildContactPage(),
                  ],
                ),
              ),

              // Navigation buttons
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: _previousPage,
                        child: const Text(
                          'Previous',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: onboardingState.isLoading ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0B1C49),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: onboardingState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_currentPage < 3 ? 'Next' : 'Complete'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What subjects do you teach?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select all subjects you can help students with',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSubjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject);
              return FilterChip(
                label: Text(subject),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSubjects.add(subject);
                    } else {
                      _selectedSubjects.remove(subject);
                    }
                  });
                },
                selectedColor: Colors.white.withOpacity(0.2),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                ),
                side: BorderSide(
                  color: isSelected ? Colors.white : Colors.white30,
                ),
              );
            }).toList(),
          ),
          if (_selectedSubjects.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please select at least one subject to continue',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExperiencePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How many years of teaching experience do you have?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This helps students understand your expertise level',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: Column(
              children: [
                Text(
                  '$_experienceYears',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _experienceYears == 1 ? 'Year' : 'Years',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Slider(
                  value: _experienceYears.toDouble(),
                  max: 30,
                  divisions: 30,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                  onChanged: (value) {
                    setState(() {
                      _experienceYears = value.round();
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '30+ Years',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Don\'t worry if you\'re just starting out! Even new tutors can be incredibly helpful to students.',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell us about yourself',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share your teaching philosophy, specializations, or what makes you unique',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _bioController,
            maxLines: 6,
            maxLength: 500,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please write a brief bio';
              }
              if (value.trim().length < 50) {
                return 'Please write at least 50 characters';
              }
              return null;
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Bio',
              hintText:
                  'e.g., I\'m passionate about making complex concepts simple and enjoyable. I specialize in helping students overcome math anxiety...',
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _qualificationsController,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Qualifications (Optional)',
              hintText: 'e.g., M.Sc. Mathematics, B.Ed., 5 years at ABC School',
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your phone number for better communication with students',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                // Basic phone validation
                final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
                if (!phoneRegex.hasMatch(value.trim())) {
                  return 'Please enter a valid phone number';
                }
              }
              return null;
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Phone Number (Optional)',
              hintText: '+1 (555) 123-4567',
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'You\'re almost done!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Complete your profile to start connecting with students and earning money as a mentor.',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
