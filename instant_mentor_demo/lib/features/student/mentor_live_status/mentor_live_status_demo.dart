import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user.dart';
import '../../../core/providers/mentor_presence_provider.dart';
import '../../../core/providers/mentor_provider.dart';
import '../../../core/services/payment_service.dart';
import '../../common/widgets/mentor_presence_widgets.dart';
import '../../payments/payment_checkout_sheet.dart';

/// Enhanced demo screen showing mentor live status features
class MentorLiveStatusDemo extends ConsumerStatefulWidget {
  const MentorLiveStatusDemo({super.key});

  @override
  ConsumerState<MentorLiveStatusDemo> createState() =>
      _MentorLiveStatusDemoState();
}

class _MentorLiveStatusDemoState extends ConsumerState<MentorLiveStatusDemo>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Live Status'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'All Mentors'),
            Tab(icon: Icon(Icons.circle), text: 'Online Now'),
            Tab(icon: Icon(Icons.check_circle), text: 'Available'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Real-time Stats Header
          const MentorAvailabilityStats(),

          // Real-time Status Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Real-time Mentor Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Green dot = Available for instant sessions\n'
                  '• Orange dot = Online but busy\n'
                  '• Red dot = Do not disturb\n'
                  '• Grey dot = Offline\n'
                  '• Status updates every 30 seconds',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Mentor Lists with Real-time Presence
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AllMentorsTab(),
                _OnlineMentorsTab(),
                _AvailableMentorsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// All mentors with real-time presence
class _AllMentorsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentors = ref.watch(mentorsProvider);
    final presencesAsync = ref.watch(mentorPresenceProvider);

    return presencesAsync.when(
      data: (presences) => _buildMentorList(mentors, presences),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildMentorList(
      List<Mentor> mentors, Map<String, MentorPresence> presences) {
    return RefreshIndicator(
      onRefresh: () async {
        // Simulate refresh
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: mentors.length,
        itemBuilder: (context, index) {
          final mentor = mentors[index];
          return MentorPresenceCard(
            mentorId: mentor.id,
            mentorName: mentor.name,
            mentorImage: mentor.profileImage ?? '',
            specializations: mentor.specializations,
            rating: mentor.rating,
            totalSessions: mentor.totalSessions,
            hourlyRate: mentor.hourlyRate,
            onTap: () =>
                _showMentorDetails(context, mentor, presences[mentor.id]),
          );
        },
      ),
    );
  }
}

/// Online mentors only
class _OnlineMentorsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentors = ref.watch(mentorsProvider);
    final presencesAsync = ref.watch(mentorPresenceProvider);

    return presencesAsync.when(
      data: (presences) {
        final onlineMentors = mentors.where((mentor) {
          final presence = presences[mentor.id];
          return presence?.isOnline ?? false;
        }).toList();

        if (onlineMentors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No mentors online right now',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Check back in a few minutes!',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return _buildMentorList(onlineMentors, presences);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildMentorList(
      List<Mentor> mentors, Map<String, MentorPresence> presences) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: mentors.length,
        itemBuilder: (context, index) {
          final mentor = mentors[index];
          return MentorPresenceCard(
            mentorId: mentor.id,
            mentorName: mentor.name,
            mentorImage: mentor.profileImage ?? '',
            specializations: mentor.specializations,
            rating: mentor.rating,
            totalSessions: mentor.totalSessions,
            hourlyRate: mentor.hourlyRate,
            onTap: () =>
                _showMentorDetails(context, mentor, presences[mentor.id]),
          );
        },
      ),
    );
  }
}

