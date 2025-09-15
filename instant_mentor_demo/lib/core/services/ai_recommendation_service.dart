import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'supabase_service.dart';

/// AI-powered mentor recommendation service
class AIRecommendationService {
  static AIRecommendationService? _instance;
  static AIRecommendationService get instance =>
      _instance ??= AIRecommendationService._();

  AIRecommendationService._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Get AI-powered mentor recommendations for a student
  Future<List<MentorRecommendation>> getRecommendationsForStudent({
    required String studentId,
    required String subject,
    List<String> learningStyle = const [],
    String difficultyLevel = 'intermediate',
    double? budgetMax,
    List<String> preferredLanguages = const [],
    bool requiresVerification = false,
    int limit = 10,
  }) async {
    try {
      // Get student profile and preferences
      final studentProfile = await _getStudentProfile(studentId);

      // Get all available mentors for the subject
      final mentors = await _getAvailableMentors(
        subject: subject,
        budgetMax: budgetMax,
        languages: preferredLanguages,
        requiresVerification: requiresVerification,
      );

      // Calculate AI scores for each mentor
      final recommendations = <MentorRecommendation>[];

      for (final mentor in mentors) {
        final score = await _calculateCompatibilityScore(
          studentProfile: studentProfile,
          mentor: mentor,
          subject: subject,
          learningStyle: learningStyle,
          difficultyLevel: difficultyLevel,
        );

        recommendations.add(MentorRecommendation(
          mentor: mentor,
          compatibilityScore: score.overallScore,
          reasoningFactors: score.factors,
          matchPercentage: (score.overallScore * 100).round(),
          estimatedSuccessRate: score.successProbability,
          recommendations: score.recommendations,
        ));
      }

      // Sort by compatibility score and return top recommendations
      recommendations
          .sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));

      // Store recommendation analytics
      await _storeRecommendationAnalytics(
          studentId, subject, recommendations.take(limit).toList());

