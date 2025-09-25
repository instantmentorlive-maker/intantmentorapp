import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/websocket_service.dart';

/// Provider for WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService.instance;
});

/// Provider for mentor availability status
final mentorStatusProvider =
    StateNotifierProvider<MentorStatusNotifier, MentorStatus>((ref) {
  return MentorStatusNotifier();
});

/// Mentor status data model
class MentorStatus {
  final bool isAvailable;
  final String statusMessage;
  final DateTime lastUpdated;

  const MentorStatus({
    required this.isAvailable,
    required this.statusMessage,
    required this.lastUpdated,
  });

  MentorStatus copyWith({
    bool? isAvailable,
    String? statusMessage,
    DateTime? lastUpdated,
  }) {
    return MentorStatus(
      isAvailable: isAvailable ?? this.isAvailable,
      statusMessage: statusMessage ?? this.statusMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// State notifier for mentor status
class MentorStatusNotifier extends StateNotifier<MentorStatus> {
  MentorStatusNotifier()
      : super(MentorStatus(
          isAvailable: false,
          statusMessage: 'Offline',
          lastUpdated: DateTime.now(),
        ));

  void updateStatus(bool isAvailable, String statusMessage) {
    state = state.copyWith(
      isAvailable: isAvailable,
      statusMessage: statusMessage,
      lastUpdated: DateTime.now(),
    );
  }
}

/// Widget for mentors to manage their availability status
class MentorStatusWidget extends ConsumerStatefulWidget {
  const MentorStatusWidget({super.key});

  @override
  ConsumerState<MentorStatusWidget> createState() => _MentorStatusWidgetState();
}

class _MentorStatusWidgetState extends ConsumerState<MentorStatusWidget> {
  final TextEditingController _statusController = TextEditingController();

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mentorStatus = ref.watch(mentorStatusProvider);
    final user = ref.watch(authProvider).user;

    // Only show for mentors
    if (user?.userMetadata?['role'] != 'mentor') {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mentorStatus.isAvailable
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    mentorStatus.isAvailable
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: mentorStatus.isAvailable ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mentor Status',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        mentorStatus.isAvailable ? 'Available' : 'Busy',
                        style: TextStyle(
                          color: mentorStatus.isAvailable
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: mentorStatus.isAvailable,
                  onChanged: (value) => _updateAvailability(value),
                  activeThumbColor: Colors.green,
                  activeTrackColor: Colors.green.withValues(alpha: 0.3),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Current Status Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: mentorStatus.isAvailable
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                mentorStatus.statusMessage,
                style: const TextStyle(fontSize: 14),
              ),
            ),

            const SizedBox(height: 16),

            // Quick Status Buttons
            Text(
              'Quick Status:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickStatusChip(
                    'Available for sessions', true, Colors.green),
                _buildQuickStatusChip('In a session', false, Colors.orange),
                _buildQuickStatusChip('Taking a break', false, Colors.blue),
                _buildQuickStatusChip('Offline', false, Colors.red),
              ],
            ),

            const SizedBox(height: 16),

            // Custom Status Input
            TextField(
              controller: _statusController,
              decoration: InputDecoration(
                hintText: 'Enter custom status message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  onPressed: () => _setCustomStatus(),
                  icon: const Icon(Icons.send),
                ),
              ),
              onSubmitted: (_) => _setCustomStatus(),
            ),

            const SizedBox(height: 12),

            // Last Updated
            Text(
              'Last updated: ${_formatTime(mentorStatus.lastUpdated)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatusChip(String label, bool isAvailable, Color color) {
    final mentorStatus = ref.watch(mentorStatusProvider);
    final isSelected = mentorStatus.statusMessage == label;

    return GestureDetector(
      onTap: () => _setQuickStatus(label, isAvailable),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : null,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _updateAvailability(bool isAvailable) async {
    final newMessage =
        isAvailable ? 'Available for sessions' : 'Currently busy';

    // Update local state
    ref
        .read(mentorStatusProvider.notifier)
        .updateStatus(isAvailable, newMessage);

    // Send to WebSocket
    await _sendStatusUpdate(isAvailable, newMessage);
  }

  void _setQuickStatus(String message, bool isAvailable) async {
    // Update local state
    ref.read(mentorStatusProvider.notifier).updateStatus(isAvailable, message);

    // Send to WebSocket
    await _sendStatusUpdate(isAvailable, message);
  }

  void _setCustomStatus() async {
    final customMessage = _statusController.text.trim();
    if (customMessage.isEmpty) return;

    final isAvailable = ref.read(mentorStatusProvider).isAvailable;

    // Update local state
    ref.read(mentorStatusProvider.notifier).updateStatus(
          isAvailable,
          customMessage,
        );

    // Send to WebSocket
    await _sendStatusUpdate(isAvailable, customMessage);

    // Clear input
    _statusController.clear();
  }

  Future<void> _sendStatusUpdate(bool isAvailable, String statusMessage) async {
    try {
      final webSocketService = ref.read(webSocketServiceProvider);

      await webSocketService.updateMentorStatus(
        isAvailable: isAvailable,
        statusMessage: statusMessage,
        statusData: {
          'userId': ref.read(authProvider).user?.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Status updated: $statusMessage'),
            backgroundColor: isAvailable ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to update mentor status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
