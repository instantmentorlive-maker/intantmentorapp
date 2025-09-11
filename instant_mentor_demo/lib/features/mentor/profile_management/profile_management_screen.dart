import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers for mentor profile data
final mentorProfileProvider = StateProvider<Map<String, dynamic>>((ref) => {
  'name': 'Dr. Sarah Johnson',
  'email': 'sarah.johnson@email.com',
  'phone': '+1 (555) 123-4567',
  'subjects': ['Mathematics', 'Physics', 'Chemistry'],
  'experience': '8 years',
  'rating': 4.9,
  'totalSessions': 1247,
  'hourlyRate': 45,
  'availability': 'Mon-Fri 9AM-6PM',
  'bio': 'Experienced mathematics and physics tutor with PhD in Applied Mathematics. Specialized in helping students excel in STEM subjects.',
  'qualifications': [
    'PhD in Applied Mathematics - MIT',
    'MS in Physics - Stanford University', 
    'Certified Online Tutor - TeachOnline Institute'
  ],
  'languages': ['English', 'Spanish', 'French'],
  'teachingStyle': 'Interactive and student-centered approach',
});

final editingModeProvider = StateProvider<bool>((ref) => false);

class ProfileManagementScreen extends ConsumerWidget {
  const ProfileManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(mentorProfileProvider);
    final isEditing = ref.watch(editingModeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (isEditing) {
                _saveProfile(context, ref);
              } else {
                ref.read(editingModeProvider.notifier).state = true;
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            _buildProfileHeader(context, profile, isEditing),
            const SizedBox(height: 24),
            
            // Basic Information
            _buildSection(
              context,
              'Basic Information',
              [
                _buildInfoTile('Name', profile['name'], Icons.person, isEditing),
                _buildInfoTile('Email', profile['email'], Icons.email, isEditing),
                _buildInfoTile('Phone', profile['phone'], Icons.phone, isEditing),
              ],
            ),
            
            // Teaching Information
            _buildSection(
              context,
              'Teaching Information',
              [
                _buildSubjectsTile(profile['subjects'], isEditing),
                _buildInfoTile('Experience', profile['experience'], Icons.work, isEditing),
                _buildInfoTile('Hourly Rate', '\$${profile['hourlyRate']}/hour', Icons.attach_money, isEditing),
                _buildInfoTile('Availability', profile['availability'], Icons.schedule, isEditing),
              ],
            ),
            
            // Bio & Qualifications
            _buildSection(
              context,
              'Professional Profile',
              [
                _buildBioTile(profile['bio'], isEditing),
                _buildQualificationsTile(profile['qualifications'], isEditing),
                _buildLanguagesTile(profile['languages'], isEditing),
                _buildInfoTile('Teaching Style', profile['teachingStyle'], Icons.school, isEditing),
              ],
            ),
            
            // Statistics (Read-only)
            _buildSection(
              context,
              'Statistics',
              [
                _buildStatTile('Rating', '${profile['rating']}/5.0', Icons.star, Colors.amber),
                _buildStatTile('Total Sessions', '${profile['totalSessions']}', Icons.video_call, Colors.blue),
                _buildStatTile('Students Taught', '${(profile['totalSessions'] * 0.3).round()}', Icons.people, Colors.green),
              ],
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, Map<String, dynamic> profile, bool isEditing) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    profile['name'].toString().split(' ').map((n) => n[0]).join(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile['subjects'].join(', ')} Tutor',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('${profile['rating']} (${profile['totalSessions']} sessions)'),
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

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
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

  Widget _buildInfoTile(String label, String value, IconData icon, bool isEditing) {
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
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                isEditing
                    ? TextFormField(
                        initialValue: value,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildSubjectsTile(List<dynamic> subjects, bool isEditing) {
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
                const Text('Subjects', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                if (isEditing)
                  TextFormField(
                    initialValue: subjects.join(', '),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      hintText: 'Separate subjects with commas',
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: subjects.map((subject) => Chip(
                      label: Text(subject.toString()),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                    )).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioTile(String bio, bool isEditing) {
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
                const Text('Bio', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                isEditing
                    ? TextFormField(
                        initialValue: bio,
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

  Widget _buildQualificationsTile(List<dynamic> qualifications, bool isEditing) {
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
                const Text('Qualifications', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                if (isEditing)
                  TextFormField(
                    initialValue: qualifications.join('\n'),
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
                    children: qualifications.map((qual) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(qual.toString())),
                        ],
                      ),
                    )).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagesTile(List<dynamic> languages, bool isEditing) {
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
                const Text('Languages', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                if (isEditing)
                  TextFormField(
                    initialValue: languages.join(', '),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      hintText: 'Separate languages with commas',
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: languages.map((lang) => Chip(
                      label: Text(lang.toString()),
                      backgroundColor: Colors.green.withOpacity(0.1),
                    )).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
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
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveProfile(BuildContext context, WidgetRef ref) {
    ref.read(editingModeProvider.notifier).state = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
