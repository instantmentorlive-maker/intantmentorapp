import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

  // Static cache to persist profile data across navigation
  static Map<String, dynamic>? _profileCache;
  static bool _isCacheValid = false;

  String _selectedGrade = '12th Grade';
  List<String> _selectedSubjects = [];
  String _selectedExam = 'JEE';

  Uint8List? _profileImageBytes;
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

    // Check if we have valid cached data
    if (_isCacheValid && _profileCache != null) {
      _loadFromCache();
      setState(() => _loadingInitial = false);
    } else {
      _loadUserData();
    }
  }

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
          _selectedExam = profile['exam_target'] ?? 'JEE';

          if (profile['subjects'] is List) {
            _selectedSubjects = List<String>.from(profile['subjects']);
          }
        });
      }

      // Load preferences
      await _loadPreferences();

      // Save loaded data to cache
      _saveToCache();
    } catch (e) {
      debugPrint('⚠️ ProfileScreen: Failed loading user data: $e');
      // Set default values only if loading fails
      if (mounted) {
        setState(() {
          _nameController.text =
              _nameController.text.isEmpty ? 'User' : _nameController.text;
          _emailController.text = _emailController.text.isEmpty
              ? 'user@example.com'
              : _emailController.text;
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
        });
      }
    } catch (e) {
      debugPrint('⚠️ ProfileScreen: Failed loading preferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = ref.watch(isStudentProvider);

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
                  CircleAvatar(
                    radius: 60,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : null,
                    child: _profileImageBytes == null
                        ? const Text(
                            'AJ',
                            style: TextStyle(
                                fontSize: 36, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _changeProfilePicture,
                      ),
                    ),
                  ),
                ],
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

                DropdownButtonFormField<String>(
                  initialValue: _selectedGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade/Class',
                    prefixIcon: Icon(Icons.school),
                  ),
                  items: [
                    '9th Grade',
                    '10th Grade',
                    '11th Grade',
                    '12th Grade',
                    'College',
                    'Graduate'
                  ]
                      .map((grade) =>
                          DropdownMenuItem(value: grade, child: Text(grade)))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedGrade = value!;
                    _saveToCache();
                  }),
                ),

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

              // Preferences
              Text(
                'Preferences',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              Card(
                child: _loadingInitial
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Email Notifications'),
                            subtitle: const Text('Receive updates via email'),
                            value: _emailNotifications,
                            onChanged: (value) {
                              setState(() {
                                _emailNotifications = value;
                                _saveToCache();
                              });
                            },
                          ),
                          SwitchListTile(
                            title: const Text('Push Notifications'),
                            subtitle: const Text('Receive push notifications'),
                            value: _pushNotifications,
                            onChanged: (value) {
                              setState(() {
                                _pushNotifications = value;
                                _saveToCache();
                              });
                            },
                          ),
                          if (isStudent)
                            SwitchListTile(
                              title: const Text('Study Reminders'),
                              subtitle: const Text('Get reminded to study'),
                              value: _studyReminders,
                              onChanged: (value) {
                                setState(() {
                                  _studyReminders = value;
                                  _saveToCache();
                                });
                              },
                            ),
                          SwitchListTile(
                            title: const Text('Session Reminders'),
                            subtitle:
                                const Text('Get reminded before sessions'),
                            value: _sessionReminders,
                            onChanged: (value) {
                              setState(() {
                                _sessionReminders = value;
                                _saveToCache();
                              });
                            },
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              // Account Actions
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text('Change Password'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _changePassword,
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Privacy Settings'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _privacySettings,
                    ),
                    ListTile(
                      leading: const Icon(Icons.help),
                      title: const Text('Help & Support'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _helpSupport,
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Logout',
                          style: TextStyle(color: Colors.red)),
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

  void _changeProfilePicture() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
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
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
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
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        avatarUrl = await SupabaseService.instance.uploadProfileImage(
          imageBytes: _profileImageBytes!,
          fileName: fileName,
        );
        print('🟢 ProfileScreen: Image uploaded successfully: $avatarUrl');
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

        // Update cache with saved data instead of invalidating it
        // This prevents the form from being reset after save
        _saveToCache();
        _isCacheValid = true;

        // Clear the profile image bytes since it's now uploaded
        if (_profileImageBytes != null) {
          setState(() {
            _profileImageBytes = null;
          });
        }
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

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // Properly sign out through auth provider
                await ref.read(authProvider.notifier).signOut();
                // Navigation will be handled by router redirect logic automatically
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading
                  // Don't manually navigate - let the router's redirect logic handle it
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
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
