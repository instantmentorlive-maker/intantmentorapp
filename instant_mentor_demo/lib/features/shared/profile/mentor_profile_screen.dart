import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MentorProfileScreen extends StatelessWidget {
  final String mentorId;

  const MentorProfileScreen({super.key, required this.mentorId});

  @override
  Widget build(BuildContext context) {
    // Mock mentor data - in real app, this would be fetched based on mentorId
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
                      child: const Text(
                        'DS',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dr. Sarah Smith',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Mathematics Expert • 8+ years experience',
                      style: TextStyle(color: Colors.grey),
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
                        Column(
                          children: [
                            const Icon(Icons.school, color: Colors.blue),
                            const Text('245', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Sessions', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.verified, color: Colors.green),
                            const Text('Verified', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Expert', style: TextStyle(fontSize: 12)),
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
                    const Text(
                      'Experienced mathematics mentor with 8+ years of teaching JEE and NEET aspirants. PhD in Mathematics from IIT Delhi. Specialized in helping students overcome math anxiety and build strong problem-solving skills.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Specializations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Mathematics', 'JEE', 'NEET', 'Calculus', 'Algebra'].map((tag) {
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
}
