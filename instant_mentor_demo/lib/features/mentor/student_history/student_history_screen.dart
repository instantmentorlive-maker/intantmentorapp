import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mock data for student history
final studentHistoryProvider = StateProvider<List<Map<String, dynamic>>>((ref) => [
  {
    'id': '1',
    'studentName': 'Alex Chen',
    'subject': 'Mathematics',
    'date': DateTime.now().subtract(const Duration(days: 1)),
    'duration': 60,
    'status': 'Completed',
    'rating': 5,
    'notes': 'Great progress on calculus concepts. Student showed excellent understanding of derivatives.',
    'topics': ['Derivatives', 'Chain Rule', 'Product Rule'],
    'nextSession': DateTime.now().add(const Duration(days: 7)),
  },
  {
    'id': '2',
    'studentName': 'Maria Rodriguez',
    'subject': 'Physics',
    'date': DateTime.now().subtract(const Duration(days: 3)),
    'duration': 45,
    'status': 'Completed',
    'rating': 4,
    'notes': 'Worked on Newton\'s laws. Student needs more practice with force diagrams.',
    'topics': ['Newton\'s Laws', 'Force Diagrams', 'Momentum'],
    'nextSession': DateTime.now().add(const Duration(days: 5)),
  },
  {
    'id': '3',
    'studentName': 'James Wilson',
    'subject': 'Chemistry',
    'date': DateTime.now().subtract(const Duration(days: 5)),
    'duration': 50,
    'status': 'Completed',
    'rating': 5,
    'notes': 'Excellent session on organic chemistry. Student mastered nomenclature quickly.',
    'topics': ['Organic Chemistry', 'Nomenclature', 'Functional Groups'],
    'nextSession': null,
  },
  {
    'id': '4',
    'studentName': 'Emily Davis',
    'subject': 'Mathematics',
    'date': DateTime.now().subtract(const Duration(days: 7)),
    'duration': 45,
    'status': 'Completed',
    'rating': 4,
    'notes': 'Covered statistics basics. Student showed good progress in data analysis.',
    'topics': ['Statistics', 'Data Analysis', 'Probability'],
    'nextSession': DateTime.now().add(const Duration(days: 3)),
  },
  {
    'id': '5',
    'studentName': 'David Kim',
    'subject': 'Physics',
    'date': DateTime.now().add(const Duration(days: 2)),
    'duration': 60,
    'status': 'Scheduled',
    'rating': 0,
    'notes': '',
    'topics': ['Quantum Physics', 'Wave Function'],
    'nextSession': null,
  },
]);

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedSubjectFilterProvider = StateProvider<String>((ref) => 'All');
final selectedStatusFilterProvider = StateProvider<String>((ref) => 'All');

class StudentHistoryScreen extends ConsumerWidget {
  const StudentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentHistory = ref.watch(studentHistoryProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final subjectFilter = ref.watch(selectedSubjectFilterProvider);
    final statusFilter = ref.watch(selectedStatusFilterProvider);
    
    final filteredHistory = _filterHistory(studentHistory, searchQuery, subjectFilter, statusFilter);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student History'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                  },
                ),
                const SizedBox(height: 12),
                
                // Filters
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Subject',
                        subjectFilter,
                        ['All', 'Mathematics', 'Physics', 'Chemistry'],
                        (value) => ref.read(selectedSubjectFilterProvider.notifier).state = value!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Status',
                        statusFilter,
                        ['All', 'Completed', 'Scheduled', 'Cancelled'],
                        (value) => ref.read(selectedStatusFilterProvider.notifier).state = value!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Statistics Summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatCard('Total Sessions', '${studentHistory.length}', Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('This Week', '${_getThisWeekCount(studentHistory)}', Colors.green),
                const SizedBox(width: 12),
                _buildStatCard('Avg Rating', _getAverageRating(studentHistory).toStringAsFixed(1), Colors.amber),
              ],
            ),
          ),
          
          // History List
          Expanded(
            child: filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No sessions found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final session = filteredHistory[index];
                      return _buildSessionCard(context, session);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, Map<String, dynamic> session) {
    final isUpcoming = session['status'] == 'Scheduled';
    final statusColor = _getStatusColor(session['status']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showSessionDetails(context, session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: Text(
                      session['studentName'].toString().split(' ').map((n) => n[0]).join(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['studentName'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          session['subject'],
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      session['status'],
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Session Details
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(session['date']),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 20),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${session['duration']} min',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (!isUpcoming && session['rating'] > 0) ...[
                    const SizedBox(width: 20),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${session['rating']}/5',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              
              if (session['topics'] != null && (session['topics'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (session['topics'] as List).map((topic) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      topic.toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  )).toList(),
                ),
              ],
              
              if (session['nextSession'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Next session: ${_formatDate(session['nextSession'])}',
                        style: const TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterHistory(
    List<Map<String, dynamic>> history,
    String searchQuery,
    String subjectFilter,
    String statusFilter,
  ) {
    return history.where((session) {
      final matchesSearch = searchQuery.isEmpty ||
          session['studentName'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          session['subject'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      
      final matchesSubject = subjectFilter == 'All' || session['subject'] == subjectFilter;
      final matchesStatus = statusFilter == 'All' || session['status'] == statusFilter;
      
      return matchesSearch && matchesSubject && matchesStatus;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Scheduled':
        return Colors.blue;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference == -1) {
      return 'Tomorrow';
    } else if (difference > 0) {
      return '$difference days ago';
    } else {
      return 'In ${-difference} days';
    }
  }

  int _getThisWeekCount(List<Map<String, dynamic>> history) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return history.where((session) {
      final sessionDate = session['date'] as DateTime;
      return sessionDate.isAfter(weekStart) && sessionDate.isBefore(now.add(const Duration(days: 1)));
    }).length;
  }

  double _getAverageRating(List<Map<String, dynamic>> history) {
    final ratedSessions = history.where((session) => session['rating'] > 0).toList();
    if (ratedSessions.isEmpty) return 0.0;
    
    final totalRating = ratedSessions.fold<int>(0, (sum, session) => sum + (session['rating'] as int));
    return totalRating / ratedSessions.length;
  }

  void _showSessionDetails(BuildContext context, Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${session['studentName']} - ${session['subject']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Date', _formatDate(session['date'])),
              _buildDetailRow('Duration', '${session['duration']} minutes'),
              _buildDetailRow('Status', session['status']),
              if (session['rating'] > 0)
                _buildDetailRow('Rating', '${session['rating']}/5 stars'),
              if (session['topics'] != null)
                _buildDetailRow('Topics', (session['topics'] as List).join(', ')),
              if (session['notes'].isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Session Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(session['notes']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (session['status'] == 'Scheduled')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _joinSession(context, session);
              },
              child: const Text('Join Session'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _joinSession(BuildContext context, Map<String, dynamic> session) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Joining session with ${session['studentName']}...'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
