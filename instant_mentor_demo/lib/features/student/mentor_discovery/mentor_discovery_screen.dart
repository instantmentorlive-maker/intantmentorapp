import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user.dart';
import '../../../core/repositories/mentor_repository.dart';

class MentorDiscoveryScreen extends ConsumerWidget {
  const MentorDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(mentorSearchParamsProvider);
    final results = ref.watch(mentorSearchResultsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Filters(params: params),
            const SizedBox(height: 16),
            Expanded(
              child: results.when(
                data: (list) => ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _MentorTile(mentor: list[i]),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  final MentorSearchParams params;
  const _Filters({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: params.query ?? '');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Search (name/exam/subject)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => _update(ref, params.copyWith(query: v)),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: params.exam,
              hint: const Text('Exam'),
              items: const ['JEE', 'NEET', 'UPSC', 'SSC', 'Class 12', 'IELTS']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => _update(ref, params.copyWith(exam: v)),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: params.subject,
              hint: const Text('Subject'),
              items: const [
                'Mathematics',
                'Physics',
                'Chemistry',
                'Biology',
                'English'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => _update(ref, params.copyWith(subject: v)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: (params.minRating ?? 0).toDouble(),
                onChanged: (v) => _update(ref, params.copyWith(minRating: v)),
                divisions: 5,
                max: 5,
                label:
                    'Min rating: ${(params.minRating ?? 0).toStringAsFixed(1)}',
              ),
            ),
            const SizedBox(width: 8),
            Row(children: [
              const Text('Available'),
              Switch(
                value: params.onlyAvailable ?? false,
                onChanged: (v) =>
                    _update(ref, params.copyWith(onlyAvailable: v)),
              ),
            ]),
          ],
        ),
      ],
    );
  }

  void _update(WidgetRef ref, MentorSearchParams p) {
    ref.read(mentorSearchParamsProvider.notifier).state = p.copyWith(offset: 0);
  }
}

class _MentorTile extends StatelessWidget {
  final Mentor mentor;
  const _MentorTile({required this.mentor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
              radius: 24,
              child: Text(mentor.name.isNotEmpty ? mentor.name[0] : '?')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mentor.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(mentor.specializations.join(', '),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(mentor.rating.toStringAsFixed(1)),
                    const SizedBox(width: 8),
                    Text('${mentor.yearsOfExperience} yrs exp')
                  ],
                )
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${mentor.hourlyRate.toStringAsFixed(0)}/hr'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: mentor.isAvailable
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  mentor.isAvailable ? 'Available' : 'Busy',
                  style: TextStyle(
                      color: mentor.isAvailable ? Colors.green : Colors.red),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
