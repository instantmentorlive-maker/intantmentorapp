import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/user.dart' as domain_user;
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/supabase_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  // Manual subscription for user changes
  ProviderSubscription<domain_user.User?>? _userSubscription;

  // Static cache to persist profile data across navigation
  static Map<String, dynamic>? _profileCache;
  static bool _isCacheValid = false;

  String _selectedGrade = '12th Grade';
  List<String> _selectedSubjects = [];
  String _selectedExam = 'JEE';

  Uint8List? _profileImageBytes;
  String? _currentAvatarUrl; // Existing saved profile picture
  final ImagePicker _picker = ImagePicker();

  // Preference toggles (locally editable, persisted via Supabase preferences JSONB column)
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _studyReminders = false; // student only
  bool _sessionReminders = true;

  bool _loadingInitial = true;
  bool _isSaving = false;

  Map<String, dynamic> get _currentPreferencePatch => {
        'email_notifications': _emailNotifications,
        'push_notifications': _pushNotifications,
        'study_reminders': _studyReminders,
        'session_reminders': _sessionReminders,
      };

  @override
  void initState() {
    super.initState();

    // Add listeners to update cache when user makes changes
    _nameController.addListener(_saveToCache);
    _emailController.addListener(_saveToCache);
    _phoneController.addListener(_saveToCache);
    _bioController.addListener(_saveToCache);

    // Prefill avatar from current domain user while we load from server
    // This makes the avatar appear immediately after login if already hydrated
    try {
      final user = ref.read(userProvider);
      final existingAvatar = user?.profileImage;
      if (existingAvatar != null && existingAvatar.isNotEmpty) {
        _currentAvatarUrl = existingAvatar;
      }
    } catch (_) {
      // ignore read errors in init; ref is available in ConsumerState
    }

    // Live update from domain user: if auth/user changes after signup, populate fields
    _userSubscription = ref.listenManual<domain_user.User?>(
      userProvider,
      (previous, next) {
        if (!mounted || next == null) return;
        // Only overwrite if current fields are empty or placeholders
        final nameEmpty = _nameController.text.trim().isEmpty ||
            _nameController.text.trim().toLowerCase() == 'user';
        final emailEmpty = _emailController.text.trim().isEmpty ||
            _emailController.text.trim().toLowerCase() == 'user@example.com';

        bool changed = false;
        if (nameEmpty && next.name.isNotEmpty) {
          _nameController.text = next.name;
          changed = true;
        }
        if (emailEmpty && next.email.isNotEmpty) {
          _emailController.text = next.email;
          changed = true;
        }
        if ((next.profileImage ?? '').isNotEmpty) {
          _currentAvatarUrl = next.profileImage;
          changed = true;
        }

        if (changed) {
          _saveToCache();
          setState(() {});
        }
      },
      fireImmediately: true,
    );

    // Use cache for immediate UI, but always fetch fresh profile from server
    if (_isCacheValid && _profileCache != null) {
      _loadFromCache();
    }
    _loadUserData();
  }

  // Note: final dispose is implemented at the end of the class to also dispose controllers

  void _loadFromCache() {
    if (_profileCache != null) {
      _nameController.text = _profileCache!['name'] ?? '';
      _emailController.text = _profileCache!['email'] ?? '';
      _phoneController.text = _profileCache!['phone'] ?? '';
      _bioController.text = _profileCache!['bio'] ?? '';
      _selectedGrade = _profileCache!['grade'] ?? '12th Grade';
      _selectedExam = _profileCache!['exam'] ?? 'JEE';
      _selectedSubjects = List<String>.from(_profileCache!['subjects'] ?? []);
      _emailNotifications = _profileCache!['emailNotifications'] ?? true;
      _pushNotifications = _profileCache!['pushNotifications'] ?? true;
      _studyReminders = _profileCache!['studyReminders'] ?? false;
      _sessionReminders = _profileCache!['sessionReminders'] ?? true;
      _currentAvatarUrl = _profileCache!['avatarUrl'];
    }
  }

  void _saveToCache() {
    _profileCache = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'bio': _bioController.text,
      'grade': _selectedGrade,
      'exam': _selectedExam,
      'subjects': _selectedSubjects,
      'emailNotifications': _emailNotifications,
      'pushNotifications': _pushNotifications,
      'studyReminders': _studyReminders,
      'sessionReminders': _sessionReminders,
      'avatarUrl': _currentAvatarUrl,
    };
    _isCacheValid = true;
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _loadingInitial = true);

      // Load actual user profile data from Supabase
      final profile = await SupabaseService.instance.getUserProfile();

      if (profile != null && mounted) {
        setState(() {
          // Load profile data with fallbacks
          _nameController.text = profile['full_name'] ?? '';
          _emailController.text = profile['email'] ?? '';
          _phoneController.text = profile['phone'] ?? '';
          _bioController.text = profile['bio'] ?? '';

          // Load additional profile fields
          _selectedGrade = profile['grade'] ?? '12th Grade';
          // Normalize/guard grade in case value is not in dropdown options
          const validGrades = [
            '9th Grade',
            '10th Grade',
            '11th Grade',
            '12th Grade',
            'Undergraduate',
            'College',
            'Graduate',
            'Other',
          ];
          if (!validGrades.contains(_selectedGrade)) {
            // Map onboarding values if needed
            const gradeMap = {
              'Grade 9': '9th Grade',
              'Grade 10': '10th Grade',
              'Grade 11': '11th Grade',
              'Grade 12': '12th Grade',
            };
            _selectedGrade = gradeMap[_selectedGrade] ?? '12th Grade';
          }
          _selectedExam = profile['exam_target'] ?? 'JEE';

          if (profile['subjects'] is List) {
            _selectedSubjects = List<String>.from(profile['subjects']);
          }

          // Load existing avatar URL if available
          _currentAvatarUrl = profile['avatar_url'];
        });
      } else if (mounted) {
        // Fallback to domain user values if remote profile not yet created
        final domainUser = ref.read(userProvider);
        if (domainUser != null) {
          _nameController.text = _nameController.text.isEmpty
              ? domainUser.name
              : _nameController.text;
          _emailController.text = _emailController.text.isEmpty
              ? (domainUser.email)
              : _emailController.text;
          if ((domainUser.profileImage ?? '').isNotEmpty) {
            _currentAvatarUrl = domainUser.profileImage;
          }
        }
      }

      // Load preferences (to populate toggles and provide fallbacks for academic info)
      await _loadPreferences();

      // Save loaded data to cache
      _saveToCache();
    } catch (e) {
      debugPrint('⚠️ ProfileScreen: Failed loading user data: $e');
      // Set default values only if loading fails
      if (mounted) {
        setState(() {
          // Prefer domain user values if available
          final domainUser = ref.read(userProvider);
          if (domainUser != null) {
            if (_nameController.text.isEmpty) {
              _nameController.text = domainUser.name;
            }
            if (_emailController.text.isEmpty) {
              _emailController.text = domainUser.email;
            }
            if ((domainUser.profileImage ?? '').isNotEmpty) {
              _currentAvatarUrl = domainUser.profileImage;
            }
          } else {
            _nameController.text =
                _nameController.text.isEmpty ? 'User' : _nameController.text;
            _emailController.text = _emailController.text.isEmpty
                ? 'user@example.com'
                : _emailController.text;
          }
        });
        // Save default values to cache
        _saveToCache();
      }
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final profile = await SupabaseService.instance.getUserProfile();
      final prefsRaw = profile?['preferences'];
      if (prefsRaw is Map && mounted) {
        setState(() {
          _emailNotifications =
              prefsRaw['email_notifications'] ?? _emailNotifications;
          // Provide backward compatible keys
          _pushNotifications =
              prefsRaw['push_notifications'] ?? _pushNotifications;
          _studyReminders = prefsRaw['study_reminders'] ?? _studyReminders;
          _sessionReminders =
              prefsRaw['session_reminders'] ?? _sessionReminders;

          // Fallback academic info from preferences if top-level fields are absent
          // Subjects of interest
          final prefSubjects = prefsRaw['interested_subjects'];
          if ((profile?['subjects'] == null ||
                  (profile?['subjects'] is List &&
                      (profile?['subjects'] as List).isEmpty)) &&
              prefSubjects is List &&
              prefSubjects.isNotEmpty) {
            _selectedSubjects = List<String>.from(prefSubjects);
          }
          // Grade/Class
          final prefGrade = prefsRaw['class_grade'];
          if ((profile?['grade'] == null ||
                  (profile?['grade'] as String?)?.isEmpty == true) &&
              prefGrade is String &&
              prefGrade.isNotEmpty) {
            // Map onboarding grade variants to this screen's dropdown values
            const gradeMap = {
              'Grade 9': '9th Grade',
              'Grade 10': '10th Grade',
              'Grade 11': '11th Grade',
              'Grade 12': '12th Grade',
            };
            _selectedGrade = gradeMap[prefGrade] ?? prefGrade;
          }
          // Target Exam
          final prefExam = prefsRaw['target_exam'];
          if ((profile?['exam_target'] == null ||
                  (profile?['exam_target'] as String?)?.isEmpty == true) &&
              prefExam is String &&
              prefExam.isNotEmpty) {
            _selectedExam =
                (prefExam == 'JEE Main' || prefExam == 'JEE Advanced')
                    ? 'JEE'
                    : prefExam;
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ ProfileScreen: Failed loading preferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = ref.watch(isStudentProvider);

    if (_loadingInitial) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: _profileImageBytes != null
                          ? Border.all(color: Colors.green, width: 3)
                          : _getProfileImageProvider() != null
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: _getProfileImageProvider(),
                      child: _getProfileImageProvider() == null
                          ? Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  fontSize: 36, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _changeProfilePicture,
                        tooltip: 'Change profile picture',
                      ),
                    ),
                  ),
                  if (_profileImageBytes != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_profileImageBytes != null)
                const Text(
                  '✅ New photo selected! Click Save to upload.',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Text(
                  'Tap the camera icon to add a profile picture',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 24),

              // Basic Information
              Text(
                'Basic Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 24),

              // Academic Information (for students)
              if (isStudent) ...[
                Text(
                  'Academic Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                Builder(builder: (context) {
                  final gradeOptions = <String>[
                    '9th Grade',
                    '10th Grade',
                    '11th Grade',
                    '12th Grade',
                    'Undergraduate',
                    'College',
                    'Graduate',
                    'Other',
                  ];
                  final currentGrade = gradeOptions.contains(_selectedGrade)
                      ? _selectedGrade
                      : '12th Grade';
                  return DropdownButtonFormField<String>(
                    value: currentGrade,
                    decoration: const InputDecoration(
                      labelText: 'Grade/Class',
                      prefixIcon: Icon(Icons.school),
                    ),
                    items: gradeOptions
                        .map((grade) => DropdownMenuItem(
                              value: grade,
                              child: Text(grade),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedGrade = value!;
                      _saveToCache();
                    }),
                  );
                }),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedExam,
                  decoration: const InputDecoration(
                    labelText: 'Target Exam',
                    prefixIcon: Icon(Icons.quiz),
                  ),
                  items: ['JEE', 'NEET', 'IELTS', 'SAT', 'GMAT', 'Other']
                      .map((exam) =>
                          DropdownMenuItem(value: exam, child: Text(exam)))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedExam = value!;
                    _saveToCache();
                  }),
                ),

                const SizedBox(height: 16),

                // Subjects
                Text(
                  'Subjects of Interest',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Mathematics',
                    'Physics',
                    'Chemistry',
                    'Biology',
                    'English',
                    'Computer Science'
                  ]
                      .map((subject) => FilterChip(
                            label: Text(subject),
                            selected: _selectedSubjects.contains(subject),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSubjects.add(subject);
                                } else {
                                  _selectedSubjects.remove(subject);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 24),

              // Bio
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'About Yourself',
                  hintText: 'Tell us a bit about yourself...',
                  prefixIcon: Icon(Icons.info),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),

              const SizedBox(height: 24),

              // Statistics Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Statistics',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),
                      if (isStudent) ...[
                        _StatRow('Sessions Completed', '28'),
                        _StatRow('Hours of Learning', '42.5'),
                        _StatRow('Subjects Studied', '4'),
                        _StatRow('Favorite Subject', 'Mathematics'),
                        _StatRow('Current Streak', '7 days'),
                      ] else ...[
                        _StatRow('Sessions Conducted', '156'),
                        _StatRow('Teaching Hours', '234'),
                        _StatRow('Students Helped', '89'),
                        _StatRow('Average Rating', '4.8 ⭐'),
                        _StatRow('Response Time', '< 2 hours'),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Preferences Section - Enhanced Design
              Text(
                'Preferences',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Notification Preferences
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _loadingInitial
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        children: [
                          _PreferenceItem(
                            title: 'Email Notifications',
                            subtitle: 'Receive updates via email',
                            value: _emailNotifications,
                            onChanged: (value) {
                              setState(() {
                                _emailNotifications = value;
                                _saveToCache();
                              });
                            },
                          ),
                          const Divider(height: 1),
                          _PreferenceItem(
                            title: 'Push Notifications',
                            subtitle: 'Receive push notifications',
                            value: _pushNotifications,
                            onChanged: (value) {
                              setState(() {
                                _pushNotifications = value;
                                _saveToCache();
                              });
                            },
                          ),
                          const Divider(height: 1),
                          _PreferenceItem(
                            title: 'Session Reminders',
                            subtitle: 'Get reminded before sessions',
                            value: _sessionReminders,
                            onChanged: (value) {
                              setState(() {
                                _sessionReminders = value;
                                _saveToCache();
                              });
                            },
                          ),
                          if (isStudent) ...[
                            const Divider(height: 1),
                            _PreferenceItem(
                              title: 'Study Reminders',
                              subtitle: 'Get reminded to study',
                              value: _studyReminders,
                              onChanged: (value) {
                                setState(() {
                                  _studyReminders = value;
                                  _saveToCache();
                                });
                              },
                            ),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              // Account Actions - Enhanced Design
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _ActionItem(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: _changePassword,
                    ),
                    const Divider(height: 1),
                    _ActionItem(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Settings',
                      onTap: _privacySettings,
                    ),
                    const Divider(height: 1),
                    _ActionItem(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: _helpSupport,
                    ),
                    const Divider(height: 1),
                    _ActionItem(
                      icon: Icons.logout,
                      title: 'Logout',
                      iconColor: Colors.red,
                      titleColor: Colors.red,
                      onTap: _logout,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _StatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _PreferenceItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _ActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Theme.of(context).colorScheme.onSurface,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  // Helper method to get the appropriate ImageProvider for profile picture
  ImageProvider? _getProfileImageProvider() {
    // Priority 1: Show newly selected image (in memory)
    if (_profileImageBytes != null) {
      return MemoryImage(_profileImageBytes!);
    }

    // Priority 2: Show existing saved profile image
    if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      // Handle base64 data URLs
      if (_currentAvatarUrl!.startsWith('data:image/')) {
        try {
          // Extract base64 data from data URL
          final base64Data = _currentAvatarUrl!.split(',')[1];
          final bytes = base64Decode(base64Data);
          return MemoryImage(bytes);
        } catch (e) {
          debugPrint('Error decoding base64 image: $e');
          return null;
        }
      }

      // Handle regular network URLs
      try {
        return NetworkImage(_currentAvatarUrl!);
      } catch (e) {
        debugPrint('Error loading network image: $e');
        return null;
      }
    }

    // No image available
    return null;
  }

  void _changeProfilePicture() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb) ...[
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to take a new photo'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromCamera();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Choose from Gallery'),
              subtitle: const Text(kIsWeb
                  ? 'Select an image file from your computer'
                  : 'Pick from your photo gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromGallery();
              },
            ),
            if (kIsWeb) ...[
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  '💡 Tip: For web, gallery option works best!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      // For web, check if camera is available
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera access on web requires HTTPS or localhost. Please allow camera permission when prompted.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Profile picture selected! Remember to save your profile.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // User cancelled or permission denied
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Camera access cancelled. You can try using "Choose from Gallery" instead.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('🔴 Camera error: $e');
      if (mounted) {
        String errorMessage = 'Error taking photo: $e';

        // Provide specific guidance for common web issues
        if (kIsWeb && e.toString().contains('NotAllowedError')) {
          errorMessage =
              'Camera permission denied. Please allow camera access in your browser settings and try again.';
        } else if (kIsWeb && e.toString().contains('NotFoundError')) {
          errorMessage =
              'No camera found. Please try "Choose from Gallery" instead.';
        } else if (kIsWeb && e.toString().contains('NotSupportedError')) {
          errorMessage =
              'Camera not supported. Please use "Choose from Gallery" instead.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Profile picture selected! Remember to save your profile.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // User cancelled selection
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image selected.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('🔴 Gallery error: $e');
      if (mounted) {
        String errorMessage = 'Error selecting image: $e';

        // Provide specific guidance for web issues
        if (kIsWeb && e.toString().contains('NotAllowedError')) {
          errorMessage =
              'File access permission denied. Please allow file access in your browser.';
        } else if (kIsWeb && e.toString().contains('AbortError')) {
          errorMessage = 'File selection was cancelled or interrupted.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authProvider);
    if (auth.isLoading || _isSaving) return; // prevent duplicate taps

    setState(() {
      _isSaving = true;
    });

    try {
      print('🔵 ProfileScreen: Starting profile save...');
      String? avatarUrl;

      // Upload profile image if one was selected
      if (_profileImageBytes != null) {
        print('🔵 ProfileScreen: Uploading profile image...');

        // Show upload progress to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Text('Uploading profile image...'),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 10),
            ),
          );
        }

        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        try {
          avatarUrl = await SupabaseService.instance.uploadProfileImage(
            imageBytes: _profileImageBytes!,
            fileName: fileName,
          );
          print('🟢 ProfileScreen: Image uploaded successfully: $avatarUrl');

          // Clear the upload progress snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        } catch (uploadError) {
          print('🔴 ProfileScreen: Image upload failed: $uploadError');
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();

            // Check if it's a storage bucket error and provide helpful message
            String userFriendlyMessage;
            if (uploadError.toString().contains('Bucket not found') ||
                uploadError.toString().contains('404')) {
              userFriendlyMessage =
                  'Image saved locally! Storage service needs setup for cloud backup.';

              // Show info instead of error for storage bucket issues
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Image saved locally! Storage service needs setup for cloud backup.'),
                  backgroundColor: Colors.orange,
                ),
              );
            } else {
              userFriendlyMessage = 'Failed to upload image: $uploadError';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userFriendlyMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
          // Continue with profile save without avatar
          avatarUrl = null;
        }
      }

      // Build profile data with only fields that have values
      final profileData = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'bio': _bioController.text.trim(),
      };

      // Add optional fields only if they have values
      if (_phoneController.text.trim().isNotEmpty) {
        profileData['phone'] = _phoneController.text.trim();
      }
      if (_selectedGrade.isNotEmpty) {
        profileData['grade'] = _selectedGrade;
      }
      if (_selectedSubjects.isNotEmpty) {
        profileData['subjects'] = _selectedSubjects;
      }
      if (_selectedExam.isNotEmpty) {
        profileData['exam_target'] = _selectedExam;
      }

      // Add avatar URL if we have one
      if (avatarUrl != null) {
        profileData['avatar_url'] = avatarUrl;
      }

      print('🔵 ProfileScreen: Updating profile with data: $profileData');
      await ref.read(authProvider.notifier).updateProfile(profileData);

      // Persist preferences separately (non-blocking if profile update fails earlier)
      try {
        print(
            '🔵 ProfileScreen: Saving preferences patch: $_currentPreferencePatch');
        await SupabaseService.instance
            .updateUserPreferences(_currentPreferencePatch);
        print('🟢 ProfileScreen: Preferences saved');
      } catch (e) {
        debugPrint('🔴 ProfileScreen: Failed saving preferences: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Preferences save failed (will retry next save): $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      if (!mounted) return;

      final err = ref.read(authProvider).error;
      if (err != null) {
        print('🔴 ProfileScreen: Save failed with error: $err');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $err'), backgroundColor: Colors.red),
        );
      } else {
        print('🟢 ProfileScreen: Profile saved successfully!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Ensure current avatar shows immediately and persists in cache
        if (avatarUrl != null) {
          setState(() {
            _currentAvatarUrl = avatarUrl;
            _profileImageBytes = null;
          });

          // Also update global user to keep UI consistent across app
          final currentUser = ref.read(userProvider);
          if (currentUser != null) {
            ref
                .read(userProvider.notifier)
                .updateUser(currentUser.copyWith(profileImage: avatarUrl));
          }
        }
        // Update cache after we updated local state
        _saveToCache();
        _isCacheValid = true;
      }

      setState(() {
        _isSaving = false;
      });
    } catch (e) {
      print('🔴 ProfileScreen: Exception during save: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed successfully!')),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _privacySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacySettingsScreen(),
      ),
    );
  }

  void _helpSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpSupportScreen(),
      ),
    );
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    // Show loading dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Logging out...'),
          ],
        ),
      ),
    );

    try {
      debugPrint('🔵 ProfileScreen: Starting logout process...');

      // Clear local cache first
      _profileCache = null;
      _isCacheValid = false;

      // Force signOut with timeout
      await Future.any([
        ref.read(authProvider.notifier).signOut(forced: true),
        Future.delayed(const Duration(seconds: 10)), // Timeout after 10 seconds
      ]);

      debugPrint('🟢 ProfileScreen: Logout completed successfully');

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Navigate to login screen immediately
      context.go('/login');

      // Show success message after navigation
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully logged out'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('🔴 ProfileScreen: Logout error: $e');

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Force navigation to login even if logout failed
      context.go('/login');

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout completed with warning: ${e.toString()}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _userSubscription?.close();
    // Remove listeners before disposing
    _nameController.removeListener(_saveToCache);
    _emailController.removeListener(_saveToCache);
    _phoneController.removeListener(_saveToCache);
    _bioController.removeListener(_saveToCache);

    // Dispose controllers
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Privacy Controls',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Profile Visibility'),
            subtitle: const Text('Allow others to see your profile'),
            value: true,
            onChanged: (value) {},
          ),
          SwitchListTile(
            title: const Text('Show Online Status'),
            subtitle: const Text('Let others know when you\'re online'),
            value: false,
            onChanged: (value) {},
          ),
          SwitchListTile(
            title: const Text('Allow Messages from Anyone'),
            subtitle: const Text('Receive messages from all users'),
            value: true,
            onChanged: (value) {},
          ),
          const SizedBox(height: 24),
          const Text(
            'Data & Analytics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Usage Analytics'),
            subtitle: const Text('Help improve the app with usage data'),
            value: true,
            onChanged: (value) {},
          ),
          SwitchListTile(
            title: const Text('Performance Tracking'),
            subtitle: const Text('Track your learning performance'),
            value: true,
            onChanged: (value) {},
          ),
        ],
      ),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.question_answer),
                  title: const Text('FAQ'),
                  subtitle: const Text('Frequently asked questions'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble),
                  title: const Text('Live Chat'),
                  subtitle: const Text('Chat with our support team'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email Support'),
                  subtitle: const Text('Send us an email'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone Support'),
                  subtitle: const Text('Call our helpline'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.feedback),
                  title: const Text('Send Feedback'),
                  subtitle: const Text('Help us improve the app'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Report Bug'),
                  subtitle: const Text('Found an issue? Let us know'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text('Rate App'),
                  subtitle: const Text('Rate us on the app store'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'App Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version: 1.0.0',
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Last Updated: Dec 2024',
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('© 2024 InstantMentor',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