/// Available mentors (online and accepting requests)
class _AvailableMentorsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableMentors = ref.watch(availableMentorsWithPresenceProvider);
    final presencesAsync = ref.watch(mentorPresenceProvider);

    return presencesAsync.when(
      data: (presences) {
        if (availableMentors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No mentors available right now',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'You can schedule a session for later!',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Quick Connect Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Connect Available!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'These mentors can start a session immediately',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _showQuickConnectDialog(context, availableMentors.first);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade600,
                    ),
                    child: const Text('Connect Now'),
                  ),
                ],
              ),
            ),

            // Available Mentors List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(seconds: 1));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: availableMentors.length,
                  itemBuilder: (context, index) {
                    final mentor = availableMentors[index];
                    return MentorPresenceCard(
                      mentorId: mentor.id,
                      mentorName: mentor.name,
                      mentorImage: mentor.profileImage ?? '',
                      specializations: mentor.specializations,
                      rating: mentor.rating,
                      totalSessions: mentor.totalSessions,
                      hourlyRate: mentor.hourlyRate,
                      onTap: () => _showMentorDetails(
                          context, mentor, presences[mentor.id]),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

// Helper functions
void _showMentorDetails(
    BuildContext context, Mentor mentor, MentorPresence? presence) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Mentor Header
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          mentor.name.split(' ').map((n) => n[0]).join(),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: MentorPresenceIndicator(
                          mentorId: mentor.id,
                          size: 20,
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
                          mentor.name,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star,
                                color: Colors.amber[600], size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${mentor.rating} (${mentor.totalSessions} sessions)',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MentorPresenceIndicator(
                          mentorId: mentor.id,
                          showLabel: true,
                          showCustomStatus: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bio
              Text(
                'About',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(mentor.bio),

              const SizedBox(height: 24),

              // Specializations
              Text(
                'Specializations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mentor.specializations
                    .map((spec) => Chip(
                          label: Text(spec),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ))
                    .toList(),
              ),

              const SizedBox(height: 24),

              // Availability Status
              if (presence != null) ...[
                Text(
                  'Current Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: presence.isAvailable
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: presence.isAvailable
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MentorPresenceIndicator(mentorId: mentor.id),
                          const SizedBox(width: 8),
                          Text(
                            presence.displayStatus,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (presence.activeSessionsCount > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${presence.activeSessionsCount} active session${presence.activeSessionsCount == 1 ? '' : 's'}',
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Last seen: ${_formatLastSeen(presence.lastSeen)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: presence?.isAvailable == true
                          ? () async {
                              Navigator.pop(context);
                              _showQuickConnectDialog(context, mentor);
                            }
                          : null,
                      icon: const Icon(Icons.video_call),
                      label: Text(
                        presence?.isAvailable == true
                            ? 'Start Session (₹${mentor.hourlyRate.toInt()}/hr)'
                            : 'Schedule Session',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Opening chat with ${mentor.name}')),
                      );
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showQuickConnectDialog(BuildContext context, Mentor mentor) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Quick Connect'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect instantly with ${mentor.name}?'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This mentor is available now for immediate help!',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Rate: ₹${mentor.hourlyRate.toInt()}/hour'),
          const Text('Minimum session: 15 minutes'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final confirmed = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => PaymentCheckoutSheet(
                mentorName: mentor.name,
                hourlyRate: mentor.hourlyRate.toDouble(),
                minutes: 15,
                amount: mentor.hourlyRate / 4, // 15 minute cost example
                onConfirm: () {},
              ),
            );
            if (confirmed != true) return;

            final sessionId = 'live_${DateTime.now().millisecondsSinceEpoch}';
            final ok = await PaymentService.instance.setupPaymentSheet(
              sessionId: sessionId,
              amount: mentor.hourlyRate / 4,
            );
            if (!ok) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment setup failed'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            final result =
                await PaymentService.instance.presentPaymentSheet(sessionId);
            if (!result.isSuccess) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.isCancelled
                        ? 'Payment cancelled'
                        : 'Payment failed: ${result.error ?? ''}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Starting session with ${mentor.name}...'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: const Text('Connect Now'),
        ),
      ],
    ),
  );
}

String _formatLastSeen(DateTime lastSeen) {
  final diff = DateTime.now().difference(lastSeen);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
