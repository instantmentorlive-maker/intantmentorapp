import 'dart:math' as math;

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

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mentor': mentor,
      'subject': subject,
      'title': title,
      'content': content,
      'topic': topic,
      'date': date.toIso8601String(),
      'hasRecording': hasRecording,
      'isBookmarked': isBookmarked,
      'videoUrl': videoUrl,
    };
  }

  factory SessionNote.fromJson(Map<String, dynamic> json) {
    return SessionNote(
      id: json['id'],
      mentor: json['mentor'],
      subject: json['subject'],
      title: json['title'],
      content: json['content'],
      topic: json['topic'],
      date: DateTime.parse(json['date']),
      hasRecording: json['hasRecording'] ?? false,
      isBookmarked: json['isBookmarked'] ?? false,
      videoUrl: json['videoUrl'],
    );
  }
}

// Provider for notes
final notesProvider =
    StateNotifierProvider<NotesNotifier, List<SessionNote>>((ref) {
  return NotesNotifier();
});

// Provider for filtered notes
final filteredNotesProvider = Provider<List<SessionNote>>((ref) {
  final notes = ref.watch(notesProvider);
  final filter = ref.watch(filterStateProvider);

  return notes.where((note) {
    // Filter by subject
    if (filter.selectedSubject != null &&
        note.subject != filter.selectedSubject) {
      return false;
    }

    // Filter by mentor
    if (filter.selectedMentor != null && note.mentor != filter.selectedMentor) {
      return false;
    }

    // Filter by date range
    if (filter.dateRange != null) {
      final noteDate = DateTime(note.date.year, note.date.month, note.date.day);
      final startDate = DateTime(filter.dateRange!.start.year,
          filter.dateRange!.start.month, filter.dateRange!.start.day);
      final endDate = DateTime(filter.dateRange!.end.year,
          filter.dateRange!.end.month, filter.dateRange!.end.day);

      if (noteDate.isBefore(startDate) || noteDate.isAfter(endDate)) {
        return false;
      }
    }

    // Filter by bookmarked
    if (filter.showBookmarkedOnly && !note.isBookmarked) {
      return false;
    }

    // Filter by recording
    if (filter.showWithRecordingOnly && !note.hasRecording) {
      return false;
    }

    return true;
  }).toList();
});

class NotesNotifier extends StateNotifier<List<SessionNote>> {
  NotesNotifier() : super([]) {
    _loadNotes();
  }

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

  void _loadNotes() {
    try {
      // For web, we'll use browser localStorage via dart:html
      // For simplicity, let's start with the default notes and then add to them
      state = [..._defaultNotes];
      print('Loaded ${state.length} notes');
    } catch (e) {
      print('Error loading notes: $e');
      state = [..._defaultNotes];
    }
  }

  void _saveNotes() {
    try {
      // For now, just log the save action
      // In a real app, you'd save to SharedPreferences or a database
      print('Saving ${state.length} notes');
    } catch (e) {
      print('Error saving notes: $e');
    }
  }

  void addNote(SessionNote note) {
    print(
        'Adding note: ${note.title} - ${note.content.substring(0, math.min(50, note.content.length))}...');
    state = [note, ...state];
    _saveNotes();
    print('Notes count after adding: ${state.length}');
  }

  void toggleBookmark(String noteId) {
    state = state.map((note) {
      if (note.id == noteId) {
        return note.copyWith(isBookmarked: !note.isBookmarked);
      }
      return note;
    }).toList();
    _saveNotes();
  }
}

class SessionNotesScreen extends ConsumerWidget {
  const SessionNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(filteredNotesProvider);
    final filter = ref.watch(filterStateProvider);