      return recommendations.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting mentor recommendations: $e');
      return [];
    }
  }

  /// Calculate compatibility score between student and mentor
  Future<CompatibilityScore> _calculateCompatibilityScore({
    required Map<String, dynamic> studentProfile,
    required Map<String, dynamic> mentor,
    required String subject,
    required List<String> learningStyle,
    required String difficultyLevel,
  }) async {
    final factors = <String, double>{};
    final recommendations = <String>[];

    // 1. Subject expertise match (25% weight)
    final subjectScore = _calculateSubjectExpertiseScore(mentor, subject);
    factors['Subject Expertise'] = subjectScore;

    // 2. Teaching style compatibility (20% weight)
    final teachingStyleScore =
        _calculateTeachingStyleScore(mentor, learningStyle);
    factors['Teaching Style Match'] = teachingStyleScore;

    // 3. Experience level appropriateness (15% weight)
    final experienceScore = _calculateExperienceScore(mentor, difficultyLevel);
    factors['Experience Level'] = experienceScore;

    // 4. Rating and reviews (15% weight)
    final ratingScore = _calculateRatingScore(mentor);
    factors['Rating & Reviews'] = ratingScore;

    // 5. Availability match (10% weight)
    final availabilityScore =
        await _calculateAvailabilityScore(mentor, studentProfile);
    factors['Availability'] = availabilityScore;

    // 6. Price compatibility (10% weight)
    final priceScore = _calculatePriceScore(mentor, studentProfile);
    factors['Price Match'] = priceScore;

    // 7. Success rate with similar students (5% weight)
    final successScore =
        await _calculateHistoricalSuccessScore(mentor, studentProfile);
    factors['Success History'] = successScore;

    // Calculate weighted overall score
    final overallScore = (subjectScore * 0.25 +
        teachingStyleScore * 0.20 +
        experienceScore * 0.15 +
        ratingScore * 0.15 +
        availabilityScore * 0.10 +
        priceScore * 0.10 +
        successScore * 0.05);

    // Generate success probability
    final successProbability =
        _calculateSuccessProbability(overallScore, factors);

    // Generate recommendations
    recommendations.addAll(_generateRecommendations(factors, mentor));

    return CompatibilityScore(
      overallScore: overallScore,
      factors: factors,
      successProbability: successProbability,
      recommendations: recommendations,
    );
  }

  /// Calculate subject expertise score
  double _calculateSubjectExpertiseScore(
      Map<String, dynamic> mentor, String subject) {
    final subjects = List<String>.from(mentor['subjects'] ?? []);
    final specializations = List<String>.from(mentor['specializations'] ?? []);
    final yearsExperience = mentor['years_experience'] ?? 0;

    if (subjects.contains(subject)) {
      double score = 0.8; // Base score for having the subject

      // Bonus for specialization
      if (specializations
          .any((spec) => spec.toLowerCase().contains(subject.toLowerCase()))) {
        score += 0.1;
      }

      // Experience bonus
      if (yearsExperience >= 5) score += 0.1;
      if (yearsExperience >= 10) score += 0.05;

      return math.min(score, 1.0);
    }

    // Partial match for related subjects
    final relatedScore = _calculateRelatedSubjectScore(subjects, subject);
    return relatedScore * 0.6; // Max 60% for related subjects
  }

  /// Calculate teaching style compatibility
  double _calculateTeachingStyleScore(
      Map<String, dynamic> mentor, List<String> preferredStyles) {
    if (preferredStyles.isEmpty) return 0.7; // Neutral score

    final mentorStyle =
        mentor['teaching_style']?.toString().toLowerCase() ?? '';
    if (mentorStyle.isEmpty) return 0.6;

    double maxMatch = 0.0;
    for (final style in preferredStyles) {
      if (mentorStyle.contains(style.toLowerCase())) {
        maxMatch = math.max(maxMatch, 0.9);
      } else if (_isCompatibleTeachingStyle(mentorStyle, style)) {
        maxMatch = math.max(maxMatch, 0.7);
      }
    }

    return maxMatch > 0 ? maxMatch : 0.5;
  }

  /// Calculate experience appropriateness score
  double _calculateExperienceScore(
      Map<String, dynamic> mentor, String difficultyLevel) {
    final yearsExperience = mentor['years_experience'] ?? 0;
    final totalSessions = mentor['total_sessions'] ?? 0;

    double score = 0.5; // Base score

    switch (difficultyLevel.toLowerCase()) {
      case 'beginner':
        if (yearsExperience >= 1) score = 0.9;
        if (totalSessions >= 10) score += 0.1;
        break;
      case 'intermediate':
        if (yearsExperience >= 3) score = 0.9;
        if (totalSessions >= 50) score += 0.1;
        break;
      case 'advanced':
        if (yearsExperience >= 5) score = 0.9;
        if (totalSessions >= 100) score += 0.1;
        break;
    }

    return math.min(score, 1.0);
  }

  /// Calculate rating-based score
  double _calculateRatingScore(Map<String, dynamic> mentor) {
    final rating = mentor['average_rating']?.toDouble() ?? 0.0;
    final totalSessions = (mentor['total_sessions'] ?? 0).toDouble();

    if (rating == 0 || totalSessions < 5) return 0.5; // New mentor

    // Rating score (4.5+ = excellent, 4.0+ = good, 3.5+ = average)
    double score = 0.0;
    if (rating >= 4.5) {
      score = 1.0;
    } else if (rating >= 4.0)
      score = 0.8;
    else if (rating >= 3.5)
      score = 0.6;
    else if (rating >= 3.0)
      score = 0.4;
    else
      score = 0.2;

    // Confidence boost based on number of reviews
    final confidenceMultiplier = math.min<double>(1.0, totalSessions / 20.0);
    return score * confidenceMultiplier + (1 - confidenceMultiplier) * 0.5;
  }

  /// Calculate availability compatibility
  Future<double> _calculateAvailabilityScore(
      Map<String, dynamic> mentor, Map<String, dynamic> studentProfile) async {
    try {
      // Get mentor availability
      final mentorId = mentor['id'];
      final availability = await _supabase.fetchData(
        table: 'mentor_availability',
        filters: {'mentor_id': mentorId, 'is_active': true},
      );

      if (availability.isEmpty) return 0.3; // Limited availability

      final studentTimezone = studentProfile['timezone'] ?? 'UTC';
      final availableSlots = availability.length;

      // More availability = better score
      double score =
          math.min<double>(1.0, availableSlots / 7.0); // 7 days optimal

      // Timezone compatibility bonus
      final mentorTimezone = availability.first['timezone'] ?? 'UTC';
      if (_isCompatibleTimezone(studentTimezone, mentorTimezone)) {
        score += 0.1;
      }

      return math.min<double>(score, 1.0);
    } catch (e) {
      return 0.5; // Neutral score on error
    }
  }

  /// Calculate price compatibility score
  double _calculatePriceScore(
      Map<String, dynamic> mentor, Map<String, dynamic> studentProfile) {
    final mentorRate = mentor['hourly_rate']?.toDouble() ?? 0.0;
    final studentBudget = studentProfile['budget_max']?.toDouble();

    if (studentBudget == null || studentBudget == 0) return 0.7; // Neutral

    if (mentorRate <= studentBudget) {
      // Calculate affordability score
      final ratio = mentorRate / studentBudget;
      if (ratio <= 0.5) return 1.0; // Very affordable
      if (ratio <= 0.7) return 0.9; // Affordable
      if (ratio <= 0.9) return 0.8; // Reasonable
      return 0.7; // At budget limit
    }

    // Over budget - decreasing score
    final overageRatio = mentorRate / studentBudget;
    if (overageRatio <= 1.2) return 0.5; // 20% over
    if (overageRatio <= 1.5) return 0.3; // 50% over
    return 0.1; // Significantly over budget
  }

  /// Calculate historical success score
  Future<double> _calculateHistoricalSuccessScore(
    Map<String, dynamic> mentor,
    Map<String, dynamic> studentProfile,
  ) async {
    try {
      final mentorId = mentor['id'];
      final studentEducationLevel = studentProfile['education_level'] ?? '';

      // Get successful sessions for similar students
      final similarStudentSessions = await _supabase.client
          .from('mentoring_sessions')
          .select('*, student_profiles!inner(*)')
          .eq('mentor_id', mentorId)
          .eq('status', 'completed')
          .gte('rating', 4)
          .limit(50);

      if (similarStudentSessions.isEmpty) return 0.5; // No data

      // Calculate success rate with similar students
      final similarSessions = similarStudentSessions.where((session) {
        final sessionStudentLevel =
            session['student_profiles']['education_level'] ?? '';
        return sessionStudentLevel == studentEducationLevel;
      }).toList();

      if (similarSessions.isEmpty) return 0.6; // No exact matches

      final successRate =
          similarSessions.length / similarStudentSessions.length;
      return math.min<double>(1.0, successRate + 0.2); // Boost for having data
    } catch (e) {
      return 0.5; // Neutral score on error
    }
  }

  /// Generate success probability
  double _calculateSuccessProbability(
      double overallScore, Map<String, double> factors) {
    double probability = overallScore;

    // Boost probability for high expertise
    if (factors['Subject Expertise']! > 0.8) probability += 0.05;

    // Boost for high ratings
    if (factors['Rating & Reviews']! > 0.8) probability += 0.05;

    // Reduce for poor availability
    if (factors['Availability']! < 0.3) probability -= 0.1;

    return math.min<double>(1.0, math.max<double>(0.1, probability));
  }

  /// Generate personalized recommendations
  List<String> _generateRecommendations(
      Map<String, double> factors, Map<String, dynamic> mentor) {
    final recommendations = <String>[];

    if (factors['Subject Expertise']! > 0.8) {
      recommendations.add('Excellent expertise in your subject area');
    }

    if (factors['Teaching Style Match']! > 0.8) {
      recommendations.add('Teaching style matches your learning preferences');
    }

    if (factors['Rating & Reviews']! > 0.8) {
      recommendations.add('Highly rated by other students');
    }

    if (factors['Price Match']! > 0.8) {
      recommendations.add('Fits well within your budget');
    }

    final yearsExp = mentor['years_experience'] ?? 0;
    if (yearsExp >= 10) {
      recommendations.add('Extensive teaching experience ($yearsExp years)');
    }

    if (mentor['is_verified'] == true) {
      recommendations.add('Verified mentor with proven credentials');
    }

    return recommendations;
  }

  /// Helper methods
  double _calculateRelatedSubjectScore(
      List<String> mentorSubjects, String targetSubject) {
    // Define subject relationships
    final subjectRelations = {
      'Mathematics': [
        'Physics',
        'Engineering',
        'Statistics',
        'Computer Science'
      ],
      'Physics': ['Mathematics', 'Chemistry', 'Engineering'],
      'Chemistry': ['Biology', 'Physics', 'Medicine'],
      'Biology': ['Chemistry', 'Medicine', 'Psychology'],
      'Computer Science': ['Mathematics', 'Engineering', 'Data Science'],
      'English': ['Literature', 'Writing', 'Communication'],
      'History': ['Social Studies', 'Political Science', 'Geography'],
    };

    final related = subjectRelations[targetSubject] ?? [];
    final hasRelated =
        mentorSubjects.any((subject) => related.contains(subject));

    return hasRelated ? 0.3 : 0.0;
  }

  bool _isCompatibleTeachingStyle(String mentorStyle, String preferredStyle) {
    final compatibilityMap = {
      'visual': ['interactive', 'hands-on', 'demonstration'],
      'auditory': ['discussion', 'lecture', 'verbal'],
      'kinesthetic': ['hands-on', 'interactive', 'practical'],
      'interactive': ['visual', 'kinesthetic', 'collaborative'],
    };

    final compatibleStyles =
        compatibilityMap[preferredStyle.toLowerCase()] ?? [];
    return compatibleStyles.any((style) => mentorStyle.contains(style));
  }

  bool _isCompatibleTimezone(String studentTz, String mentorTz) {
    // Simplified timezone compatibility check
    final sameRegion = studentTz.split('/').first == mentorTz.split('/').first;
    return sameRegion;
  }

  /// Get student profile with preferences
  Future<Map<String, dynamic>> _getStudentProfile(String studentId) async {
    try {
      final profile = await _supabase.fetchData(
        table: 'student_profiles',
        filters: {'user_id': studentId},
      );

      if (profile.isNotEmpty) {
        return profile.first;
      }

      // Fallback to user profile
      final userProfile = await _supabase.fetchData(
        table: 'user_profiles',
        filters: {'id': studentId},
      );

      return userProfile.isNotEmpty ? userProfile.first : {};
    } catch (e) {
      debugPrint('Error getting student profile: $e');
      return {};
    }
  }

  /// Get available mentors for subject
  Future<List<Map<String, dynamic>>> _getAvailableMentors({
    required String subject,
    double? budgetMax,
    List<String> languages = const [],
    bool requiresVerification = false,
  }) async {
    try {
      var query = _supabase.client
          .from('mentor_profiles')
          .select('*, user_profiles!inner(*)')
          .eq('is_available', true)
          .contains('subjects', [subject]);

      if (budgetMax != null) {
        query = query.lte('hourly_rate', budgetMax);
      }

      if (requiresVerification) {
        query = query.eq('is_verified', true);
      }

      final mentors = await query;
      return List<Map<String, dynamic>>.from(mentors);
    } catch (e) {
      debugPrint('Error getting available mentors: $e');
      return [];
    }
  }

  /// Store recommendation analytics
  Future<void> _storeRecommendationAnalytics(
    String studentId,
    String subject,
    List<MentorRecommendation> recommendations,
  ) async {
    try {
      await _supabase.insertData(
        table: 'recommendation_analytics',
        data: {
          'student_id': studentId,
          'subject': subject,
          'recommendations_count': recommendations.length,
          'top_score': recommendations.isNotEmpty
              ? recommendations.first.compatibilityScore
              : 0,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error storing recommendation analytics: $e');
    }
  }
}

/// Mentor recommendation with AI score
class MentorRecommendation {
  final Map<String, dynamic> mentor;
  final double compatibilityScore;
  final Map<String, double> reasoningFactors;
  final int matchPercentage;
  final double estimatedSuccessRate;
  final List<String> recommendations;

  MentorRecommendation({
    required this.mentor,
    required this.compatibilityScore,
    required this.reasoningFactors,
    required this.matchPercentage,
    required this.estimatedSuccessRate,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
        'mentor': mentor,
        'compatibility_score': compatibilityScore,
        'reasoning_factors': reasoningFactors,
        'match_percentage': matchPercentage,
        'estimated_success_rate': estimatedSuccessRate,
        'recommendations': recommendations,
      };
}

/// Compatibility scoring result
class CompatibilityScore {
  final double overallScore;
  final Map<String, double> factors;
  final double successProbability;
  final List<String> recommendations;

  CompatibilityScore({
    required this.overallScore,
    required this.factors,
    required this.successProbability,
    required this.recommendations,
  });
}
