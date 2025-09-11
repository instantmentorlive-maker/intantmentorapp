import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/scheduling_service.dart';

final schedulingServiceProvider = Provider((ref) => SchedulingService.instance);

final availableSlotsProvider = FutureProvider.family
    .autoDispose<List<DateTime>, ({String mentorId, DateTime date, int slotMinutes, int durationMinutes})>((ref, args) async {
  // Recompute when sessions change for this mentor/date via realtime
  final client = Supabase.instance.client;
  final channel = client.channel('public:mentoring_sessions:slots:${args.mentorId}')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'mentoring_sessions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'mentor_id',
        value: args.mentorId,
      ),
      callback: (_) => ref.invalidateSelf(),
    )
    ..subscribe();
  ref.onDispose(() => client.removeChannel(channel));

  final service = ref.read(schedulingServiceProvider);
  return service.listAvailableSlots(
    mentorId: args.mentorId,
    date: args.date,
    slotMinutes: args.slotMinutes,
    durationMinutes: args.durationMinutes,
  );
});
