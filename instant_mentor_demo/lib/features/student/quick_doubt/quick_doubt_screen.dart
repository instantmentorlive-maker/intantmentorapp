import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuickDoubtScreen extends ConsumerStatefulWidget {
  const QuickDoubtScreen({super.key});

  @override
  ConsumerState<QuickDoubtScreen> createState() => _QuickDoubtScreenState();
}

class _QuickDoubtScreenState extends ConsumerState<QuickDoubtScreen> {
  final TextEditingController _questionController = TextEditingController();
  String _selectedSubject = 'Mathematics';
  String _urgencyLevel = 'Medium';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Doubt Session'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
              color: Colors.orange.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flash_on, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Doubt Sessions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Get instant help for urgent doubts! Sessions last 5-15 minutes and connect you with available mentors immediately.'),
                    const SizedBox(height: 8),
                    Text(
                      '💡 Perfect for last-minute exam prep or homework help!',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.orange[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Available Mentors
            Text(
              'Available Now (${_getAvailableMentors().length} mentors online)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _getAvailableMentors().length,
                itemBuilder: (context, index) {
                  final mentor = _getAvailableMentors()[index];
                  return _MentorCard(mentor: mentor);
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Question Form
            Text(
              'Describe Your Doubt',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSubject,
                            decoration: const InputDecoration(
                              labelText: 'Subject',
                              prefixIcon: Icon(Icons.subject),
                            ),
                            items: ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (value) => setState(() => _selectedSubject = value!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _urgencyLevel,
                            decoration: const InputDecoration(
                              labelText: 'Urgency',
                              prefixIcon: Icon(Icons.priority_high),
                            ),
                            items: ['Low', 'Medium', 'High', 'Urgent']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (value) => setState(() => _urgencyLevel = value!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _questionController,
                      decoration: const InputDecoration(
                        labelText: 'Your Question',
                        hintText: 'Describe your doubt in detail...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _attachImage(),
                          icon: const Icon(Icons.image),
                        ),
                        IconButton(
                          onPressed: () => _attachDocument(),
                          icon: const Icon(Icons.attach_file),
                        ),
                        IconButton(
                          onPressed: () => _recordVoice(),
                          icon: const Icon(Icons.mic),
                        ),
                        const Spacer(),
                        Text(
                          '${_questionController.text.length}/500',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Pricing Info
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.monetization_on,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Session Pricing',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '5 min: \$8 • 10 min: \$15 • 15 min: \$22',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _questionController.text.trim().isEmpty
                    ? null
                    : () => _findMentor(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.search),
                label: const Text('Find Available Mentor'),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _scheduleForLater(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                icon: const Icon(Icons.schedule),
                label: const Text('Schedule for Later'),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recent Quick Sessions
            Text(
              'Your Recent Quick Sessions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ...List.generate(3, (index) => _buildRecentSessionCard(index)),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getAvailableMentors() {
    return [
      {
        'name': 'Dr. Sarah',
        'subject': 'Math',
        'rating': 4.9,
        'responseTime': '< 2 min',
        'isOnline': true,
      },
      {
        'name': 'Prof. Kumar',
        'subject': 'Physics',
        'rating': 4.8,
        'responseTime': '< 3 min',
        'isOnline': true,
      },
      {
        'name': 'Dr. Priya',
        'subject': 'Chemistry',
        'rating': 4.7,
        'responseTime': '< 5 min',
        'isOnline': true,
      },
    ];
  }

  Widget _buildRecentSessionCard(int index) {
    final sessions = [
      {
        'question': 'How to solve quadratic equations?',
        'mentor': 'Dr. Sarah Smith',
        'subject': 'Mathematics',
        'duration': '8 min',
        'date': 'Yesterday',
        'rating': 5,
      },
      {
        'question': 'Explain Newton\'s third law',
        'mentor': 'Prof. Raj Kumar',
        'subject': 'Physics',
        'duration': '12 min',
        'date': '3 days ago',
        'rating': 4,
      },
      {
        'question': 'Chemical bonding concepts',
        'mentor': 'Dr. Priya Sharma',
        'subject': 'Chemistry',
        'duration': '15 min',
        'date': '1 week ago',
        'rating': 5,
      },
    ];
    
    final session = sessions[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(session['mentor'].toString().split(' ').map((n) => n[0]).join()),
        ),
        title: Text(
          session['question'].toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${session['mentor']} • ${session['duration']} • ${session['date']}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                session['rating'] as int,
                (i) => Icon(Icons.star, size: 12, color: Colors.amber[600]),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session['subject'].toString(),
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        onTap: () => _viewSessionDetails(session),
      ),
    );
  }

  void _attachImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image attachment feature coming soon!')),
    );
  }

  void _attachDocument() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document attachment feature coming soon!')),
    );
  }

  void _recordVoice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice recording feature coming soon!')),
    );
  }

  void _findMentor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finding Mentor...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Finding the best available mentor for $_selectedSubject'),
            const SizedBox(height: 8),
            Text(
              'This usually takes less than 30 seconds',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
    
    // Simulate mentor finding
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      _showMentorFound();
    });
  }

  void _showMentorFound() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mentor Found! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              child: Text('DS'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dr. Sarah Smith',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text('Mathematics Expert • ⭐ 4.9'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Available Now', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Estimated session duration: 10-15 minutes\nCost: \$15',
              textAlign: TextAlign.center,
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
              _startSession();
            },
            child: const Text('Start Session'),
          ),
        ],
      ),
    );
  }

  void _startSession() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting quick doubt session...'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Navigate to session screen (would be implemented)
    Navigator.pop(context);
  }

  void _scheduleForLater() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('When would you like to have this doubt session?'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('In 1 hour'),
              onTap: () => _scheduleSession('1 hour'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Tomorrow'),
              onTap: () => _scheduleSession('tomorrow'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Custom time'),
              onTap: () => _scheduleSession('custom'),
            ),
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

  void _scheduleSession(String when) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Session scheduled for $when')),
    );
  }

  void _viewSessionDetails(Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(session['question'].toString()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mentor: ${session['mentor']}'),
            Text('Subject: ${session['subject']}'),
            Text('Duration: ${session['duration']}'),
            Text('Date: ${session['date']}'),
            const SizedBox(height: 12),
            Text('Rating: ${'⭐' * (session['rating'] as int)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Viewing session recording...')),
              );
            },
            child: const Text('View Recording'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }
}

class _MentorCard extends StatelessWidget {
  final Map<String, dynamic> mentor;

  const _MentorCard({required this.mentor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    child: Text(mentor['name'].toString().split(' ').map((n) => n[0]).join()),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: mentor['isOnline'] ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mentor['name'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                mentor['subject'],
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 10, color: Colors.amber[600]),
                  const SizedBox(width: 2),
                  Text('${mentor['rating']}', style: const TextStyle(fontSize: 10)),
                ],
              ),
              Text(
                mentor['responseTime'],
                style: const TextStyle(fontSize: 9, color: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
