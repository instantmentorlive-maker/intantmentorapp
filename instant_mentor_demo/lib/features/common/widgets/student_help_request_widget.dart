import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/websocket_service.dart';

/// Provider for WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService.instance;
});

/// Widget for students to request help from mentors
class StudentHelpRequestWidget extends ConsumerStatefulWidget {
  final String? mentorId;
  final String? mentorName;

  const StudentHelpRequestWidget({
    super.key,
    this.mentorId,
    this.mentorName,
  });

  @override
  ConsumerState<StudentHelpRequestWidget> createState() =>
      _StudentHelpRequestWidgetState();
}

class _StudentHelpRequestWidgetState
    extends ConsumerState<StudentHelpRequestWidget> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedUrgency = 'medium';
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    // Only show for students
    if (user?.userMetadata?['role'] != 'student') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.help_outline,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Help',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            widget.mentorName != null
                                ? 'From ${widget.mentorName}'
                                : 'From available mentors',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Subject Input
                Material(
                  color: Colors.transparent,
                  child: TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject *',
                      hintText: 'What do you need help with?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.subject),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Message Input
                Material(
                  color: Colors.transparent,
                  child: TextField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Message (optional)',
                      hintText: 'Provide more details about your question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Urgency Selection
                Text(
                  'Urgency Level:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildUrgencyChip('low', 'Low', Colors.green),
                      const SizedBox(width: 8),
                      _buildUrgencyChip('medium', 'Medium', Colors.orange),
                      const SizedBox(width: 8),
                      _buildUrgencyChip('high', 'Urgent', Colors.red),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Quick Help Buttons
                Text(
                  'Quick Actions:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickActionButton(
                      'Math Help',
                      Icons.calculate,
                      () => _sendQuickRequest(
                          'Math Help', 'I need help with mathematics'),
                    ),
                    _buildQuickActionButton(
                      'Programming',
                      Icons.code,
                      () => _sendQuickRequest(
                          'Programming Help', 'I need coding assistance'),
                    ),
                    _buildQuickActionButton(
                      'Science',
                      Icons.science,
                      () => _sendQuickRequest(
                          'Science Help', 'I need help with science concepts'),
                    ),
                    _buildQuickActionButton(
                      'General',
                      Icons.school,
                      () => _sendQuickRequest(
                          'General Question', 'I have a general question'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendHelpRequest,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Help Request'),
                  ),
                ),
              ],
            ),
          ), // End of SingleChildScrollView
        ), // End of ScrollConfiguration
      ),
    );
  }

  Widget _buildUrgencyChip(String value, String label, Color color) {
    final isSelected = _selectedUrgency == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedUrgency = value),
      child: Container(
        constraints: const BoxConstraints(minWidth: 80), // Ensure minimum width
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
      String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendQuickRequest(String subject, String message) {
    _subjectController.text = subject;
    _messageController.text = message;
    _sendHelpRequest();
  }

  void _sendHelpRequest() async {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a subject for your help request'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final webSocketService = ref.read(webSocketServiceProvider);
      final user = ref.read(authProvider).user;

      // If no specific mentor, broadcast to all available mentors
      final targetMentorId = widget.mentorId ?? 'broadcast_to_mentors';

      await webSocketService.requestHelp(
        mentorId: targetMentorId,
        subject: subject,
        message: _messageController.text.trim(),
        urgency: _selectedUrgency,
        requestData: {
          'studentId': user?.id,
          'studentName': user?.userMetadata?['full_name'] ?? 'Unknown Student',
          'timestamp': DateTime.now().toIso8601String(),
          'requestType': widget.mentorId != null ? 'direct' : 'broadcast',
        },
      );

      // Clear form
      _subjectController.clear();
      _messageController.clear();
      setState(() => _selectedUrgency = 'medium');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mentorId != null
                  ? '✅ Help request sent to ${widget.mentorName}'
                  : '✅ Help request sent to available mentors',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to send help request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to send help request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
