import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/chat.dart';
import '../../../core/models/user.dart';
// Routing is no longer used directly here; we open contextual screens/dialogs instead
// import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_providers.dart';
import '../../../core/providers/user_provider.dart';
import '../../chat/chat_detail_screen.dart';
import '../../student/booking/book_session_screen.dart';

class MentorProfileScreen extends ConsumerWidget {
  final String mentorId;

  const MentorProfileScreen({super.key, required this.mentorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock mentor data based on mentorId - in real app, this would be fetched from database
    final Map<String, dynamic> mentorData = _getMentorData(mentorId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share mentor profile',
            onPressed: () {
              final shareUrl = _buildMentorShareLink(mentorData['id']);
              Share.share(
                'Check out mentor ${mentorData['name']} on Instant Mentor: $shareUrl',
                subject: 'Mentor Recommendation',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        mentorData['initials'],
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      mentorData['name'],
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      mentorData['description'],
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Icon(Icons.star, color: Colors.amber[600]),
                            const Text('4.8',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Rating',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const Column(
                          children: [
                            Icon(Icons.school, color: Colors.blue),
                            Text('245',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Sessions', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const Column(
                          children: [
                            Icon(Icons.verified, color: Colors.green),
                            Text('Verified',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Expert', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // About Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(mentorData['about']),
                    const SizedBox(height: 16),
                    const Text(
                      'Specializations',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: (mentorData['specializations'] as List<String>)
                          .map((tag) {
                        return Chip(label: Text(tag));
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onBookSession(context, mentorData),
                    icon: const Icon(Icons.book_online),
                    label: const Text('Book Session'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onSendMessage(context, ref, mentorData),
                    icon: const Icon(Icons.chat),
                    label: const Text('Send Message'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildMentorShareLink(String id) {
    // In production this would be a deep link or web URL
    return 'https://instantmentor.app/mentor/$id';
  }

  void _onSendMessage(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> mentorData,
  ) async {
    final auth = ref.read(authProvider);
    final me = auth.user; // Supabase auth user (for id)
    final domainUser = ref.read(userProvider); // Domain user (for name)
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send a message.')),
      );
      return;
    }

    try {
      final chatService = ref.read(chatServiceProvider);
      final threadId = await chatService.createOrGetThread(
        studentId: me.id,
        mentorId: mentorId,
        subject: (mentorData['specializations'] as List<String>).isNotEmpty
            ? (mentorData['specializations'] as List<String>).first
            : null,
      );

      // Build a lightweight thread model for the detail screen; messages will stream in
      final thread = ChatThread(
        id: threadId,
        studentId: me.id,
        studentName:
            (domainUser?.name ?? '').isNotEmpty ? domainUser!.name : 'Me',
        mentorId: mentorId,
        mentorName: mentorData['name'] as String,
        lastActivity: DateTime.now(),
        subject: (mentorData['specializations'] as List<String>).isNotEmpty
            ? (mentorData['specializations'] as List<String>).first
            : null,
      );

      // Open chat detail screen
      // Using Navigator push (consistent with StudentChatScreen navigation)
      // ignore: use_build_context_synchronously
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatDetailScreen(thread: thread)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
    }
  }

  void _onBookSession(BuildContext context, Map<String, dynamic> mentorData) {
    // Construct a minimal Mentor domain object for BookingDialog
    final mentor = Mentor(
      id: mentorId,
      name: mentorData['name'] as String,
      email: '$mentorId@example.com',
      createdAt: DateTime.now(),
      specializations:
          List<String>.from(mentorData['specializations'] as List<String>),
      qualifications: const [],
      hourlyRate: 50.0, // default rate for demo
      rating: 4.8,
      totalSessions: 245,
      isAvailable: true,
      totalEarnings: 0.0,
      bio: mentorData['about'] as String,
      yearsOfExperience: 5,
    );

    showDialog(
      context: context,
      builder: (_) => BookingDialog(mentor: mentor),
    );
  }

  // Mock method to get mentor data based on mentorId
  Map<String, dynamic> _getMentorData(String mentorId) {
    // Demo mentor records - include both numeric and 'mentor_X' keys so callers
    // that pass either format resolve correctly.
    final mentorRecords = {
      // Numeric IDs (used in many mock lists)
      '1': {
        'id': '1',
        'name': 'Prof. Raj Kumar',
        'initials': 'PRK',
        'description': 'Physics Expert • 10+ years experience',
        'about':
            'Experienced physics mentor with 10+ years of teaching IIT-JEE and NEET aspirants. PhD in Physics from IIT Bombay. Expert in mechanics, thermodynamics, and electromagnetism.',
        'specializations': [
          'Physics',
          'IIT-JEE',
          'NEET',
          'Mechanics',
          'Thermodynamics'
        ],
      },
      '2': {
        'id': '2',
        'name': 'Dr. Sarah Smith',
        'initials': 'DS',
        'description': 'Mathematics Expert • 8+ years experience',
        'about':
            'Experienced mathematics mentor with 8+ years of teaching JEE and NEET aspirants. PhD in Mathematics from IIT Delhi. Specialized in helping students overcome math anxiety and build strong problem-solving skills.',
        'specializations': [
          'Mathematics',
          'JEE',
          'NEET',
          'Calculus',
          'Algebra'
        ],
      },
      '3': {
        'id': '3',
        'name': 'Dr. Priya Sharma',
        'initials': 'DPS',
        'description': 'Chemistry Expert • 6+ years experience',
        'about':
            'Chemistry expert with a focus on organic chemistry and practical applications. Skilled at helping students with conceptual understanding and exam preparation.',
        'specializations': [
          'Chemistry',
          'Organic Chemistry',
          'NEET',
          'Analytical Chemistry'
        ],
      },
      '4': {
        'id': '4',
        'name': 'Mr. Vikash Singh',
        'initials': 'MVS',
        'description': 'English Expert • 5+ years experience',
        'about':
            'English language expert specializing in grammar, writing skills, and test preparation, including IELTS and creative writing coaching.',
        'specializations': ['English', 'IELTS', 'Writing', 'Grammar'],
      },
      '5': {
        'id': '5',
        'name': 'Dr. Anjali Gupta',
        'initials': 'DAG',
        'description': 'Biology Expert • 10+ years experience',
        'about':
            'Medical researcher and educator with expertise in life sciences and medical entrance preparation.',
        'specializations': ['Biology', 'Genetics', 'NEET', 'Cell Biology'],
      },
      // Direct mentor_X keys matching the provider data
      'mentor_1': {
        'id': 'mentor_1',
        'name': 'Dr. Sarah Smith',
        'initials': 'DS',
        'description': 'Mathematics Expert • 8+ years experience',
        'about':
            'Experienced mathematics mentor with 8+ years of teaching JEE and NEET aspirants. PhD in Mathematics from IIT Delhi. Specialized in helping students overcome math anxiety and build strong problem-solving skills.',
        'specializations': [
          'Mathematics',
          'JEE',
          'NEET',
          'Calculus',
          'Algebra'
        ],
      },
      'mentor_2': {
        'id': 'mentor_2',
        'name': 'Prof. Raj Kumar',
        'initials': 'PRK',
        'description': 'Physics Expert • 10+ years experience',
        'about':
            'Experienced physics mentor with 10+ years of teaching IIT-JEE and NEET aspirants. PhD in Physics from IIT Bombay. Expert in mechanics, thermodynamics, and electromagnetism.',
        'specializations': [
          'Physics',
          'IIT-JEE',
          'NEET',
          'Mechanics',
          'Thermodynamics'
        ],
      },
      'mentor_3': {
        'id': 'mentor_3',
        'name': 'Dr. Priya Sharma',
        'initials': 'DPS',
        'description': 'Chemistry Expert • 6+ years experience',
        'about':
            'Chemistry expert with a focus on organic chemistry and practical applications. Skilled at helping students with conceptual understanding and exam preparation.',
        'specializations': [
          'Chemistry',
          'Organic Chemistry',
          'NEET',
          'Analytical Chemistry'
        ],
      },
      'mentor_4': {
        'id': 'mentor_4',
        'name': 'Mr. Vikash Singh',
        'initials': 'MVS',
        'description': 'English Expert • 5+ years experience',
        'about':
            'English language expert specializing in grammar, writing skills, and test preparation, including IELTS and creative writing coaching.',
        'specializations': ['English', 'IELTS', 'Writing', 'Grammar'],
      },
      'mentor_5': {
        'id': 'mentor_5',
        'name': 'Dr. Anjali Gupta',
        'initials': 'DAG',
        'description': 'Biology Expert • 10+ years experience',
        'about':
            'Medical researcher and educator with expertise in life sciences and medical entrance preparation.',
        'specializations': ['Biology', 'Genetics', 'NEET', 'Cell Biology'],
      },
    };

    // If supplied id isn't found, try to fallback by prefixing 'mentor_'
    if (mentorRecords.containsKey(mentorId) &&
        mentorRecords[mentorId] != null) {
      return Map<String, dynamic>.from(mentorRecords[mentorId]!);
    }

    // Try fallback prefixes
    final altKey = mentorId.startsWith('mentor_')
        ? mentorId.substring(7) // Remove 'mentor_' prefix
        : 'mentor_$mentorId';
    if (mentorRecords.containsKey(altKey) && mentorRecords[altKey] != null) {
      return Map<String, dynamic>.from(mentorRecords[altKey]!);
    }

    // Final fallback: return mentor with id 'mentor_2' (Prof. Raj Kumar - highest rated)
    return Map<String, dynamic>.from(mentorRecords['mentor_2']!);
  }
}
