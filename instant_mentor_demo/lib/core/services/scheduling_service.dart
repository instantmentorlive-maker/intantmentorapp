import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_tracker.dart';

class SchedulingService {
  SchedulingService._();
  static final instance = SchedulingService._();
  final _db = Supabase.instance.client;

  Future<void> setWeeklyAvailability({
    required String mentorId,
    required Map<int, ({TimeOfDay start, TimeOfDay end, bool enabled})> days,
    String timezone = 'UTC',
  }) async {
    for (final entry in days.entries) {
      final d = entry.value;
      final start = _timeOfDayToString(d.start);
      final end = _timeOfDayToString(d.end);
      await _db.from('mentor_availability').upsert({
        'mentor_id': mentorId,
        'day_of_week': entry.key,
        'start_time': start,
        'end_time': end,
        'is_enabled': d.enabled,
        'timezone': timezone,
      });
    }
  }

  Future<Map<int, ({TimeOfDay start, TimeOfDay end, bool enabled})>> getWeeklyAvailability(String mentorId) async {
    final rows = await _db
        .from('mentor_availability')
        .select('day_of_week, start_time, end_time, is_enabled, timezone')
        .eq('mentor_id', mentorId);
    final map = <int, ({TimeOfDay start, TimeOfDay end, bool enabled})>{};
    for (final r in rows) {
      map[r['day_of_week'] as int] = (
        start: _parseTime(r['start_time'] as String),
        end: _parseTime(r['end_time'] as String),
        enabled: r['is_enabled'] as bool? ?? true,
      );
    }
    return map;
  }

  Future<List<DateTime>> listAvailableSlots({
    required String mentorId,
    required DateTime date,
    required int slotMinutes,
    required int durationMinutes,
  }) async {
    // Get weekly availability for the weekday
    final weekday = (date.weekday + 6) % 7; // Monday=0..Sunday=6
    final avail = await _db
        .from('mentor_availability')
        .select('start_time, end_time, is_enabled')
        .eq('mentor_id', mentorId)
        .eq('day_of_week', weekday)
        .maybeSingle();
    if (avail == null || (avail['is_enabled'] as bool? ?? false) == false) return [];

    // Build day window
    final startTod = _parseTime(avail['start_time'] as String);
    final endTod = _parseTime(avail['end_time'] as String);
    final dayStart = DateTime(date.year, date.month, date.day, startTod.hour, startTod.minute);
    final dayEnd = DateTime(date.year, date.month, date.day, endTod.hour, endTod.minute);

    // Fetch existing sessions for mentor on that day (exclude cancelled/declined)
    final nextDay = dayStart.add(const Duration(days: 1));
    final existing = await _db
        .from('mentoring_sessions')
        .select('scheduled_time, duration_minutes, status')
        .gte('scheduled_time', dayStart.toIso8601String())
        .lt('scheduled_time', nextDay.toIso8601String())
        .eq('mentor_id', mentorId)
        .not('status', 'in', '("cancelled","declined")');

    // Fetch time-off blocks
    final timeOff = await _db
        .from('mentor_time_off')
        .select('start_at, end_at')
        .eq('mentor_id', mentorId)
        .or('and(start_at.gte.${dayStart.toIso8601String()},start_at.lt.${nextDay.toIso8601String()}),and(end_at.gt.${dayStart.toIso8601String()},end_at.lte.${nextDay.toIso8601String()})');

    bool conflicts(DateTime start, DateTime end) {
      for (final s in existing) {
        final sStart = DateTime.parse(s['scheduled_time'] as String);
        final sEnd = sStart.add(Duration(minutes: (s['duration_minutes'] as int?) ?? 0));
        if (_overlaps(start, end, sStart, sEnd)) return true;
      }
      for (final b in timeOff) {
        final bStart = DateTime.parse(b['start_at'] as String);
        final bEnd = DateTime.parse(b['end_at'] as String);
        if (_overlaps(start, end, bStart, bEnd)) return true;
      }
      return false;
    }

    final slots = <DateTime>[];
    for (DateTime t = dayStart; t.add(Duration(minutes: durationMinutes)).isBefore(dayEnd) ||
        t.add(Duration(minutes: durationMinutes)).isAtSameMomentAs(dayEnd); t = t.add(Duration(minutes: slotMinutes))) {
      final end = t.add(Duration(minutes: durationMinutes));
      if (t.isAfter(DateTime.now())) {
        if (!conflicts(t, end)) slots.add(t);
      }
    }
    return slots;
  }

  Future<Map<String, dynamic>> bookSessionSlot({
    required String studentId,
    required String mentorId,
    required DateTime start,
    required int durationMinutes,
    String? subject,
    String? description,
  }) async {
    // Double-check conflicts server-side via RPC (optional); for now, naive check
    final end = start.add(Duration(minutes: durationMinutes));
    final existing = await _db
        .from('mentoring_sessions')
        .select('scheduled_time, duration_minutes, status')
        .eq('mentor_id', mentorId)
        .gte('scheduled_time', start.toIso8601String())
        .lt('scheduled_time', end.toIso8601String());
    if (existing.isNotEmpty) {
      throw Exception('Selected time overlaps with another session');
    }

    final row = await _db
        .from('mentoring_sessions')
        .insert({
          'mentor_id': mentorId,
          'student_id': studentId,
          'scheduled_time': start.toIso8601String(),
          'duration_minutes': durationMinutes,
          'subject': subject,
          'description': description,
          'status': 'scheduled',
        })
        .select()
        .single();
    // Track event
    final sid = row['id']?.toString() ?? '';
    if (sid.isNotEmpty) {
      unawaited(
          AnalyticsTracker.instance.sessionCreated(sid, studentId, mentorId));
    }
    return row;
  }

  static bool _overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  static TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _timeOfDayToString(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }
}
