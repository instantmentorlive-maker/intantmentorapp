import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

// Real-time provider that fetches actual user profile data from Supabase
final mentorProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);

  if (!auth.isAuthenticated || auth.user == null) {
    return {};
  }

  final userId = auth.user!.id;
  final userEmail = auth.user!.email ?? '';

  try {
    // Fetch user profile data with timeout
    final userProfile = await _supabase
        .from('user_profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );

    // Fetch mentor profile data with timeout
    final mentorProfile = await _supabase
        .from('mentor_profiles')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );

    // Combine data from both tables
    return {
      'name': userProfile?['full_name'] ?? 'User',
      'email': userEmail,
      'phone': userProfile?['phone'] ?? '',
      'subjects': mentorProfile?['subjects'] != null
          ? (mentorProfile!['subjects'] as List).cast<String>()
          : <String>[],
      'experience': mentorProfile?['experience'] ?? '',
      'rating': mentorProfile?['rating']?.toDouble() ?? 0.0,
      'totalSessions': mentorProfile?['total_sessions'] ?? 0,
      'hourlyRate': mentorProfile?['hourly_rate'] ?? 0,
      'availability': mentorProfile?['availability'] ?? '',
      'bio': mentorProfile?['bio'] ?? '',
      'qualifications': mentorProfile?['qualifications'] != null
          ? (mentorProfile!['qualifications'] as List).cast<String>()
          : <String>[],
      'languages': mentorProfile?['languages'] != null
          ? (mentorProfile!['languages'] as List).cast<String>()
          : <String>['English'],
      'teachingStyle': mentorProfile?['teaching_style'] ?? '',
    };
  } catch (e) {
    debugPrint('❌ Error loading profile data: $e');
    // Return minimal data with user email from auth
    return {
      'name': auth.user!.userMetadata?['full_name'] ?? 'User',
      'email': userEmail,
      'phone': '',
      'subjects': <String>[],
      'experience': '',
      'rating': 0.0,
      'totalSessions': 0,
      'hourlyRate': 0,
      'availability': '',
      'bio': '',
      'qualifications': <String>[],
      'languages': <String>['English'],
      'teachingStyle': '',
    };
  }
});

final editingModeProvider = StateProvider<bool>((ref) => false);

