import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'supabase_service.dart';

/// Gamification and rewards service for engagement
class GamificationService {
  static GamificationService? _instance;
  static GamificationService get instance =>
      _instance ??= GamificationService._();

  GamificationService._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Award points to a user
  Future<bool> awardPoints({
    required String userId,
    required int points,
    required String reason,
    required PointsCategory category,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      // Record the points transaction
      await _supabase.insertData(
        table: 'points_transactions',
        data: {
          'user_id': userId,
          'points': points,
          'reason': reason,
          'category': category.toString().split('.').last,
          'metadata': metadata,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      // Update user's total points
      await _updateUserPoints(userId, points);

      // Check for new achievements
      await _checkAchievements(userId);

      // Check for level up
      await _checkLevelUp(userId);

      return true;
    } catch (e) {
      debugPrint('Error awarding points: $e');
      return false;
    }
  }

  /// Unlock an achievement for a user
  Future<bool> unlockAchievement({
    required String userId,
    required String achievementId,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      // Check if already unlocked
      final existing = await _supabase.fetchData(
        table: 'user_achievements',
        filters: {
          'user_id': userId,
          'achievement_id': achievementId,
        },
      );

      if (existing.isNotEmpty) {
        debugPrint('Achievement already unlocked');
        return false;
      }

      // Get achievement details
      final achievements = await _supabase.fetchData(
        table: 'achievements',
        filters: {'id': achievementId},
      );

      if (achievements.isEmpty) {
        debugPrint('Achievement not found');
        return false;
      }

      final achievement = achievements.first;

      // Unlock the achievement
      await _supabase.insertData(
        table: 'user_achievements',
        data: {
          'user_id': userId,
          'achievement_id': achievementId,
          'unlocked_at': DateTime.now().toIso8601String(),
          'metadata': metadata,
        },
      );

      // Award points for achievement
      final points = achievement['points'] ?? 0;
      if (points > 0) {
        await awardPoints(
          userId: userId,
          points: points,
          reason: 'Achievement unlocked: ${achievement['name']}',
          category: PointsCategory.achievement,
          metadata: {'achievement_id': achievementId},
        );
      }

      // Send notification
      await _sendAchievementNotification(userId, achievement);

      return true;
    } catch (e) {
      debugPrint('Error unlocking achievement: $e');
      return false;
    }
  }

  /// Create a new challenge
  Future<String?> createChallenge({
    required String title,
    required String description,
    required String creatorId,
    required ChallengeType type,
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> requirements,
    required List<ChallengeReward> rewards,
    int maxParticipants = 0, // 0 = unlimited
    List<String> tags = const [],
  }) async {
    try {
      final challengeData = {
        'title': title,
        'description': description,
        'creator_id': creatorId,
        'challenge_type': type.toString().split('.').last,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'requirements': requirements,
        'rewards': rewards.map((r) => r.toJson()).toList(),
        'max_participants': maxParticipants,
        'current_participants': 0,
        'tags': tags,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'challenges',
        data: challengeData,
      );

      return result.first['id'].toString();
    } catch (e) {
      debugPrint('Error creating challenge: $e');
      return null;
    }
  }

  /// Join a challenge
  Future<bool> joinChallenge({
    required String challengeId,
    required String userId,
  }) async {
    try {
      // Check if challenge exists and is active
      final challenges = await _supabase.fetchData(
        table: 'challenges',
        filters: {'id': challengeId},
      );

      if (challenges.isEmpty) {
        debugPrint('Challenge not found');
        return false;
      }

      final challenge = challenges.first;

      if (challenge['status'] != 'active') {
        debugPrint('Challenge is not active');
        return false;
      }

      // Check if user is already participating
      final existing = await _supabase.fetchData(
        table: 'challenge_participants',
        filters: {
          'challenge_id': challengeId,
          'user_id': userId,
        },
      );

      if (existing.isNotEmpty) {
        debugPrint('User is already participating');
        return false;
      }

      // Check participant limit
      final maxParticipants = challenge['max_participants'] ?? 0;
      final currentParticipants = challenge['current_participants'] ?? 0;

      if (maxParticipants > 0 && currentParticipants >= maxParticipants) {
        debugPrint('Challenge is full');
        return false;
      }

      // Add user as participant
      await _supabase.insertData(
        table: 'challenge_participants',
        data: {
          'challenge_id': challengeId,
          'user_id': userId,
          'joined_at': DateTime.now().toIso8601String(),
          'progress': 0.0,
          'status': 'active',
        },
      );

      // Update participant count
      await _supabase.updateData(
        table: 'challenges',
        data: {'current_participants': currentParticipants + 1},
        column: 'id',
        value: challengeId,
      );

      return true;
    } catch (e) {
      debugPrint('Error joining challenge: $e');
      return false;
    }
  }

  /// Update challenge progress
  Future<bool> updateChallengeProgress({
    required String challengeId,
    required String userId,
    required double progress,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      await _supabase.updateData(
        table: 'challenge_participants',
        data: {
          'progress': progress.clamp(0.0, 100.0),
          'last_updated': DateTime.now().toIso8601String(),
          'data': data,
          if (progress >= 100.0)
            'completed_at': DateTime.now().toIso8601String(),
          if (progress >= 100.0) 'status': 'completed',
        },
        column: 'challenge_id',
        value: challengeId,
      );

      // Award completion rewards if finished
      if (progress >= 100.0) {
        await _awardChallengeRewards(challengeId, userId);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating challenge progress: $e');
      return false;
    }
  }

  /// Create a learning streak
  Future<bool> recordLearningActivity({
    required String userId,
    required ActivityType activityType,
    required DateTime timestamp,
    int duration = 0, // minutes
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      // Record the activity
      await _supabase.insertData(
        table: 'learning_activities',
        data: {
          'user_id': userId,
          'activity_type': activityType.toString().split('.').last,
          'timestamp': timestamp.toIso8601String(),
          'duration': duration,
          'metadata': metadata,
        },
      );

      // Update streak
      await _updateLearningStreak(userId, timestamp);

      // Award points based on activity
      final points = _getActivityPoints(activityType, duration);
      if (points > 0) {
        await awardPoints(
          userId: userId,
          points: points,
          reason:
              'Learning activity: ${activityType.toString().split('.').last}',
          category: PointsCategory.activity,
          metadata: {
            'activity_type': activityType.toString().split('.').last,
            'duration': duration,
          },
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error recording learning activity: $e');
      return false;
    }
  }

  /// Get user's gamification profile
  Future<UserGamificationProfile?> getUserProfile(String userId) async {
    try {
      // Get user stats
      final userStats = await _supabase.fetchData(
        table: 'user_gamification_stats',
        filters: {'user_id': userId},
      );

      UserGamificationStats stats;
      if (userStats.isEmpty) {
        // Create initial stats
        stats = await _createInitialStats(userId);
      } else {
        stats = UserGamificationStats.fromJson(userStats.first);
      }

      // Get achievements
      final achievements = await _getUserAchievements(userId);

      // Get active challenges
      final challenges = await _getUserActiveChallenges(userId);

      // Get recent activities
      final activities = await _getRecentActivities(userId);

      return UserGamificationProfile(
        userId: userId,
        stats: stats,
        achievements: achievements,
        activeChallenges: challenges,
        recentActivities: activities,
      );
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Get leaderboard
  Future<List<LeaderboardEntry>> getLeaderboard({
    LeaderboardType type = LeaderboardType.totalPoints,
    LeaderboardTimeframe timeframe = LeaderboardTimeframe.allTime,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final leaderboardData = <LeaderboardEntry>[];

      switch (type) {
        case LeaderboardType.totalPoints:
          leaderboardData
              .addAll(await _getPointsLeaderboard(timeframe, limit, offset));
          break;
        case LeaderboardType.streaks:
          leaderboardData
              .addAll(await _getStreaksLeaderboard(timeframe, limit, offset));
          break;
        case LeaderboardType.achievements:
          leaderboardData.addAll(
              await _getAchievementsLeaderboard(timeframe, limit, offset));
          break;
        case LeaderboardType.challenges:
          leaderboardData.addAll(
              await _getChallengesLeaderboard(timeframe, limit, offset));
          break;
      }

      return leaderboardData;
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get available rewards for user
  Future<List<UserReward>> getAvailableRewards(String userId) async {
    try {
      final userStats = await _supabase.fetchData(
        table: 'user_gamification_stats',
        filters: {'user_id': userId},
      );

      if (userStats.isEmpty) return [];

      final stats = UserGamificationStats.fromJson(userStats.first);

      // Get all rewards
      final rewards = await _supabase.fetchData(
        table: 'rewards',
        filters: {'is_active': true},
      );

      final availableRewards = <UserReward>[];

      for (final reward in rewards) {
        final pointsCost = reward['points_cost'] ?? 0;
        final levelRequired = reward['level_required'] ?? 1;

        if (stats.totalPoints >= pointsCost && stats.level >= levelRequired) {
          availableRewards.add(UserReward.fromJson(reward));
        }
      }

      return availableRewards;
    } catch (e) {
      debugPrint('Error getting available rewards: $e');
      return [];
    }
  }

  /// Redeem a reward
  Future<bool> redeemReward({
    required String userId,
    required String rewardId,
  }) async {
    try {
      // Get reward details
      final rewards = await _supabase.fetchData(
        table: 'rewards',
        filters: {'id': rewardId},
      );

      if (rewards.isEmpty) {
        debugPrint('Reward not found');
        return false;
      }

      final reward = rewards.first;
      final pointsCost = reward['points_cost'] ?? 0;

      // Check if user has enough points
      final userStats = await _supabase.fetchData(
        table: 'user_gamification_stats',
        filters: {'user_id': userId},
      );

      if (userStats.isEmpty) {
        debugPrint('User stats not found');
        return false;
      }

      final stats = UserGamificationStats.fromJson(userStats.first);

      if (stats.totalPoints < pointsCost) {
        debugPrint('Insufficient points');
        return false;
      }

      // Record redemption
      await _supabase.insertData(
        table: 'reward_redemptions',
        data: {
          'user_id': userId,
          'reward_id': rewardId,
          'points_spent': pointsCost,
          'redeemed_at': DateTime.now().toIso8601String(),
          'status': 'pending',
        },
      );

      // Deduct points
      await _updateUserPoints(userId, -pointsCost);

      return true;
    } catch (e) {
      debugPrint('Error redeeming reward: $e');
      return false;
    }
  }

  /// Private helper methods

  Future<void> _updateUserPoints(String userId, int pointsChange) async {
    try {
      final userStats = await _supabase.fetchData(
        table: 'user_gamification_stats',
        filters: {'user_id': userId},
      );

      if (userStats.isEmpty) {
        // Create initial stats
        await _createInitialStats(userId);
        await _updateUserPoints(userId, pointsChange);
        return;
      }

      final stats = userStats.first;
      final currentPoints = stats['total_points'] ?? 0;
      final newPoints =
          (currentPoints + pointsChange).clamp(0, double.infinity).toInt();

      await _supabase.updateData(
        table: 'user_gamification_stats',
        data: {
          'total_points': newPoints,
          'updated_at': DateTime.now().toIso8601String(),
        },
        column: 'user_id',
        value: userId,
      );
    } catch (e) {
      debugPrint('Error updating user points: $e');
    }
  }

  Future<void> _checkAchievements(String userId) async {
    try {
      // Get user's current stats
      final userStats = await _supabase.fetchData(
        table: 'user_gamification_stats',
        filters: {'user_id': userId},
      );

      if (userStats.isEmpty) return;

      final stats = UserGamificationStats.fromJson(userStats.first);

      // Get all achievements user hasn't unlocked yet
      final unlockedAchievements = await _supabase.fetchData(
        table: 'user_achievements',
        filters: {'user_id': userId},
      );

      final unlockedIds =
          unlockedAchievements.map((a) => a['achievement_id']).toSet();

      final allAchievements = await _supabase.fetchData(
        table: 'achievements',
        filters: {'is_active': true},
      );

      for (final achievement in allAchievements) {
        final achievementId = achievement['id'];

        if (unlockedIds.contains(achievementId)) continue;

        // Check if criteria is met
        if (_checkAchievementCriteria(achievement, stats)) {
          await unlockAchievement(
            userId: userId,
            achievementId: achievementId,
            metadata: {'auto_unlocked': true},
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking achievements: $e');
    }
  }

  bool _checkAchievementCriteria(
    Map<String, dynamic> achievement,
    UserGamificationStats stats,
  ) {
    final criteria = achievement['criteria'] as Map<String, dynamic>? ?? {};

    // Check points requirement
    if (criteria.containsKey('total_points')) {
      if (stats.totalPoints < criteria['total_points']) return false;
    }

    // Check level requirement
    if (criteria.containsKey('level')) {
      if (stats.level < criteria['level']) return false;
    }

    // Check streak requirement
    if (criteria.containsKey('streak_days')) {
      if (stats.currentStreak < criteria['streak_days']) return false;
    }

    // Add more criteria checks as needed

    return true;
  }

  Future<void> _checkLevelUp(String userId) async {
    try {
      final userStats = await _supabase.fetchData(
        table: 'user_gamification_stats',
        filters: {'user_id': userId},
      );

      if (userStats.isEmpty) return;

      final stats = userStats.first;
      final currentLevel = stats['level'] ?? 1;
      final totalPoints = stats['total_points'] ?? 0;

      // Calculate new level based on points
      final newLevel = _calculateLevel(totalPoints);

      if (newLevel > currentLevel) {
        await _supabase.updateData(
          table: 'user_gamification_stats',
          data: {
            'level': newLevel,
            'updated_at': DateTime.now().toIso8601String(),
          },
          column: 'user_id',
          value: userId,
        );

        // Award level up bonus
        await awardPoints(
          userId: userId,
          points: newLevel * 50, // 50 points per level
          reason: 'Level up to $newLevel',
          category: PointsCategory.levelUp,
          metadata: {'new_level': newLevel, 'old_level': currentLevel},
        );

        // Send level up notification
        await _sendLevelUpNotification(userId, newLevel);
      }
    } catch (e) {
      debugPrint('Error checking level up: $e');
    }
  }

  int _calculateLevel(int totalPoints) {
    // Level formula: sqrt(points / 1000) + 1
    return math.sqrt(totalPoints / 1000).floor() + 1;
  }

  Future<void> _updateLearningStreak(
      String userId, DateTime activityDate) async {
    try {
      final userStats = await _supabase.fetchData(
        table: 'user_gamification_stats',
        filters: {'user_id': userId},
      );

      if (userStats.isEmpty) return;

      final stats = userStats.first;
      final lastActivityDate = stats['last_activity_date'] != null
          ? DateTime.parse(stats['last_activity_date'])
          : null;

      final currentStreak = stats['current_streak'] ?? 0;
      final longestStreak = stats['longest_streak'] ?? 0;

      int newStreak = currentStreak;

      if (lastActivityDate == null) {
        // First activity
        newStreak = 1;
      } else {
        final daysDiff = activityDate.difference(lastActivityDate).inDays;

        if (daysDiff == 1) {
          // Consecutive day
          newStreak = currentStreak + 1;
        } else if (daysDiff > 1) {
          // Streak broken
          newStreak = 1;
        }
        // If daysDiff == 0, same day activity, keep current streak
      }

      final newLongestStreak =
          newStreak > longestStreak ? newStreak : longestStreak;

      await _supabase.updateData(
        table: 'user_gamification_stats',
        data: {
          'current_streak': newStreak,
          'longest_streak': newLongestStreak,
          'last_activity_date': activityDate.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        column: 'user_id',
        value: userId,
      );
    } catch (e) {
      debugPrint('Error updating learning streak: $e');
    }
  }

  int _getActivityPoints(ActivityType activityType, int duration) {
    switch (activityType) {
      case ActivityType.sessionCompleted:
        return 50;
      case ActivityType.quizCompleted:
        return 25;
      case ActivityType.assignmentSubmitted:
        return 75;
      case ActivityType.moduleCompleted:
        return 100;
      case ActivityType.dailyLogin:
        return 10;
      case ActivityType.messagesSent:
        return 5;
      case ActivityType.studyGroupParticipation:
        return 30;
      case ActivityType.videoCallAttended:
        return (duration / 10).floor() * 5; // 5 points per 10 minutes
    }
  }

  Future<UserGamificationStats> _createInitialStats(String userId) async {
    final initialData = {
      'user_id': userId,
      'total_points': 0,
      'level': 1,
      'current_streak': 0,
      'longest_streak': 0,
      'achievements_count': 0,
      'challenges_completed': 0,
      'last_activity_date': null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase.insertData(
      table: 'user_gamification_stats',
      data: initialData,
    );

    return UserGamificationStats.fromJson(initialData);
  }

  Future<List<UserAchievement>> _getUserAchievements(String userId) async {
    final userAchievements = await _supabase.fetchData(
      table: 'user_achievements',
      filters: {'user_id': userId},
    );

    return userAchievements.map((ua) => UserAchievement.fromJson(ua)).toList();
  }

  Future<List<UserChallenge>> _getUserActiveChallenges(String userId) async {
    final participations = await _supabase.fetchData(
      table: 'challenge_participants',
      filters: {
        'user_id': userId,
        'status': 'active',
      },
    );

    return participations.map((p) => UserChallenge.fromJson(p)).toList();
  }

  Future<List<LearningActivity>> _getRecentActivities(String userId) async {
    final activities = await _supabase.fetchData(
      table: 'learning_activities',
      filters: {'user_id': userId},
    );

    // Sort by timestamp descending and take last 20
    activities.sort((a, b) {
      final aTime = DateTime.parse(a['timestamp']);
      final bTime = DateTime.parse(b['timestamp']);
      return bTime.compareTo(aTime);
    });

    final recentActivities = activities.take(20).toList();

    return recentActivities.map((a) => LearningActivity.fromJson(a)).toList();
  }

  Future<List<LeaderboardEntry>> _getPointsLeaderboard(
    LeaderboardTimeframe timeframe,
    int limit,
    int offset,
  ) async {
    final stats = await _supabase.fetchData(
      table: 'user_gamification_stats',
      filters: {},
    );

    // Sort by total points descending
    stats.sort(
        (a, b) => (b['total_points'] ?? 0).compareTo(a['total_points'] ?? 0));

    // Apply pagination
    final paginatedStats = stats.skip(offset).take(limit).toList();

    return paginatedStats.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;

      return LeaderboardEntry(
        rank: offset + index + 1,
        userId: stat['user_id'],
        score: (stat['total_points'] ?? 0).toDouble(),
        metadata: {'level': stat['level'] ?? 1},
      );
    }).toList();
  }

  Future<List<LeaderboardEntry>> _getStreaksLeaderboard(
    LeaderboardTimeframe timeframe,
    int limit,
    int offset,
  ) async {
    final stats = await _supabase.fetchData(
      table: 'user_gamification_stats',
      filters: {},
    );

    // Sort by current streak descending
    stats.sort((a, b) =>
        (b['current_streak'] ?? 0).compareTo(a['current_streak'] ?? 0));

    final paginatedStats = stats.skip(offset).take(limit).toList();

    return paginatedStats.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;

      return LeaderboardEntry(
        rank: offset + index + 1,
        userId: stat['user_id'],
        score: (stat['current_streak'] ?? 0).toDouble(),
        metadata: {'longest_streak': stat['longest_streak'] ?? 0},
      );
    }).toList();
  }

  Future<List<LeaderboardEntry>> _getAchievementsLeaderboard(
    LeaderboardTimeframe timeframe,
    int limit,
    int offset,
  ) async {
    final stats = await _supabase.fetchData(
      table: 'user_gamification_stats',
      filters: {},
    );

    // Sort by achievements count descending
    stats.sort((a, b) =>
        (b['achievements_count'] ?? 0).compareTo(a['achievements_count'] ?? 0));

    final paginatedStats = stats.skip(offset).take(limit).toList();

    return paginatedStats.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;

      return LeaderboardEntry(
        rank: offset + index + 1,
        userId: stat['user_id'],
        score: (stat['achievements_count'] ?? 0).toDouble(),
        metadata: {'total_points': stat['total_points'] ?? 0},
      );
    }).toList();
  }

  Future<List<LeaderboardEntry>> _getChallengesLeaderboard(
    LeaderboardTimeframe timeframe,
    int limit,
    int offset,
  ) async {
    final stats = await _supabase.fetchData(
      table: 'user_gamification_stats',
      filters: {},
    );

    // Sort by challenges completed descending
    stats.sort((a, b) => (b['challenges_completed'] ?? 0)
        .compareTo(a['challenges_completed'] ?? 0));

    final paginatedStats = stats.skip(offset).take(limit).toList();

    return paginatedStats.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;

      return LeaderboardEntry(
        rank: offset + index + 1,
        userId: stat['user_id'],
        score: (stat['challenges_completed'] ?? 0).toDouble(),
        metadata: {'total_points': stat['total_points'] ?? 0},
      );
    }).toList();
  }

  Future<void> _awardChallengeRewards(String challengeId, String userId) async {
    try {
      final challenges = await _supabase.fetchData(
        table: 'challenges',
        filters: {'id': challengeId},
      );

      if (challenges.isEmpty) return;

      final challenge = challenges.first;
      final rewards = challenge['rewards'] as List? ?? [];

      for (final rewardData in rewards) {
        final reward = ChallengeReward.fromJson(rewardData);

        if (reward.type == 'points') {
          await awardPoints(
            userId: userId,
            points: reward.value.toInt(),
            reason: 'Challenge completed: ${challenge['title']}',
            category: PointsCategory.challenge,
            metadata: {'challenge_id': challengeId},
          );
        } else if (reward.type == 'achievement') {
          await unlockAchievement(
            userId: userId,
            achievementId: reward.value.toString(),
            metadata: {'challenge_id': challengeId},
          );
        }
      }
    } catch (e) {
      debugPrint('Error awarding challenge rewards: $e');
    }
  }

  Future<void> _sendAchievementNotification(
    String userId,
    Map<String, dynamic> achievement,
  ) async {
    try {
      await _supabase.insertData(
        table: 'notifications',
        data: {
          'user_id': userId,
          'type': 'achievement_unlocked',
          'title': 'Achievement Unlocked!',
          'message': 'You have unlocked "${achievement['name']}"',
          'data': {
            'achievement_id': achievement['id'],
            'achievement_name': achievement['name'],
          },
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error sending achievement notification: $e');
    }
  }

  Future<void> _sendLevelUpNotification(String userId, int newLevel) async {
    try {
      await _supabase.insertData(
        table: 'notifications',
        data: {
          'user_id': userId,
          'type': 'level_up',
          'title': 'Level Up!',
          'message': 'Congratulations! You have reached level $newLevel',
          'data': {'new_level': newLevel},
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error sending level up notification: $e');
    }
  }
}

/// Data models for gamification

enum PointsCategory {
  activity,
  achievement,
  challenge,
  levelUp,
  bonus,
  social,
}

enum ChallengeType {
  individual,
  team,
  global,
  timeLimit,
  milestone,
}

enum ActivityType {
  sessionCompleted,
  quizCompleted,
  assignmentSubmitted,
  moduleCompleted,
  dailyLogin,
  messagesSent,
  studyGroupParticipation,
  videoCallAttended,
}

enum LeaderboardType {
  totalPoints,
  streaks,
  achievements,
  challenges,
}

enum LeaderboardTimeframe {
  daily,
  weekly,
  monthly,
  allTime,
}

class ChallengeReward {
  final String type; // 'points', 'achievement', 'badge'
  final double value;
  final String description;

  ChallengeReward({
    required this.type,
    required this.value,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'description': description,
      };

  factory ChallengeReward.fromJson(Map<String, dynamic> json) =>
      ChallengeReward(
        type: json['type'] ?? '',
        value: (json['value'] ?? 0).toDouble(),
        description: json['description'] ?? '',
      );
}

class UserGamificationStats {
  final String userId;
  final int totalPoints;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final int achievementsCount;
  final int challengesCompleted;
  final DateTime? lastActivityDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserGamificationStats({
    required this.userId,
    required this.totalPoints,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    required this.achievementsCount,
    required this.challengesCompleted,
    this.lastActivityDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserGamificationStats.fromJson(Map<String, dynamic> json) =>
      UserGamificationStats(
        userId: json['user_id'] ?? '',
        totalPoints: json['total_points'] ?? 0,
        level: json['level'] ?? 1,
        currentStreak: json['current_streak'] ?? 0,
        longestStreak: json['longest_streak'] ?? 0,
        achievementsCount: json['achievements_count'] ?? 0,
        challengesCompleted: json['challenges_completed'] ?? 0,
        lastActivityDate: json['last_activity_date'] != null
            ? DateTime.parse(json['last_activity_date'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'total_points': totalPoints,
        'level': level,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'achievements_count': achievementsCount,
        'challenges_completed': challengesCompleted,
        'last_activity_date': lastActivityDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class UserAchievement {
  final String userId;
  final String achievementId;
  final DateTime unlockedAt;
  final Map<String, dynamic> metadata;

  UserAchievement({
    required this.userId,
    required this.achievementId,
    required this.unlockedAt,
    this.metadata = const {},
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) =>
      UserAchievement(
        userId: json['user_id'] ?? '',
        achievementId: json['achievement_id'] ?? '',
        unlockedAt: DateTime.parse(json['unlocked_at']),
        metadata: json['metadata'] ?? {},
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'achievement_id': achievementId,
        'unlocked_at': unlockedAt.toIso8601String(),
        'metadata': metadata,
      };
}

class UserChallenge {
  final String challengeId;
  final String userId;
  final DateTime joinedAt;
  final double progress;
  final String status;
  final DateTime? completedAt;

  UserChallenge({
    required this.challengeId,
    required this.userId,
    required this.joinedAt,
    required this.progress,
    required this.status,
    this.completedAt,
  });

  factory UserChallenge.fromJson(Map<String, dynamic> json) => UserChallenge(
        challengeId: json['challenge_id'] ?? '',
        userId: json['user_id'] ?? '',
        joinedAt: DateTime.parse(json['joined_at']),
        progress: (json['progress'] ?? 0).toDouble(),
        status: json['status'] ?? '',
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'challenge_id': challengeId,
        'user_id': userId,
        'joined_at': joinedAt.toIso8601String(),
        'progress': progress,
        'status': status,
        'completed_at': completedAt?.toIso8601String(),
      };
}

class LearningActivity {
  final String userId;
  final ActivityType activityType;
  final DateTime timestamp;
  final int duration;
  final Map<String, dynamic> metadata;

  LearningActivity({
    required this.userId,
    required this.activityType,
    required this.timestamp,
    required this.duration,
    this.metadata = const {},
  });

  factory LearningActivity.fromJson(Map<String, dynamic> json) =>
      LearningActivity(
        userId: json['user_id'] ?? '',
        activityType: ActivityType.values.firstWhere(
          (t) => t.toString().split('.').last == json['activity_type'],
          orElse: () => ActivityType.dailyLogin,
        ),
        timestamp: DateTime.parse(json['timestamp']),
        duration: json['duration'] ?? 0,
        metadata: json['metadata'] ?? {},
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'activity_type': activityType.toString().split('.').last,
        'timestamp': timestamp.toIso8601String(),
        'duration': duration,
        'metadata': metadata,
      };
}

class LeaderboardEntry {
  final int rank;
  final String userId;
  final double score;
  final Map<String, dynamic> metadata;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.score,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'user_id': userId,
        'score': score,
        'metadata': metadata,
      };
}

class UserReward {
  final String id;
  final String name;
  final String description;
  final String type;
  final int pointsCost;
  final int levelRequired;
  final bool isActive;

  UserReward({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.pointsCost,
    required this.levelRequired,
    required this.isActive,
  });

  factory UserReward.fromJson(Map<String, dynamic> json) => UserReward(
        id: json['id'].toString(),
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        type: json['type'] ?? '',
        pointsCost: json['points_cost'] ?? 0,
        levelRequired: json['level_required'] ?? 1,
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
        'points_cost': pointsCost,
        'level_required': levelRequired,
        'is_active': isActive,
      };
}

class UserGamificationProfile {
  final String userId;
  final UserGamificationStats stats;
  final List<UserAchievement> achievements;
  final List<UserChallenge> activeChallenges;
  final List<LearningActivity> recentActivities;

  UserGamificationProfile({
    required this.userId,
    required this.stats,
    required this.achievements,
    required this.activeChallenges,
    required this.recentActivities,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'stats': stats.toJson(),
        'achievements': achievements.map((a) => a.toJson()).toList(),
        'active_challenges': activeChallenges.map((c) => c.toJson()).toList(),
        'recent_activities': recentActivities.map((a) => a.toJson()).toList(),
      };
}
