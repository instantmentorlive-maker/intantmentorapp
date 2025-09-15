import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MentorProfileScreen extends StatelessWidget {
  final String mentorId;

  const MentorProfileScreen({super.key, required this.mentorId});

  @override
  Widget build(BuildContext context) {
    // Mock mentor data based on mentorId - in real app, this would be fetched from database
    Map<String, dynamic> mentorData = _getMentorData(mentorId);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
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
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        mentorData['initials'],
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      mentorData['name'],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                            const Text('4.8', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Rating', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const Column(
                          children: [
                            Icon(Icons.school, color: Colors.blue),
                            Text('245', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Sessions', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const Column(
                          children: [
                            Icon(Icons.verified, color: Colors.green),
                            Text('Verified', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(mentorData['about']),
                    const SizedBox(height: 16),
                    const Text(
                      'Specializations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: (mentorData['specializations'] as List<String>).map((tag) {
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
                    onPressed: () => context.go('/student/booking'),
                    icon: const Icon(Icons.book_online),
                    label: const Text('Book Session'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/student/chat'),
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

  // Mock method to get mentor data based on mentorId
  Map<String, dynamic> _getMentorData(String mentorId) {
    final mentors = {
      'mentor_1': {
        'name': 'Prof. Raj Kumar',
        'initials': 'PRK',
        'description': 'Physics Expert • 10+ years experience',
        'about': 'Experienced physics mentor with 10+ years of teaching IIT-JEE and NEET aspirants. PhD in Physics from IIT Bombay. Expert in mechanics, thermodynamics, and electromagnetism.',
        'specializations': ['Physics', 'IIT-JEE', 'NEET', 'Mechanics', 'Thermodynamics'],
      },
      'mentor_2': {
        'name': 'Dr. Sarah Smith',
        'initials': 'DS',
        'description': 'Mathematics Expert • 8+ years experience',
        'about': 'Experienced mathematics mentor with 8+ years of teaching JEE and NEET aspirants. PhD in Mathematics from IIT Delhi. Specialized in helping students overcome math anxiety and build strong problem-solving skills.',
        'specializations': ['Mathematics', 'JEE', 'NEET', 'Calculus', 'Algebra'],
      },
    };

    return mentors[mentorId] ?? mentors['mentor_2']!; // Default to Dr. Sarah Smith
  }
}
