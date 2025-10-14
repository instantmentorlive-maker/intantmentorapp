import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';

// Provider to track student onboarding completion
final studentOnboardingProvider =
    StateNotifierProvider<StudentOnboardingNotifier, StudentOnboardingState>(
        (ref) {
  return StudentOnboardingNotifier();
});

class StudentOnboardingState {
  final bool isLoading;
  final bool isCompleted;
  final String? error;
  final Map<String, dynamic> formData;

  const StudentOnboardingState({
    this.isLoading = false,
    this.isCompleted = false,
    this.error,
    this.formData = const {},
  });

  StudentOnboardingState copyWith({
    bool? isLoading,
    bool? isCompleted,
    String? error,
    Map<String, dynamic>? formData,
  }) {
    return StudentOnboardingState(
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error,
      formData: formData ?? this.formData,
    );
  }
}

class StudentOnboardingNotifier extends StateNotifier<StudentOnboardingState> {
  StudentOnboardingNotifier() : super(const StudentOnboardingState());

  void updateFormData(String key, dynamic value) {
    final newFormData = {...state.formData, key: value};
    state = state.copyWith(formData: newFormData);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        // Persist student onboarding preferences into user_profiles
        final subjects =
            (state.formData['interested_subjects'] as List<String>?) ??
                <String>[];
        final classGrade = (state.formData['class_grade'] as String?) ?? '';
        final targetExam = (state.formData['target_exam'] as String?) ?? 'None';
        final bio = (state.formData['bio'] as String?)?.trim() ?? '';

        // Merge into preferences JSONB with explicit keys
        final preferences = <String, dynamic>{
          'interested_subjects': subjects,
          'class_grade': classGrade,
          'target_exam': targetExam,
        };

        // Normalize values for top-level columns expected by Profile screen
        String normalizedGrade = classGrade;
        // Map common variants to the dropdown options used in profile screen
        const gradeMap = {
          'Grade 9': '9th Grade',
          'Grade 10': '10th Grade',
          'Grade 11': '11th Grade',
          'Grade 12': '12th Grade',
        };
        if (gradeMap.containsKey(normalizedGrade)) {
          normalizedGrade = gradeMap[normalizedGrade]!;
        }

        String normalizedExam = targetExam;
        // Map JEE variants to 'JEE' used in profile screen options
        if (normalizedExam == 'JEE Main' || normalizedExam == 'JEE Advanced') {
          normalizedExam = 'JEE';
        }

        await SupabaseService.instance.upsertUserProfile(
          profileData: {
            if (bio.isNotEmpty) 'bio': bio,
            'preferences': preferences,
            'onboarding_completed': true,
            // Also write to top-level fields so Profile screen reflects updates immediately
            if (normalizedGrade.isNotEmpty) 'grade': normalizedGrade,
            if (subjects.isNotEmpty) 'subjects': subjects,
            if (normalizedExam.isNotEmpty) 'exam_target': normalizedExam,
          },
        );
      } else {
        // Preview mode
        await Future.delayed(const Duration(milliseconds: 1200));
      }

