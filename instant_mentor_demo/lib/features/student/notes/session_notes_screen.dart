import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_video_player.dart';

// Note model
class SessionNote {
  final String id;
  final String mentor;
  final String subject;
  final String title;
  final String content;
  final String topic;
  final DateTime date;
  final bool hasRecording;
  final bool isBookmarked;
  final String? videoUrl;

  SessionNote({
    required this.id,
    required this.mentor,
    required this.subject,
    required this.title,
    required this.content,
    required this.topic,
    required this.date,
    this.hasRecording = false,
    this.isBookmarked = false,
    this.videoUrl,
  });

  SessionNote copyWith({
    String? id,
    String? mentor,
    String? subject,
    String? title,
    String? content,
    String? topic,
    DateTime? date,
    bool? hasRecording,
    bool? isBookmarked,
    String? videoUrl,
  }) {
    return SessionNote(
      id: id ?? this.id,
      mentor: mentor ?? this.mentor,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      content: content ?? this.content,
      topic: topic ?? this.topic,
      date: date ?? this.date,
      hasRecording: hasRecording ?? this.hasRecording,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }
}

// Provider for notes
final notesProvider =
    StateNotifierProvider<NotesNotifier, List<SessionNote>>((ref) {
  return NotesNotifier();
});

class NotesNotifier extends StateNotifier<List<SessionNote>> {
  NotesNotifier() : super(_defaultNotes);

  static final List<SessionNote> _defaultNotes = [
    SessionNote(
      id: '1',
      mentor: 'Dr. Sarah Smith',
      subject: 'Mathematics',
      title: 'Calculus Integration',
      content:
          'Key concepts covered: Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore...',
      topic: 'Calculus Integration',
      date: DateTime.now(),
      hasRecording: true,
      videoUrl:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    ),
    SessionNote(
      id: '2',
      mentor: 'Prof. Raj Kumar',
      subject: 'Physics',
      title: 'Quantum Mechanics',
      content:
          'Key concepts covered: Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore...',
      topic: 'Quantum Mechanics',
      date: DateTime.now().subtract(const Duration(days: 1)),
      hasRecording: true,
      videoUrl:
          'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
    ),
  ];

  void addNote(SessionNote note) {
    state = [note, ...state];
  }

  void toggleBookmark(String noteId) {
    state = state.map((note) {
      if (note.id == noteId) {
        return note.copyWith(isBookmarked: !note.isBookmarked);
      }
      return note;
    }).toList();
  }
}

class SessionNotesScreen extends ConsumerWidget {
  const SessionNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Notes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and Filter Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _showFilterDialog(context),
                  icon: const Icon(Icons.filter_list),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.note,
                    title: 'Total Notes',
                    value: '${notes.length}',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.video_library,
                    title: 'Recordings',
                    value: '${notes.where((n) => n.hasRecording).length}',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.bookmark,
                    title: 'Bookmarked',
                    value: '${notes.where((n) => n.isBookmarked).length}',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Notes List
            Text(
              'Recent Session Notes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            ...notes.map((note) => _buildNoteCard(context, ref, note)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, WidgetRef ref, SessionNote note) {
    String getTimeAgo(DateTime date) {
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${(difference.inDays / 7).floor()} week${(difference.inDays / 7).floor() > 1 ? 's' : ''} ago';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(note.mentor.split(' ').map((n) => n[0]).join()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${note.subject} with ${note.mentor}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        getTimeAgo(note.date),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (note.hasRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'REC',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => ref
                          .read(notesProvider.notifier)
                          .toggleBookmark(note.id),
                      icon: Icon(
                        note.isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        size: 20,
                        color: note.isBookmarked ? Colors.orange : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Topic: ${note.topic}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              note.content,
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (note.hasRecording)
                  ElevatedButton.icon(
                    onPressed: () => _showVideoPlayer(
                      context,
                      sessionTitle: '${note.subject} with ${note.mentor}',
                      videoUrl: note.videoUrl,
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Watch Recording'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _viewNoteDetails(context, note),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View Notes'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedMentor = 'Dr. Sarah Smith';
    String selectedSubject = 'Mathematics';
    String selectedTopic = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Quick Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select Mentor'),
                  value: selectedMentor,
                  items: [
                    'Dr. Sarah Smith',
                    'Prof. Raj Kumar',
                    'Dr. Priya Sharma',
                    'Mr. Vikash Singh'
                  ]
                      .map((mentor) =>
                          DropdownMenuItem(value: mentor, child: Text(mentor)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedMentor = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Select Subject'),
                  value: selectedSubject,
                  items: ['Mathematics', 'Physics', 'Chemistry', 'English']
                      .map((subject) => DropdownMenuItem(
                          value: subject, child: Text(subject)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedSubject = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Topic',
                    hintText: 'e.g., Calculus Integration',
                  ),
                  onChanged: (value) => selectedTopic = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Note Content',
                    hintText: 'Write your note here...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty &&
                    contentController.text.isNotEmpty) {
                  final newNote = SessionNote(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    mentor: selectedMentor,
                    subject: selectedSubject,
                    title: titleController.text,
                    content: contentController.text,
                    topic: selectedTopic.isNotEmpty
                        ? selectedTopic
                        : titleController.text,
                    date: DateTime.now(),
                    hasRecording: false,
                    isBookmarked: false,
                  );

                  ref.read(notesProvider.notifier).addNote(newNote);
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Note added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPlayer(BuildContext context,
      {String? sessionTitle, String? videoUrl}) {
    showDialog(
      context: context,
      builder: (context) => SessionVideoPlayer(
        videoUrl: videoUrl,
        sessionTitle: sessionTitle ?? 'Session Recording',
      ),
    );
  }

  void _viewNoteDetails(BuildContext context, SessionNote note) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Note Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('${note.subject} with ${note.mentor}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Topic: ${note.topic}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(note.content),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Notes'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filter options will be implemented here'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