class ProfileManagementScreen extends ConsumerStatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  ConsumerState<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState
    extends ConsumerState<ProfileManagementScreen> {
  // Controllers for editable fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectsController = TextEditingController();
  final _experienceController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _bioController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _languagesController = TextEditingController();
  final _teachingStyleController = TextEditingController();

  bool _controllersInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectsController.dispose();
    _experienceController.dispose();
    _hourlyRateController.dispose();
    _availabilityController.dispose();
    _bioController.dispose();
    _qualificationsController.dispose();
    _languagesController.dispose();
    _teachingStyleController.dispose();
    super.dispose();
  }

  void _populateControllers(Map<String, dynamic> profile) {
    _nameController.text = profile['name'] ?? '';
    _emailController.text = profile['email'] ?? '';
    _phoneController.text = profile['phone'] ?? '';
    _subjectsController.text = (profile['subjects'] as List?)?.join(', ') ?? '';
    _experienceController.text = profile['experience'] ?? '';
    _hourlyRateController.text = (profile['hourlyRate']?.toString() ?? '')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    _availabilityController.text = profile['availability'] ?? '';
    _bioController.text = profile['bio'] ?? '';
    _qualificationsController.text =
        (profile['qualifications'] as List?)?.join('\n') ?? '';
    _languagesController.text =
        (profile['languages'] as List?)?.join(', ') ?? '';
    _teachingStyleController.text = profile['teachingStyle'] ?? '';
    _controllersInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(mentorProfileProvider);
    final isEditing = ref.watch(editingModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: profileAsync.hasValue
                ? () {
                    if (isEditing) {
                      _saveProfile(context, profileAsync.value!);
                    } else {
                      _controllersInitialized = false; // force re-population
                      ref.read(editingModeProvider.notifier).state = true;
                    }
                  }
                : null,
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          // Initialize controllers if entering edit mode
          if (isEditing && !_controllersInitialized) {
            _populateControllers(profile);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(context, profile, isEditing),
                const SizedBox(height: 24),
                _buildSection(
                  context,
                  'Basic Information',
                  [
                    _buildInfoTile(
                        'Name', profile['name'], Icons.person, isEditing,
                        controller: _nameController),
                    _buildInfoTile(
                        'Email', profile['email'], Icons.email, isEditing,
                        controller: _emailController),
                    _buildInfoTile(
                        'Phone', profile['phone'], Icons.phone, isEditing,
                        controller: _phoneController),
                  ],
                ),
                _buildSection(
                  context,
                  'Teaching Information',
                  [
                    _buildSubjectsTile(profile['subjects'], isEditing,
                        controller: _subjectsController),
                    _buildInfoTile('Experience', profile['experience'],
                        Icons.work, isEditing,
                        controller: _experienceController),
                    _buildInfoTile(
                        'Hourly Rate',
                        '\$${profile['hourlyRate']}/hour',
                        Icons.attach_money,
                        isEditing,
                        controller: _hourlyRateController),
                    _buildInfoTile('Availability', profile['availability'],
                        Icons.schedule, isEditing,
                        controller: _availabilityController),
                  ],
                ),
                _buildSection(
                  context,
                  'Professional Profile',
                  [
                    _buildBioTile(profile['bio'], isEditing,
                        controller: _bioController),
                    _buildQualificationsTile(
                        profile['qualifications'], isEditing,
                        controller: _qualificationsController),
                    _buildLanguagesTile(profile['languages'], isEditing,
                        controller: _languagesController),
                    _buildInfoTile('Teaching Style', profile['teachingStyle'],
                        Icons.school, isEditing,
                        controller: _teachingStyleController),
                  ],
                ),
                _buildSection(
                  context,
                  'Statistics',
                  [
                    _buildStatTile('Rating', '${profile['rating']}/5.0',
                        Icons.star, Colors.amber),
                    _buildStatTile(
                        'Total Sessions',
                        '${profile['totalSessions']}',
                        Icons.video_call,
                        Colors.blue),
                    _buildStatTile(
                        'Students Taught',
                        '${(profile['totalSessions'] * 0.3).round()}',
                        Icons.people,
                        Colors.green),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Failed to load profile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(mentorProfileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile(
      BuildContext context, Map<String, dynamic> original) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final userId = auth.user!.id;

    // Build updated map
    final updated = {
      'full_name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'subjects': _subjectsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'experience': _experienceController.text.trim(),
      'hourly_rate': _parseHourly(_hourlyRateController.text),
      'availability': _availabilityController.text.trim(),
      'bio': _bioController.text.trim(),
      'qualifications': _qualificationsController.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'languages': _languagesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'teaching_style': _teachingStyleController.text.trim(),
    };

    try {
      // Update user_profiles table
      await _supabase
          .from('user_profiles')
          .update({
            'full_name': updated['full_name'],
            'phone': updated['phone'],
          })
          .eq('id', userId)
          .timeout(const Duration(seconds: 10));

      // Update mentor_profiles table
      await _supabase
          .from('mentor_profiles')
          .update({
            'subjects': updated['subjects'],
            'experience': updated['experience'],
            'hourly_rate': updated['hourly_rate'],
            'availability': updated['availability'],
            'bio': updated['bio'],
            'qualifications': updated['qualifications'],
            'languages': updated['languages'],
            'teaching_style': updated['teaching_style'],
          })
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));

      // Refresh the profile provider to fetch updated data
      ref.invalidate(mentorProfileProvider);

      ref.read(editingModeProvider.notifier).state = false;
      _controllersInitialized = false; // reset to ensure fresh load next edit

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  num _parseHourly(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return 0;
    return num.tryParse(cleaned) ?? 0;
  }

  Widget _buildProfileHeader(
      BuildContext context, Map<String, dynamic> profile, bool isEditing) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    profile['name']
                        .toString()
                        .split(' ')
                        .map((n) => n[0])
                        .join(),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isEditing)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
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
                    profile['name'],
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile['subjects'].join(', ')} Tutor',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                          '${profile['rating']} (${profile['totalSessions']} sessions)'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInfoTile(
      String label, String value, IconData icon, bool isEditing,
      {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                isEditing
                    ? TextFormField(
                        controller: controller,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                      )
                    : Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsTile(List<dynamic> subjects, bool isEditing,
      {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.school, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subjects',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                if (isEditing)
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      hintText: 'Separate subjects with commas',
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: subjects
                        .map((subject) => Chip(
                              label: Text(subject.toString()),
                              backgroundColor: Colors.blue.withOpacity(0.1),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioTile(String bio, bool isEditing,
      {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bio',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                isEditing
                    ? TextFormField(
                        controller: controller,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      )
                    : Text(bio),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualificationsTile(List<dynamic> qualifications, bool isEditing,
      {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.school_outlined, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Qualifications',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                if (isEditing)
                  TextFormField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                      hintText: 'One qualification per line',
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: qualifications
                        .map((qual) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Expanded(child: Text(qual.toString())),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagesTile(List<dynamic> languages, bool isEditing,
      {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.language, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Languages',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                if (isEditing)
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      hintText: 'Separate languages with commas',
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: languages
                        .map((lang) => Chip(
                              label: Text(lang.toString()),
                              backgroundColor: Colors.green.withOpacity(0.1),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