      state = state.copyWith(isLoading: false, isCompleted: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

class StudentOnboardingScreen extends ConsumerStatefulWidget {
  const StudentOnboardingScreen({super.key});

  @override
  ConsumerState<StudentOnboardingScreen> createState() =>
      _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState
    extends ConsumerState<StudentOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form controllers
  final _bioController = TextEditingController();
  // For target exam custom entry when "Other" is selected
  final _customExamController = TextEditingController();

  // Form data
  final List<String> _selectedInterests = [];
  String _selectedGrade = 'Grade 10';
  String _selectedTargetExam = 'None';

  final List<String> _availableInterests = const [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'English',
    'History',
    'Economics',
    'Programming',
    'Test Prep',
    'Interview Prep',
    'Other',
  ];

  final List<String> _grades = const [
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
    'Undergraduate',
    'Graduate',
    'Other',
  ];

  final List<String> _targetExams = const [
    'None',
    'SAT',
    'ACT',
    'JEE Main',
    'JEE Advanced',
    'NEET',
    'GRE',
    'GMAT',
    'IELTS',
    'TOEFL',
    'Other',
  ];

  @override
  void dispose() {
    _bioController.dispose();
    _customExamController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && _selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one interest to continue'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentPage < 3) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(studentOnboardingProvider.notifier);
    notifier.updateFormData('interested_subjects', _selectedInterests);
    notifier.updateFormData('class_grade', _selectedGrade);
    final targetExam = _selectedTargetExam == 'Other'
        ? _customExamController.text.trim()
        : _selectedTargetExam;
    notifier.updateFormData('target_exam', targetExam);
    notifier.updateFormData('bio', _bioController.text.trim());

    await notifier.completeOnboarding();

    final state = ref.read(studentOnboardingProvider);
    if (!mounted) return;

    if (state.isCompleted) {
      // Clear the new-student flag and navigate
      ref.read(authProvider.notifier).clearNewStudentSignupFlag();

      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Welcome! Your learning preferences are saved.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) context.go('/student/home');
        });
      } else {
        // Preview mode dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Preview Complete!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'This is a preview of the student onboarding process.'),
                const SizedBox(height: 12),
                const Text('Interested Subjects:'),
                Text('• ${_selectedInterests.join('\n• ')}'),
                const SizedBox(height: 8),
                Text('Class/Grade: $_selectedGrade'),
                const SizedBox(height: 8),
                Text(
                    'Target Exam: ${_selectedTargetExam == 'Other' ? _customExamController.text.trim() : _selectedTargetExam}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _pageController.animateToPage(0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                },
                child: const Text('Start Over'),
              ),
              ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close')),
            ],
          ),
        );
      }
    } else if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${state.error}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _skipOnboarding() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Onboarding?'),
        content: const Text(
            'You can update your preferences later in More > Settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Setup')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).clearNewStudentSignupFlag();
              context.go('/student/home');
            },
            child: const Text('Skip for Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(studentOnboardingProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Learning Profile'),
        backgroundColor: const Color(0xFF0B1C49),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _skipOnboarding,
            child: const Text('Skip', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1C49), Color(0xFF1E3A8A)],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress
              Padding(
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
              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (p) => setState(() => _currentPage = p),
                  children: [
                    _buildInterestsPage(),
                    _buildClassGradePage(),
                    _buildTargetExamPage(),
                    _buildAboutYourselfPage(),
                  ],
                ),
              ),
              // Nav buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                          onPressed: _previousPage,
                          child: const Text('Previous',
                              style: TextStyle(color: Colors.white70)))
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: onboardingState.isLoading ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0B1C49),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child: onboardingState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
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

  Widget _buildInterestsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What do you want to learn?',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 8),
          const Text('Select all topics you are interested in',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInterests.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return FilterChip(
                label: Text(
                  interest,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                },
                backgroundColor: isSelected
                    ? const Color(0xFF1E3A8A)
                    : Colors.white.withOpacity(0.9),
                selectedColor: const Color(0xFF1E3A8A),
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFF1E3A8A).withOpacity(0.3),
                ),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          if (_selectedInterests.isEmpty)
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
                          'Please select at least one interest to continue',
                          style: TextStyle(color: Colors.orange))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassGradePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What is your class/grade?',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 8),
          const Text('This helps us match you with the right mentors',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: Column(
              children: _grades.map((grade) {
                return RadioListTile<String>(
                  value: grade,
                  groupValue: _selectedGrade,
                  onChanged: (v) => setState(() => _selectedGrade = v!),
                  title:
                      Text(grade, style: const TextStyle(color: Colors.white)),
                  activeColor: Colors.white,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetExamPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What is your target exam?',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 8),
          const Text('Choose one (or select Other to type your exam)',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _targetExams.map((exam) {
              final isSelected = _selectedTargetExam == exam;
              return ChoiceChip(
                label: Text(
                  exam,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedTargetExam = exam;
                    if (exam != 'Other') {
                      _customExamController.clear();
                    }
                  });
                },
                backgroundColor: isSelected
                    ? const Color(0xFF1E3A8A)
                    : Colors.white.withOpacity(0.9),
                selectedColor: const Color(0xFF1E3A8A),
                pressElevation: 2,
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFF1E3A8A).withOpacity(0.3),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_selectedTargetExam == 'Other')
            TextFormField(
              controller: _customExamController,
              maxLength: 80,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                  'Enter exam name', 'e.g., State Board, CBSE, ICSE, etc.'),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutYourselfPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About Yourself',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 8),
          const Text(
              'Share anything about your learning style or preferences (optional).',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _bioController,
            maxLines: 5,
            maxLength: 500,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('About you (optional)',
                'e.g., I prefer evening sessions and visual explanations'),
          ),
          const SizedBox(height: 24),
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
                    Text('You\'re almost done!',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                    'We\'ll use your preferences to recommend the best mentors for you.',
                    style: TextStyle(color: Colors.green)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
    );
  }
}