    // Check if any filters are active
    final hasActiveFilters = filter.selectedSubject != null ||
        filter.selectedMentor != null ||
        filter.dateRange != null ||
        filter.showBookmarkedOnly ||
        filter.showWithRecordingOnly;

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
                Stack(
                  children: [
                    IconButton(
                      onPressed: () => _showFilterDialog(context),
                      icon: Icon(
                        Icons.filter_list,
                        color: hasActiveFilters
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    if (hasActiveFilters)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
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

            // Filter status message
            if (hasActiveFilters) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filters applied - Showing ${notes.length} filtered notes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(filterStateProvider.notifier).state =
                            const FilterState();
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 24),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child:
                          const Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

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
                  decoration: const InputDecoration(
                    labelText: 'Select Mentor',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: selectedMentor,
                  items: [
                    'Dr. Sarah Smith',
                    'Prof. Raj Kumar',
                    'Dr. Priya Sharma',
                    'Mr. Vikash Singh'
                  ]
                      .map((mentor) =>
                          DropdownMenuItem(value: mentor, child: Text(mentor)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedMentor = value);
                      print('Selected mentor: $value');
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Subject',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: selectedSubject,
                  items: ['Mathematics', 'Physics', 'Chemistry', 'English']
                      .map((subject) => DropdownMenuItem(
                          value: subject, child: Text(subject)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedSubject = value);
                      print('Selected subject: $value');
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Topic',
                    hintText: 'e.g., Calculus Integration',
                    border: OutlineInputBorder(),
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
                    border: OutlineInputBorder(),
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
                // Debug: Check what values we have
                print('Title: "${titleController.text}"');
                print('Content: "${contentController.text}"');
                print('Mentor: "$selectedMentor"');
                print('Subject: "$selectedSubject"');

                if (titleController.text.trim().isNotEmpty &&
                    contentController.text.trim().isNotEmpty &&
                    selectedMentor.isNotEmpty &&
                    selectedSubject.isNotEmpty) {
                  final newNote = SessionNote(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    mentor: selectedMentor,
                    subject: selectedSubject,
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    topic: selectedTopic.isNotEmpty
                        ? selectedTopic.trim()
                        : titleController.text.trim(),
                    date: DateTime.now(),
                  );

                  try {
                    ref.read(notesProvider.notifier).addNote(newNote);
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note saved successfully!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    print('Error saving note: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving note: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  // Show validation error
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Please fill in both title and content fields'),
                      backgroundColor: Colors.orange,
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
      builder: (context) => _FilterNotesDialog(),
    );
  }
}

// Filter state provider
class FilterState {
  final String? selectedSubject;
  final String? selectedMentor;
  final DateTimeRange? dateRange;
  final bool showBookmarkedOnly;
  final bool showWithRecordingOnly;

  const FilterState({
    this.selectedSubject,
    this.selectedMentor,
    this.dateRange,
    this.showBookmarkedOnly = false,
    this.showWithRecordingOnly = false,
  });

  FilterState copyWith({
    String? selectedSubject,
    String? selectedMentor,
    DateTimeRange? dateRange,
    bool? showBookmarkedOnly,
    bool? showWithRecordingOnly,
  }) {
    return FilterState(
      selectedSubject: selectedSubject ?? this.selectedSubject,
      selectedMentor: selectedMentor ?? this.selectedMentor,
      dateRange: dateRange ?? this.dateRange,
      showBookmarkedOnly: showBookmarkedOnly ?? this.showBookmarkedOnly,
      showWithRecordingOnly:
          showWithRecordingOnly ?? this.showWithRecordingOnly,
    );
  }
}

final filterStateProvider =
    StateProvider<FilterState>((ref) => const FilterState());

class _FilterNotesDialog extends ConsumerStatefulWidget {
  @override
  _FilterNotesDialogState createState() => _FilterNotesDialogState();
}

class _FilterNotesDialogState extends ConsumerState<_FilterNotesDialog> {
  late FilterState _tempFilter;

  @override
  void initState() {
    super.initState();
    _tempFilter = ref.read(filterStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);

    // Get unique subjects and mentors from notes
    final subjects = notes.map((note) => note.subject).toSet().toList()..sort();
    final mentors = notes.map((note) => note.mentor).toSet().toList()..sort();

    return AlertDialog(
      title: const Text('Filter Notes'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject Filter
            const Text('Subject:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _tempFilter.selectedSubject,
              decoration: const InputDecoration(
                hintText: 'All Subjects',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(
                  child: Text('All Subjects'),
                ),
                ...subjects.map((subject) => DropdownMenuItem<String>(
                      value: subject,
                      child: Text(subject),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _tempFilter = _tempFilter.copyWith(selectedSubject: value);
                });
              },
            ),

            const SizedBox(height: 16),

            // Mentor Filter
            const Text('Mentor:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _tempFilter.selectedMentor,
              decoration: const InputDecoration(
                hintText: 'All Mentors',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(
                  child: Text('All Mentors'),
                ),
                ...mentors.map((mentor) => DropdownMenuItem<String>(
                      value: mentor,
                      child: Text(mentor),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _tempFilter = _tempFilter.copyWith(selectedMentor: value);
                });
              },
            ),

            const SizedBox(height: 16),

            // Date Range Filter
            const Text('Date Range:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _tempFilter.dateRange,
                );
                if (picked != null) {
                  setState(() {
                    _tempFilter = _tempFilter.copyWith(dateRange: picked);
                  });
                }
              },
              child: Text(
                _tempFilter.dateRange != null
                    ? '${_tempFilter.dateRange!.start.day}/${_tempFilter.dateRange!.start.month}/${_tempFilter.dateRange!.start.year} - ${_tempFilter.dateRange!.end.day}/${_tempFilter.dateRange!.end.month}/${_tempFilter.dateRange!.end.year}'
                    : 'Select Date Range',
              ),
            ),

            if (_tempFilter.dateRange != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _tempFilter = _tempFilter.copyWith();
                  });
                },
                child: const Text('Clear Date Range'),
              ),
            ],

            const SizedBox(height: 16),

            // Toggle Filters
            CheckboxListTile(
              title: const Text('Show only bookmarked notes'),
              value: _tempFilter.showBookmarkedOnly,
              onChanged: (value) {
                setState(() {
                  _tempFilter =
                      _tempFilter.copyWith(showBookmarkedOnly: value ?? false);
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

            CheckboxListTile(
              title: const Text('Show only notes with recordings'),
              value: _tempFilter.showWithRecordingOnly,
              onChanged: (value) {
                setState(() {
                  _tempFilter = _tempFilter.copyWith(
                      showWithRecordingOnly: value ?? false);
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Clear all filters
            setState(() {
              _tempFilter = const FilterState();
            });
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Apply filters
            ref.read(filterStateProvider.notifier).state = _tempFilter;
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
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
