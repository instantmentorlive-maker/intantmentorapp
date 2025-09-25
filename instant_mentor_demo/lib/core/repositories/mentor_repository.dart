import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/supabase_service.dart';

class MentorSearchParams {
  final String? query; // free text or exam tag
  final String? exam; // JEE, NEET, UPSC, SSC, etc.
  final String? subject; // Mathematics, Physics, etc.
  final double? minRating;
  final int? minExperience;
  final bool? onlyAvailable;
  final int limit;
  final int offset;
  final String sort; // rating_desc | experience_desc | price_asc

  const MentorSearchParams({
    this.query,
    this.exam,
    this.subject,
    this.minRating,
    this.minExperience,
    this.onlyAvailable,
    this.limit = 20,
    this.offset = 0,
    this.sort = 'rating_desc',
  });

  MentorSearchParams copyWith({
    String? query,
    String? exam,
    String? subject,
    double? minRating,
    int? minExperience,
    bool? onlyAvailable,
    int? limit,
    int? offset,
    String? sort,
  }) {
    return MentorSearchParams(
      query: query ?? this.query,
      exam: exam ?? this.exam,
      subject: subject ?? this.subject,
      minRating: minRating ?? this.minRating,
      minExperience: minExperience ?? this.minExperience,
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      sort: sort ?? this.sort,
    );
  }
}

class MentorRepository {
  final SupabaseService _supabase;
  MentorRepository(this._supabase);

  Future<List<Mentor>> searchMentors(MentorSearchParams p) async {
    try {
      // Prefer RPC if available
      final res = await _supabase.client.rpc('search_mentors', params: {
        'p_query': p.query,
        'p_exam': p.exam,
        'p_subject': p.subject,
        'p_min_rating': p.minRating,
        'p_min_experience': p.minExperience,
        'p_available': p.onlyAvailable,
        'p_limit': p.limit,
        'p_offset': p.offset,
        'p_sort': p.sort,
      }).select();

      return _mapRows(res);
    } catch (e) {
      // Fallback to direct table query if RPC missing
      debugPrint('search_mentors RPC failed, falling back to table query: $e');
      dynamic query = _supabase.client.from('mentor_profiles').select();

      if (p.query != null && p.query!.isNotEmpty) {
        final q = p.query!;
        query = query.or(
          'name.ilike.%$q%,bio.ilike.%$q%,exams.cs.{$q},subjects.cs.{$q},specializations.cs.{$q}',
        );
      }
      if (p.exam != null && p.exam!.isNotEmpty) {
        query = query.contains('exams', [p.exam]);
      }
      if (p.subject != null && p.subject!.isNotEmpty) {
        query = query.contains('subjects', [p.subject]);
      }
      if (p.minRating != null) {
        query = query.gte('rating', p.minRating!);
      }
      if (p.minExperience != null) {
        query = query.gte('years_of_experience', p.minExperience!);
      }
      if (p.onlyAvailable != null) {
        query = query.eq('is_available', p.onlyAvailable!);
      }

      switch (p.sort) {
        case 'experience_desc':
          query = query.order('years_of_experience', ascending: false);
          break;
        case 'price_asc':
          query = query.order('hourly_rate', ascending: true);
          break;
        default:
          query = query
              .order('rating', ascending: false)
              .order('rating_count', ascending: false);
      }

      query = query.range(p.offset, p.offset + p.limit - 1);
      final res = await query;
      return _mapRows(res);
    }
  }

  List<Mentor> _mapRows(dynamic rows) {
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.map((r) {
      return Mentor(
        id: (r['id'] ?? r['user_id']).toString(),
        name: r['name'] ?? 'Unknown',
        email: r['email'] ?? '',
        profileImage: r['profile_image'],
        createdAt: DateTime.parse(r['created_at']),
        specializations: List<String>.from(r['specializations'] ?? const []),
        qualifications: const <String>[],
        hourlyRate: (r['hourly_rate'] as num?)?.toDouble() ?? 0,
        rating: (r['rating'] as num?)?.toDouble() ?? 0,
        totalSessions: r['total_sessions'] ?? 0,
        isAvailable: r['is_available'] ?? true,
        totalEarnings: 0,
        bio: r['bio'] ?? '',
        yearsOfExperience: r['years_of_experience'] ?? 0,
      );
    }).toList();
  }
}

final mentorRepositoryProvider = Provider<MentorRepository>((ref) {
  return MentorRepository(SupabaseService.instance);
});

final mentorSearchParamsProvider = StateProvider<MentorSearchParams>((ref) {
  return const MentorSearchParams();
});

final mentorSearchResultsProvider =
    FutureProvider.autoDispose<List<Mentor>>((ref) async {
  final repo = ref.watch(mentorRepositoryProvider);
  final params = ref.watch(mentorSearchParamsProvider);
  return repo.searchMentors(params);
});
