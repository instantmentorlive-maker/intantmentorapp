import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/mentor_presence_provider.dart';
import '../../../core/realtime/messaging_service.dart';

/// Enhanced mentor presence indicator widget
class MentorPresenceIndicator extends ConsumerWidget {
  final String mentorId;
  final double size;
  final bool showLabel;
  final bool showCustomStatus;

  const MentorPresenceIndicator({
    super.key,
    required this.mentorId,
    this.size = 16,
    this.showLabel = false,
    this.showCustomStatus = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(mentorPresenceByIdProvider(mentorId));

    if (presence == null) {
      return const SizedBox.shrink();
    }

    final color = _getPresenceColor(presence.status);
    final isAvailable = presence.isAvailable;

    if (showLabel || showCustomStatus) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(color, isAvailable),
          if (showLabel || showCustomStatus) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                showCustomStatus && presence.customStatus != null
                    ? presence.customStatus!
                    : presence.displayStatus,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    return _buildDot(color, isAvailable);
  }

  Widget _buildDot(Color color, bool isAvailable) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: size > 12 ? 2 : 1,
        ),
        boxShadow: isAvailable
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: isAvailable
          ? Icon(
              Icons.check,
              size: size * 0.6,
              color: Colors.white,
            )
          : null,
    );
  }

  Color _getPresenceColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return Colors.green;
      case PresenceStatus.away:
        return Colors.orange;
      case PresenceStatus.busy:
        return Colors.red;
      case PresenceStatus.offline:
        return Colors.grey;
    }
  }
}

/// Enhanced mentor card with real-time presence
class MentorPresenceCard extends ConsumerWidget {
  final String mentorId;
  final String mentorName;
  final String mentorImage;
  final List<String> specializations;
  final double rating;
  final int totalSessions;
  final double hourlyRate;
  final VoidCallback? onTap;

  const MentorPresenceCard({
    super.key,
    required this.mentorId,
    required this.mentorName,
    required this.mentorImage,
    required this.specializations,
    required this.rating,
    required this.totalSessions,
    required this.hourlyRate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(mentorPresenceByIdProvider(mentorId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Profile Image with Presence Indicator
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          mentorName.split(' ').map((n) => n[0]).join(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: MentorPresenceIndicator(
                          mentorId: mentorId,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Mentor Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mentorName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star,
                                color: Colors.amber[600], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$rating ($totalSessions sessions)',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        MentorPresenceIndicator(
                          mentorId: mentorId,
                          showLabel: true,
                          showCustomStatus: true,
                        ),
                      ],
                    ),
                  ),

                  // Price and Availability
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${hourlyRate.toInt()}/hr',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildAvailabilityChip(context, presence),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Specializations
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: specializations.take(3).map((subject) {
                    return Chip(
                      label: Text(
                        subject,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    );
                  }).toList(),
                ),
              ),

              if (presence?.activeSessionsCount != null &&
                  presence!.activeSessionsCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.group,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${presence.activeSessionsCount} active session${presence.activeSessionsCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityChip(
      BuildContext context, MentorPresence? presence) {
    if (presence == null) {
      return const Chip(
        label: Text('Unknown'),
        backgroundColor: Colors.grey,
      );
    }

    Color backgroundColor;
    Color textColor;
    String label = presence.displayStatus;

    if (presence.isAvailable) {
      backgroundColor = Colors.green.withValues(alpha: 0.1);
      textColor = Colors.green;
    } else if (presence.isOnline) {
      backgroundColor = Colors.orange.withValues(alpha: 0.1);
      textColor = Colors.orange;
    } else {
      backgroundColor = Colors.grey.withValues(alpha: 0.1);
      textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Real-time mentor availability stats widget
class MentorAvailabilityStats extends ConsumerWidget {
  const MentorAvailabilityStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineCount = ref.watch(onlineMentorsCountProvider);
    final availableCount = ref.watch(availableMentorsCountProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.circle,
            iconColor: Colors.green,
            label: 'Online',
            value: onlineCount.toString(),
          ),
          _StatItem(
            icon: Icons.check_circle,
            iconColor: Colors.blue,
            label: 'Available',
            value: availableCount.toString(),
          ),
          _StatItem(
            icon: Icons.schedule,
            iconColor: Colors.orange,
            label: 'Avg Response',
            value: '< 2min',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
