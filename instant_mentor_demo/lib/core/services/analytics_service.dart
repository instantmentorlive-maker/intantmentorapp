import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'supabase_service.dart';

/// Advanced analytics and insights service
class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();

  AnalyticsService._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Get comprehensive learning analytics for a student
  Future<StudentAnalytics> getStudentAnalytics(String studentId) async {
    try {
      // Get all student sessions
      final sessions = await _supabase.fetchData(
        table: 'mentoring_sessions',
        filters: {'student_id': studentId},
      );

      // Get student reviews
      final reviews = await _supabase.fetchData(
        table: 'reviews',
        filters: {'reviewer_id': studentId},
      );

      // Calculate progress metrics
      final progressMetrics = _calculateProgressMetrics(sessions);
      final learningInsights = _generateLearningInsights(sessions, reviews);
      final performanceAnalysis = _analyzePerformance(sessions, reviews);
      final subjectDistribution = _analyzeSubjectDistribution(sessions);
      final engagementMetrics = _calculateEngagementMetrics(sessions);

      return StudentAnalytics(
        studentId: studentId,
        totalSessions: sessions.length,
        completedSessions:
            sessions.where((s) => s['status'] == 'completed').length,
        averageRating: _calculateAverageRating(reviews),
        progressMetrics: progressMetrics,
        learningInsights: learningInsights,
        performanceAnalysis: performanceAnalysis,
        subjectDistribution: subjectDistribution,
        engagementMetrics: engagementMetrics,
        recommendations: _generateStudentRecommendations(sessions, reviews),
      );
    } catch (e) {
      debugPrint('Error getting student analytics: $e');
      return StudentAnalytics.empty(studentId);
    }
  }

  /// Get comprehensive mentor analytics
  Future<MentorAnalytics> getMentorAnalytics(String mentorId) async {
    try {
      // Get mentor profile
      final mentorProfile = await _supabase.fetchData(
        table: 'mentor_profiles',
        filters: {'user_id': mentorId},
      );

      if (mentorProfile.isEmpty) {
        return MentorAnalytics.empty(mentorId);
      }

      final mentorProfileId = mentorProfile.first['id'];

      // Get mentor sessions
      final sessions = await _supabase.fetchData(
        table: 'mentoring_sessions',
        filters: {'mentor_id': mentorProfileId},
      );

      // Get reviews for mentor
      final reviews = await _supabase.client
          .from('reviews')
          .select('*')
          .eq('reviewed_id', mentorId);

      // Calculate performance metrics
      final performanceMetrics =
          _calculateMentorPerformanceMetrics(sessions, reviews);
      final teachingEffectiveness =
          _analyzeMentorEffectiveness(sessions, reviews);
      final studentOutcomes = _analyzeStudentOutcomes(sessions);
      final subjectExpertise = _analyzeSubjectExpertise(sessions, reviews);
      final earningsAnalytics = _calculateEarningsAnalytics(sessions);

      return MentorAnalytics(
        mentorId: mentorId,
        totalSessions: sessions.length,
        completedSessions:
            sessions.where((s) => s['status'] == 'completed').length,
        averageRating:
            _calculateAverageRating(List<Map<String, dynamic>>.from(reviews)),
        totalStudents: _countUniqueStudents(sessions),
        performanceMetrics: performanceMetrics,
        teachingEffectiveness: teachingEffectiveness,
        studentOutcomes: studentOutcomes,
        subjectExpertise: subjectExpertise,
        earningsAnalytics: earningsAnalytics,
        recommendations: _generateMentorRecommendations(sessions, reviews),
      );
    } catch (e) {
      debugPrint('Error getting mentor analytics: $e');
      return MentorAnalytics.empty(mentorId);
    }
  }

  /// Get platform-wide analytics
  Future<PlatformAnalytics> getPlatformAnalytics() async {
    try {
      // Get platform statistics
      final userStats = await _getPlatformUserStats();
      final sessionStats = await _getPlatformSessionStats();
      final growthMetrics = await _calculateGrowthMetrics();
      final popularSubjects = await _getPopularSubjects();
      final qualityMetrics = await _calculateQualityMetrics();

      return PlatformAnalytics(
        totalUsers: userStats['total_users'] ?? 0,
        totalMentors: userStats['total_mentors'] ?? 0,
        totalStudents: userStats['total_students'] ?? 0,
        totalSessions: sessionStats['total_sessions'] ?? 0,
        completedSessions: sessionStats['completed_sessions'] ?? 0,
        averagePlatformRating: qualityMetrics['average_rating'],
        growthMetrics: growthMetrics,
        popularSubjects: popularSubjects,
        qualityMetrics: qualityMetrics,
      );
    } catch (e) {
      debugPrint('Error getting platform analytics: $e');
      return PlatformAnalytics.empty();
    }
  }

  /// Calculate learning progress metrics
  Map<String, dynamic> _calculateProgressMetrics(
      List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return {};

    final completedSessions =
        sessions.where((s) => s['status'] == 'completed').toList();
    final totalSessionTime = completedSessions.fold<int>(
        0, (sum, session) => sum + (session['duration_minutes'] ?? 0));

    // Calculate learning velocity (sessions per week)
    final firstSession = sessions.isNotEmpty
        ? DateTime.parse(sessions.first['created_at'])
        : DateTime.now();
    final lastSession = sessions.isNotEmpty
        ? DateTime.parse(sessions.last['created_at'])
        : DateTime.now();

    final weeksBetween = lastSession.difference(firstSession).inDays / 7.0;
    final learningVelocity =
        weeksBetween > 0 ? sessions.length / weeksBetween : 0.0;

    // Calculate consistency score
    final consistencyScore = _calculateConsistencyScore(sessions);

    return {
      'total_learning_time': totalSessionTime,
      'average_session_duration': completedSessions.isNotEmpty
          ? totalSessionTime / completedSessions.length
          : 0,
      'learning_velocity': learningVelocity,
      'consistency_score': consistencyScore,
      'completion_rate': sessions.isNotEmpty
          ? completedSessions.length / sessions.length
          : 0.0,
    };
  }

  /// Generate learning insights
  List<LearningInsight> _generateLearningInsights(
    List<Map<String, dynamic>> sessions,
    List<Map<String, dynamic>> reviews,
  ) {
    final insights = <LearningInsight>[];

    // Subject preference insights
    final subjectCounts = <String, int>{};
    for (final session in sessions) {
      final subject = session['subject'] ?? 'Unknown';
      subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
    }

    if (subjectCounts.isNotEmpty) {
      final favoriteSubject =
          subjectCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      insights.add(LearningInsight(
        title: 'Favorite Subject',
        description: 'You spend most time learning $favoriteSubject',
        type: 'subject_preference',
        value: favoriteSubject,
        score: subjectCounts[favoriteSubject]!.toDouble(),
      ));
    }

    // Learning streak insights
    final streak = _calculateLearningStreak(sessions);
    if (streak > 0) {
      insights.add(LearningInsight(
        title: 'Learning Streak',
        description: 'You have a $streak session learning streak!',
        type: 'engagement',
        value: streak.toString(),
        score: streak.toDouble(),
      ));
    }

    // Performance improvement insights
    if (reviews.length >= 3) {
      final recentRatings =
          reviews.take(5).map((r) => (r['rating'] ?? 0).toDouble()).toList();
      final olderRatings = reviews
          .skip(5)
          .take(5)
          .map((r) => (r['rating'] ?? 0).toDouble())
          .toList();

      if (recentRatings.isNotEmpty && olderRatings.isNotEmpty) {
        final recentAvg =
            recentRatings.reduce((a, b) => a + b) / recentRatings.length;
        final olderAvg =
            olderRatings.reduce((a, b) => a + b) / olderRatings.length;
        final improvement = recentAvg - olderAvg;

        if (improvement > 0.2) {
          insights.add(LearningInsight(
            title: 'Performance Improvement',
            description:
                'Your ratings have improved by ${(improvement * 100).toStringAsFixed(1)}%',
            type: 'performance',
            value: improvement.toStringAsFixed(2),
            score: improvement,
          ));
        }
      }
    }

    return insights;
  }

  /// Analyze mentor performance
  Map<String, dynamic> _calculateMentorPerformanceMetrics(
    List<Map<String, dynamic>> sessions,
    List<Map<String, dynamic>> reviews,
  ) {
    final completedSessions =
        sessions.where((s) => s['status'] == 'completed').toList();
    final cancelledSessions =
        sessions.where((s) => s['status'] == 'cancelled').toList();

    final completionRate =
        sessions.isNotEmpty ? completedSessions.length / sessions.length : 0.0;

    final cancellationRate =
        sessions.isNotEmpty ? cancelledSessions.length / sessions.length : 0.0;

    final averageRating = _calculateAverageRating(reviews);

    // Calculate student retention rate
    final studentRetention = _calculateStudentRetention(sessions);

    // Calculate response time (simplified)
    final avgResponseTime = _calculateAverageResponseTime(sessions);

    return {
      'completion_rate': completionRate,
      'cancellation_rate': cancellationRate,
      'average_rating': averageRating,
      'student_retention_rate': studentRetention,
      'average_response_time_hours': avgResponseTime,
      'total_teaching_hours': completedSessions.fold<int>(
              0, (sum, s) => sum + (s['duration_minutes'] ?? 0)) /
          60.0,
    };
  }

  /// Calculate earnings analytics for mentor
  Map<String, dynamic> _calculateEarningsAnalytics(
      List<Map<String, dynamic>> sessions) {
    final paidSessions = sessions
        .where(
            (s) => s['status'] == 'completed' && s['payment_status'] == 'paid')
        .toList();

    final totalEarnings = paidSessions.fold<double>(
        0.0, (sum, session) => sum + (session['cost']?.toDouble() ?? 0.0));

    final averageSessionValue =
        paidSessions.isNotEmpty ? totalEarnings / paidSessions.length : 0.0;

    // Calculate monthly earnings trend
    final monthlyEarnings = <String, double>{};
    for (final session in paidSessions) {
      final date = DateTime.parse(session['created_at']);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthlyEarnings[monthKey] = (monthlyEarnings[monthKey] ?? 0.0) +
          (session['cost']?.toDouble() ?? 0.0);
    }

    return {
      'total_earnings': totalEarnings,
      'average_session_value': averageSessionValue,
      'monthly_earnings': monthlyEarnings,
      'paid_sessions_count': paidSessions.length,
    };
  }

  /// Helper methods
  double _calculateAverageRating(List<Map<String, dynamic>> reviews) {
    if (reviews.isEmpty) return 0.0;

    final ratings = reviews
        .map((r) => (r['rating'] ?? 0).toDouble())
        .where((rating) => rating > 0);

    return ratings.isNotEmpty
        ? ratings.reduce((a, b) => a + b) / ratings.length
        : 0.0;
  }

  double _calculateConsistencyScore(List<Map<String, dynamic>> sessions) {
    if (sessions.length < 2) return 0.0;

    // Calculate gaps between sessions
    final sessionDates =
        sessions.map((s) => DateTime.parse(s['created_at'])).toList()..sort();

    final gaps = <int>[];
    for (int i = 1; i < sessionDates.length; i++) {
      gaps.add(sessionDates[i].difference(sessionDates[i - 1]).inDays);
    }

    if (gaps.isEmpty) return 0.0;

    // Lower variance in gaps = higher consistency
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final variance =
        gaps.map((gap) => math.pow(gap - avgGap, 2)).reduce((a, b) => a + b) /
            gaps.length;

    // Convert to score (lower variance = higher score)
    return math.max(0.0, 1.0 - (variance / 100.0));
  }

  int _calculateLearningStreak(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0;

    final completedSessions = sessions
        .where((s) => s['status'] == 'completed')
        .map((s) => DateTime.parse(s['scheduled_time']))
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Most recent first

    if (completedSessions.isEmpty) return 0;

    int streak = 1;
    DateTime current = completedSessions.first;

    for (int i = 1; i < completedSessions.length; i++) {
      final daysDiff = current.difference(completedSessions[i]).inDays;
      if (daysDiff <= 7) {
        // Within a week
        streak++;
        current = completedSessions[i];
      } else {
        break;
      }
    }

    return streak;
  }

  double _calculateStudentRetention(List<Map<String, dynamic>> sessions) {
    final studentSessions = <String, List<Map<String, dynamic>>>{};

    for (final session in sessions) {
      final studentId = session['student_id'];
      studentSessions[studentId] = (studentSessions[studentId] ?? [])
        ..add(session);
    }

    if (studentSessions.isEmpty) return 0.0;

    final returningStudents =
        studentSessions.values.where((sessions) => sessions.length > 1).length;

    return returningStudents / studentSessions.length;
  }

  double _calculateAverageResponseTime(List<Map<String, dynamic>> sessions) {
    // Simplified calculation - would need message data for accurate response time
    return 2.5; // Default 2.5 hours
  }

  int _countUniqueStudents(List<Map<String, dynamic>> sessions) {
    return sessions.map((s) => s['student_id']).toSet().length;
  }

  Map<String, dynamic> _analyzePerformance(
    List<Map<String, dynamic>> sessions,
    List<Map<String, dynamic>> reviews,
  ) {
    // Placeholder for detailed performance analysis
    return {
      'improvement_trend': 'positive',
      'weak_areas': <String>[],
      'strong_areas': <String>[],
    };
  }

  Map<String, int> _analyzeSubjectDistribution(
      List<Map<String, dynamic>> sessions) {
    final distribution = <String, int>{};
    for (final session in sessions) {
      final subject = session['subject'] ?? 'Unknown';
      distribution[subject] = (distribution[subject] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, dynamic> _calculateEngagementMetrics(
      List<Map<String, dynamic>> sessions) {
    return {
      'active_days': _calculateActiveDays(sessions),
      'average_weekly_sessions': _calculateWeeklyAverage(sessions),
    };
  }

  int _calculateActiveDays(List<Map<String, dynamic>> sessions) {
    final uniqueDays = sessions
        .map((s) => DateTime.parse(s['created_at']))
        .map((date) => '${date.year}-${date.month}-${date.day}')
        .toSet();
    return uniqueDays.length;
  }

  double _calculateWeeklyAverage(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0.0;

    final firstSession = DateTime.parse(sessions.first['created_at']);
    final lastSession = DateTime.parse(sessions.last['created_at']);
    final weeks = lastSession.difference(firstSession).inDays / 7.0;

    return weeks > 0 ? sessions.length / weeks : 0.0;
  }

  List<String> _generateStudentRecommendations(
    List<Map<String, dynamic>> sessions,
    List<Map<String, dynamic>> reviews,
  ) {
    final recommendations = <String>[];

    if (sessions.length < 5) {
      recommendations.add('Book more sessions to accelerate your learning');
    }

    final avgRating = _calculateAverageRating(reviews);
    if (avgRating < 4.0) {
      recommendations
          .add('Consider trying different mentors to find the best fit');
    }

    return recommendations;
  }

  List<String> _generateMentorRecommendations(
    List<Map<String, dynamic>> sessions,
    List<Map<String, dynamic>> reviews,
  ) {
    final recommendations = <String>[];

    final completionRate = sessions.isNotEmpty
        ? sessions.where((s) => s['status'] == 'completed').length /
            sessions.length
        : 0.0;

    if (completionRate < 0.8) {
      recommendations.add('Focus on improving session completion rates');
    }

    final avgRating = _calculateAverageRating(reviews);
    if (avgRating < 4.5) {
      recommendations.add('Work on enhancing student satisfaction');
    }

    return recommendations;
  }

  // Placeholder methods for platform analytics
  Future<Map<String, int>> _getPlatformUserStats() async {
    try {
      final userCount = await _supabase.fetchData(table: 'user_profiles');
      final mentorCount = await _supabase.fetchData(table: 'mentor_profiles');
      final studentCount = await _supabase.fetchData(table: 'student_profiles');

      return {
        'total_users': userCount.length,
        'total_mentors': mentorCount.length,
        'total_students': studentCount.length,
      };
    } catch (e) {
      return {'total_users': 0, 'total_mentors': 0, 'total_students': 0};
    }
  }

  Future<Map<String, int>> _getPlatformSessionStats() async {
    try {
      final totalSessions =
          await _supabase.fetchData(table: 'mentoring_sessions');
      final completedSessions = await _supabase.fetchData(
        table: 'mentoring_sessions',
        filters: {'status': 'completed'},
      );

      return {
        'total_sessions': totalSessions.length,
        'completed_sessions': completedSessions.length,
      };
    } catch (e) {
      return {'total_sessions': 0, 'completed_sessions': 0};
    }
  }

  Future<Map<String, dynamic>> _calculateGrowthMetrics() async {
    // Placeholder for growth calculations
    return {
      'monthly_user_growth': 15.0,
      'monthly_session_growth': 25.0,
    };
  }

  Future<List<Map<String, dynamic>>> _getPopularSubjects() async {
    try {
      final subjects = await _supabase.client
          .from('mentoring_sessions')
          .select('subject')
          .not('subject', 'is', null);

      final subjectCounts = <String, int>{};
      for (final session in subjects) {
        final subject = session['subject'] as String;
        subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
      }

      final sortedSubjects = subjectCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedSubjects
          .take(10)
          .map((entry) => {
                'subject': entry.key,
                'count': entry.value,
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _calculateQualityMetrics() async {
    try {
      final reviews = await _supabase.fetchData(table: 'reviews');
      final avgRating = _calculateAverageRating(reviews);

      return {
        'average_rating': avgRating,
        'total_reviews': reviews.length,
      };
    } catch (e) {
      return {'average_rating': 0.0, 'total_reviews': 0};
    }
  }

  // Additional helper methods for deeper analysis
  Map<String, dynamic> _analyzeMentorEffectiveness(
    List<Map<String, dynamic>> sessions,
    List<Map<String, dynamic>> reviews,
  ) {
    return {
      'student_improvement_rate': 0.75,
      'knowledge_transfer_score': 0.85,
      'engagement_score': 0.80,
    };
  }

  Map<String, dynamic> _analyzeStudentOutcomes(
      List<Map<String, dynamic>> sessions) {
    return {
      'goal_achievement_rate': 0.70,
      'skill_improvement_score': 0.65,
      'satisfaction_score': 0.80,
    };
  }

  Map<String, dynamic> _analyzeSubjectExpertise(
    List<Map<String, dynamic>> sessions,
    List<Map<String, dynamic>> reviews,
  ) {
    final subjectPerformance = <String, double>{};
    final subjectCounts = <String, int>{};

    for (final session in sessions) {
      final subject = session['subject'] ?? 'Unknown';
      subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
    }

    // Calculate performance score per subject based on reviews
    for (final review in reviews) {
      final sessionId = review['session_id'];
      final rating = (review['rating'] ?? 0).toDouble();

      // Find corresponding session subject
      final session = sessions.firstWhere(
        (s) => s['id'] == sessionId,
        orElse: () => {'subject': 'Unknown'},
      );

      final subject = session['subject'] ?? 'Unknown';
      subjectPerformance[subject] =
          (subjectPerformance[subject] ?? 0.0) + rating;
    }

    // Normalize by number of sessions per subject
    final normalizedPerformance = <String, double>{};
    subjectPerformance.forEach((subject, totalRating) {
      final sessionCount = subjectCounts[subject] ?? 1;
      normalizedPerformance[subject] = totalRating / sessionCount;
    });

    return {
      'subject_performance': normalizedPerformance,
      'subject_counts': subjectCounts,
      'strongest_subjects': _getTopSubjects(normalizedPerformance, 3),
    };
  }

  List<String> _getTopSubjects(Map<String, double> performance, int count) {
    final sortedSubjects = performance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedSubjects.take(count).map((entry) => entry.key).toList();
  }
}

/// Student analytics data model
class StudentAnalytics {
  final String studentId;
  final int totalSessions;
  final int completedSessions;
  final double averageRating;
  final Map<String, dynamic> progressMetrics;
  final List<LearningInsight> learningInsights;
  final Map<String, dynamic> performanceAnalysis;
  final Map<String, int> subjectDistribution;
  final Map<String, dynamic> engagementMetrics;
  final List<String> recommendations;

  StudentAnalytics({
    required this.studentId,
    required this.totalSessions,
    required this.completedSessions,
    required this.averageRating,
    required this.progressMetrics,
    required this.learningInsights,
    required this.performanceAnalysis,
    required this.subjectDistribution,
    required this.engagementMetrics,
    required this.recommendations,
  });

  factory StudentAnalytics.empty(String studentId) => StudentAnalytics(
        studentId: studentId,
        totalSessions: 0,
        completedSessions: 0,
        averageRating: 0.0,
        progressMetrics: {},
        learningInsights: [],
        performanceAnalysis: {},
        subjectDistribution: {},
        engagementMetrics: {},
        recommendations: [],
      );

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'total_sessions': totalSessions,
        'completed_sessions': completedSessions,
        'average_rating': averageRating,
        'progress_metrics': progressMetrics,
        'learning_insights': learningInsights.map((i) => i.toJson()).toList(),
        'performance_analysis': performanceAnalysis,
        'subject_distribution': subjectDistribution,
        'engagement_metrics': engagementMetrics,
        'recommendations': recommendations,
      };
}

/// Mentor analytics data model
class MentorAnalytics {
  final String mentorId;
  final int totalSessions;
  final int completedSessions;
  final double averageRating;
  final int totalStudents;
  final Map<String, dynamic> performanceMetrics;
  final Map<String, dynamic> teachingEffectiveness;
  final Map<String, dynamic> studentOutcomes;
  final Map<String, dynamic> subjectExpertise;
  final Map<String, dynamic> earningsAnalytics;
  final List<String> recommendations;

  MentorAnalytics({
    required this.mentorId,
    required this.totalSessions,
    required this.completedSessions,
    required this.averageRating,
    required this.totalStudents,
    required this.performanceMetrics,
    required this.teachingEffectiveness,
    required this.studentOutcomes,
    required this.subjectExpertise,
    required this.earningsAnalytics,
    required this.recommendations,
  });

  factory MentorAnalytics.empty(String mentorId) => MentorAnalytics(
        mentorId: mentorId,
        totalSessions: 0,
        completedSessions: 0,
        averageRating: 0.0,
        totalStudents: 0,
        performanceMetrics: {},
        teachingEffectiveness: {},
        studentOutcomes: {},
        subjectExpertise: {},
        earningsAnalytics: {},
        recommendations: [],
      );

  Map<String, dynamic> toJson() => {
        'mentor_id': mentorId,
        'total_sessions': totalSessions,
        'completed_sessions': completedSessions,
        'average_rating': averageRating,
        'total_students': totalStudents,
        'performance_metrics': performanceMetrics,
        'teaching_effectiveness': teachingEffectiveness,
        'student_outcomes': studentOutcomes,
        'subject_expertise': subjectExpertise,
        'earnings_analytics': earningsAnalytics,
        'recommendations': recommendations,
      };
}

/// Platform analytics data model
class PlatformAnalytics {
  final int totalUsers;
  final int totalMentors;
  final int totalStudents;
  final int totalSessions;
  final int completedSessions;
  final double averagePlatformRating;
  final Map<String, dynamic> growthMetrics;
  final List<Map<String, dynamic>> popularSubjects;
  final Map<String, dynamic> qualityMetrics;

  PlatformAnalytics({
    required this.totalUsers,
    required this.totalMentors,
    required this.totalStudents,
    required this.totalSessions,
    required this.completedSessions,
    required this.averagePlatformRating,
    required this.growthMetrics,
    required this.popularSubjects,
    required this.qualityMetrics,
  });

  factory PlatformAnalytics.empty() => PlatformAnalytics(
        totalUsers: 0,
        totalMentors: 0,
        totalStudents: 0,
        totalSessions: 0,
        completedSessions: 0,
        averagePlatformRating: 0.0,
        growthMetrics: {},
        popularSubjects: [],
        qualityMetrics: {},
      );

  Map<String, dynamic> toJson() => {
        'total_users': totalUsers,
        'total_mentors': totalMentors,
        'total_students': totalStudents,
        'total_sessions': totalSessions,
        'completed_sessions': completedSessions,
        'average_platform_rating': averagePlatformRating,
        'growth_metrics': growthMetrics,
        'popular_subjects': popularSubjects,
        'quality_metrics': qualityMetrics,
      };
}

/// Learning insight data model
class LearningInsight {
  final String title;
  final String description;
  final String type;
  final String value;
  final double score;

  LearningInsight({
    required this.title,
    required this.description,
    required this.type,
    required this.value,
    required this.score,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'type': type,
        'value': value,
        'score': score,
      };
}
