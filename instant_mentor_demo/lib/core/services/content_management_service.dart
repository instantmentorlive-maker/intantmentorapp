import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Content management service for educational resources
class ContentManagementService {
  static ContentManagementService? _instance;
  static ContentManagementService get instance =>
      _instance ??= ContentManagementService._();

  ContentManagementService._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Create a new learning module
  Future<String?> createLearningModule({
    required String title,
    required String subject,
    required String description,
    required String difficulty,
    required String creatorId,
    List<String> topics = const [],
    List<String> prerequisites = const [],
    int estimatedDuration = 60,
  }) async {
    try {
      final moduleData = {
        'title': title,
        'subject': subject,
        'description': description,
        'difficulty': difficulty,
        'creator_id': creatorId,
        'topics': topics,
        'prerequisites': prerequisites,
        'estimated_duration': estimatedDuration,
        'status': 'draft',
        'is_public': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'learning_modules',
        data: moduleData,
      );

      return result['id'].toString();
    } catch (e) {
      debugPrint('Error creating learning module: $e');
      return null;
    }
  }

  /// Add content to a learning module
  Future<bool> addModuleContent({
    required String moduleId,
    required String
        contentType, // 'text', 'video', 'quiz', 'exercise', 'resource'
    required String title,
    required Map<String, dynamic> content,
    int orderIndex = 0,
  }) async {
    try {
      final contentData = {
        'module_id': moduleId,
        'content_type': contentType,
        'title': title,
        'content': content,
        'order_index': orderIndex,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.insertData(
        table: 'module_content',
        data: contentData,
      );

      return true;
    } catch (e) {
      debugPrint('Error adding module content: $e');
      return false;
    }
  }

  /// Create an interactive quiz
  Future<String?> createQuiz({
    required String title,
    required String subject,
    required String difficulty,
    required String creatorId,
    required List<QuizQuestion> questions,
    int timeLimit = 0, // 0 = no time limit
    int passingScore = 70,
  }) async {
    try {
      final quizData = {
        'title': title,
        'subject': subject,
        'difficulty': difficulty,
        'creator_id': creatorId,
        'time_limit': timeLimit,
        'passing_score': passingScore,
        'total_questions': questions.length,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'quizzes',
        data: quizData,
      );

      final quizId = result['id'].toString();

      // Add questions to quiz
      for (int i = 0; i < questions.length; i++) {
        await _addQuizQuestion(quizId, questions[i], i + 1);
      }

      return quizId;
    } catch (e) {
      debugPrint('Error creating quiz: $e');
      return null;
    }
  }

  /// Submit quiz attempt
  Future<QuizResult?> submitQuizAttempt({
    required String quizId,
    required String studentId,
    required Map<String, dynamic> answers,
    int timeSpent = 0,
  }) async {
    try {
      // Get quiz and questions
      final quiz = await _getQuiz(quizId);
      if (quiz == null) return null;

      final questions = await _getQuizQuestions(quizId);

      // Calculate score
      final result = _calculateQuizScore(questions, answers);

      // Save quiz attempt
      final attemptData = {
        'quiz_id': quizId,
        'student_id': studentId,
        'answers': answers,
        'score': result.score,
        'total_questions': questions.length,
        'correct_answers': result.correctAnswers,
        'time_spent': timeSpent,
        'passed': result.score >= quiz['passing_score'],
        'completed_at': DateTime.now().toIso8601String(),
      };

      await _supabase.insertData(
        table: 'quiz_attempts',
        data: attemptData,
      );

      return result;
    } catch (e) {
      debugPrint('Error submitting quiz attempt: $e');
      return null;
    }
  }

  /// Create an assignment
  Future<String?> createAssignment({
    required String title,
    required String subject,
    required String description,
    required String mentorId,
    required DateTime dueDate,
    required AssignmentType type,
    Map<String, dynamic> requirements = const {},
    int maxPoints = 100,
  }) async {
    try {
      final assignmentData = {
        'title': title,
        'subject': subject,
        'description': description,
        'mentor_id': mentorId,
        'due_date': dueDate.toIso8601String(),
        'assignment_type': type.toString().split('.').last,
        'requirements': requirements,
        'max_points': maxPoints,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'assignments',
        data: assignmentData,
      );

      return result['id'].toString();
    } catch (e) {
      debugPrint('Error creating assignment: $e');
      return null;
    }
  }

  /// Submit assignment
  Future<bool> submitAssignment({
    required String assignmentId,
    required String studentId,
    required Map<String, dynamic> submission,
    List<String> attachments = const [],
  }) async {
    try {
      final submissionData = {
        'assignment_id': assignmentId,
        'student_id': studentId,
        'submission_content': submission,
        'attachments': attachments,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'submitted',
      };

      await _supabase.insertData(
        table: 'assignment_submissions',
        data: submissionData,
      );

      return true;
    } catch (e) {
      debugPrint('Error submitting assignment: $e');
      return false;
    }
  }

  /// Grade assignment submission
  Future<bool> gradeAssignment({
    required String submissionId,
    required String mentorId,
    required int score,
    required String feedback,
    Map<String, dynamic> detailedFeedback = const {},
  }) async {
    try {
      await _supabase.updateData(
        table: 'assignment_submissions',
        data: {
          'score': score,
          'feedback': feedback,
          'detailed_feedback': detailedFeedback,
          'graded_by': mentorId,
          'graded_at': DateTime.now().toIso8601String(),
          'status': 'graded',
        },
        column: 'id',
        value: submissionId,
      );

      return true;
    } catch (e) {
      debugPrint('Error grading assignment: $e');
      return false;
    }
  }

  /// Create a resource library entry
  Future<String?> createResource({
    required String title,
    required String subject,
    required String
        resourceType, // 'document', 'video', 'link', 'image', 'audio'
    required String url,
    required String creatorId,
    String description = '',
    List<String> tags = const [],
    String difficulty = 'intermediate',
    bool isPublic = true,
  }) async {
    try {
      final resourceData = {
        'title': title,
        'subject': subject,
        'resource_type': resourceType,
        'url': url,
        'description': description,
        'creator_id': creatorId,
        'tags': tags,
        'difficulty': difficulty,
        'is_public': isPublic,
        'downloads': 0,
        'views': 0,
        'rating': 0.0,
        'rating_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'resources',
        data: resourceData,
      );

      return result['id'].toString();
    } catch (e) {
      debugPrint('Error creating resource: $e');
      return null;
    }
  }

  /// Search content
  Future<List<ContentItem>> searchContent({
    String query = '',
    String? subject,
    String? contentType,
    String? difficulty,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final searchResults = <ContentItem>[];

      // Search in learning modules
      final modules = await _searchLearningModules(
        query: query,
        subject: subject,
        difficulty: difficulty,
        limit: limit ~/ 4,
      );
      searchResults.addAll(modules);

      // Search in quizzes
      final quizzes = await _searchQuizzes(
        query: query,
        subject: subject,
        difficulty: difficulty,
        limit: limit ~/ 4,
      );
      searchResults.addAll(quizzes);

      // Search in assignments
      final assignments = await _searchAssignments(
        query: query,
        subject: subject,
        limit: limit ~/ 4,
      );
      searchResults.addAll(assignments);

      // Search in resources
      final resources = await _searchResources(
        query: query,
        subject: subject,
        resourceType: contentType,
        difficulty: difficulty,
        limit: limit ~/ 4,
      );
      searchResults.addAll(resources);

      return searchResults;
    } catch (e) {
      debugPrint('Error searching content: $e');
      return [];
    }
  }

  /// Get student progress for a module
  Future<ModuleProgress?> getModuleProgress({
    required String moduleId,
    required String studentId,
  }) async {
    try {
      final progressData = await _supabase.fetchData(
        table: 'module_progress',
        filters: {
          'module_id': moduleId,
          'student_id': studentId,
        },
      );

      if (progressData.isEmpty) {
        // Create initial progress record
        await _supabase.insertData(
          table: 'module_progress',
          data: {
            'module_id': moduleId,
            'student_id': studentId,
            'progress_percentage': 0,
            'completed_sections': <String>[],
            'started_at': DateTime.now().toIso8601String(),
          },
        );

        return ModuleProgress(
          moduleId: moduleId,
          studentId: studentId,
          progressPercentage: 0,
          completedSections: [],
          startedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        );
      }

      final progress = progressData.first;
      return ModuleProgress(
        moduleId: moduleId,
        studentId: studentId,
        progressPercentage: (progress['progress_percentage'] ?? 0).toDouble(),
        completedSections:
            List<String>.from(progress['completed_sections'] ?? []),
        startedAt: DateTime.parse(progress['started_at']),
        lastAccessedAt: progress['last_accessed_at'] != null
            ? DateTime.parse(progress['last_accessed_at'])
            : DateTime.parse(progress['started_at']),
        completedAt: progress['completed_at'] != null
            ? DateTime.parse(progress['completed_at'])
            : null,
      );
    } catch (e) {
      debugPrint('Error getting module progress: $e');
      return null;
    }
  }

  /// Update module progress
  Future<bool> updateModuleProgress({
    required String moduleId,
    required String studentId,
    required String sectionId,
    double progressIncrement = 0,
  }) async {
    try {
      final currentProgress = await getModuleProgress(
        moduleId: moduleId,
        studentId: studentId,
      );

      if (currentProgress == null) return false;

      final updatedSections =
          List<String>.from(currentProgress.completedSections);
      if (!updatedSections.contains(sectionId)) {
        updatedSections.add(sectionId);
      }

      final newProgress =
          currentProgress.progressPercentage + progressIncrement;
      final isCompleted = newProgress >= 100;

      await _supabase.updateData(
        table: 'module_progress',
        data: {
          'progress_percentage': newProgress.clamp(0, 100),
          'completed_sections': updatedSections,
          'last_accessed_at': DateTime.now().toIso8601String(),
          if (isCompleted) 'completed_at': DateTime.now().toIso8601String(),
        },
        column: 'module_id',
        value: moduleId,
      );

      return true;
    } catch (e) {
      debugPrint('Error updating module progress: $e');
      return false;
    }
  }

  /// Private helper methods

  Future<bool> _addQuizQuestion(
    String quizId,
    QuizQuestion question,
    int orderIndex,
  ) async {
    try {
      final questionData = {
        'quiz_id': quizId,
        'question_text': question.questionText,
        'question_type': question.type.toString().split('.').last,
        'options': question.options,
        'correct_answer': question.correctAnswer,
        'explanation': question.explanation,
        'points': question.points,
        'order_index': orderIndex,
      };

      await _supabase.insertData(
        table: 'quiz_questions',
        data: questionData,
      );

      return true;
    } catch (e) {
      debugPrint('Error adding quiz question: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getQuiz(String quizId) async {
    try {
      final quizzes = await _supabase.fetchData(
        table: 'quizzes',
        filters: {'id': quizId},
      );

      return quizzes.isNotEmpty ? quizzes.first : null;
    } catch (e) {
      debugPrint('Error getting quiz: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getQuizQuestions(String quizId) async {
    try {
      final questions = await _supabase.fetchData(
        table: 'quiz_questions',
        filters: {'quiz_id': quizId},
      );

      // Sort by order_index
      questions.sort(
          (a, b) => (a['order_index'] ?? 0).compareTo(b['order_index'] ?? 0));

      return questions;
    } catch (e) {
      debugPrint('Error getting quiz questions: $e');
      return [];
    }
  }

  QuizResult _calculateQuizScore(
    List<Map<String, dynamic>> questions,
    Map<String, dynamic> answers,
  ) {
    int correctAnswers = 0;
    int totalPoints = 0;
    int earnedPoints = 0;

    for (final question in questions) {
      final questionId = question['id'];
      final correctAnswer = question['correct_answer'];
      final studentAnswer = answers[questionId];
      final points = (question['points'] ?? 1).toInt();

      totalPoints += points;

      if (studentAnswer == correctAnswer) {
        correctAnswers++;
        earnedPoints += points;
      }
    }

    final score =
        totalPoints > 0 ? (earnedPoints / totalPoints * 100).round() : 0;

    return QuizResult(
      score: score,
      correctAnswers: correctAnswers,
      totalQuestions: questions.length,
      earnedPoints: earnedPoints,
      totalPoints: totalPoints,
    );
  }

  Future<List<ContentItem>> _searchLearningModules({
    String query = '',
    String? subject,
    String? difficulty,
    int limit = 5,
  }) async {
    try {
      final filters = <String, dynamic>{
        'is_public': true,
      };

      if (subject != null) {
        filters['subject'] = subject;
      }

      if (difficulty != null) {
        filters['difficulty'] = difficulty;
      }

      final modules = await _supabase.fetchData(
        table: 'learning_modules',
        filters: filters,
      );

      // Filter by query if provided
      var filteredModules = modules;
      if (query.isNotEmpty) {
        filteredModules = modules.where((module) {
          final title = (module['title'] ?? '').toString().toLowerCase();
          final description =
              (module['description'] ?? '').toString().toLowerCase();
          final searchQuery = query.toLowerCase();
          return title.contains(searchQuery) ||
              description.contains(searchQuery);
        }).toList();
      }

      // Limit results
      if (filteredModules.length > limit) {
        filteredModules = filteredModules.take(limit).toList();
      }

      return filteredModules
          .map<ContentItem>((module) => ContentItem(
                id: module['id'].toString(),
                title: module['title'],
                type: 'learning_module',
                subject: module['subject'],
                description: module['description'],
                difficulty: module['difficulty'],
                createdAt: DateTime.parse(module['created_at']),
                metadata: {
                  'topics': module['topics'],
                  'estimated_duration': module['estimated_duration'],
                },
              ))
          .toList();
    } catch (e) {
      debugPrint('Error searching learning modules: $e');
      return [];
    }
  }

  Future<List<ContentItem>> _searchQuizzes({
    String query = '',
    String? subject,
    String? difficulty,
    int limit = 5,
  }) async {
    try {
      final filters = <String, dynamic>{
        'status': 'active',
      };

      if (subject != null) {
        filters['subject'] = subject;
      }

      if (difficulty != null) {
        filters['difficulty'] = difficulty;
      }

      final quizzes = await _supabase.fetchData(
        table: 'quizzes',
        filters: filters,
      );

      // Filter by query if provided
      var filteredQuizzes = quizzes;
      if (query.isNotEmpty) {
        filteredQuizzes = quizzes.where((quiz) {
          final title = (quiz['title'] ?? '').toString().toLowerCase();
          final searchQuery = query.toLowerCase();
          return title.contains(searchQuery);
        }).toList();
      }

      // Limit results
      if (filteredQuizzes.length > limit) {
        filteredQuizzes = filteredQuizzes.take(limit).toList();
      }

      return filteredQuizzes
          .map<ContentItem>((quiz) => ContentItem(
                id: quiz['id'].toString(),
                title: quiz['title'],
                type: 'quiz',
                subject: quiz['subject'],
                description:
                    'Interactive quiz with ${quiz['total_questions']} questions',
                difficulty: quiz['difficulty'],
                createdAt: DateTime.parse(quiz['created_at']),
                metadata: {
                  'total_questions': quiz['total_questions'],
                  'time_limit': quiz['time_limit'],
                  'passing_score': quiz['passing_score'],
                },
              ))
          .toList();
    } catch (e) {
      debugPrint('Error searching quizzes: $e');
      return [];
    }
  }

  Future<List<ContentItem>> _searchAssignments({
    String query = '',
    String? subject,
    int limit = 5,
  }) async {
    try {
      final filters = <String, dynamic>{
        'status': 'active',
      };

      if (subject != null) {
        filters['subject'] = subject;
      }

      final assignments = await _supabase.fetchData(
        table: 'assignments',
        filters: filters,
      );

      // Filter by query if provided
      var filteredAssignments = assignments;
      if (query.isNotEmpty) {
        filteredAssignments = assignments.where((assignment) {
          final title = (assignment['title'] ?? '').toString().toLowerCase();
          final description =
              (assignment['description'] ?? '').toString().toLowerCase();
          final searchQuery = query.toLowerCase();
          return title.contains(searchQuery) ||
              description.contains(searchQuery);
        }).toList();
      }

      // Limit results
      if (filteredAssignments.length > limit) {
        filteredAssignments = filteredAssignments.take(limit).toList();
      }

      return filteredAssignments
          .map<ContentItem>((assignment) => ContentItem(
                id: assignment['id'].toString(),
                title: assignment['title'],
                type: 'assignment',
                subject: assignment['subject'],
                description: assignment['description'],
                difficulty:
                    'intermediate', // Default difficulty for assignments
                createdAt: DateTime.parse(assignment['created_at']),
                metadata: {
                  'due_date': assignment['due_date'],
                  'max_points': assignment['max_points'],
                  'assignment_type': assignment['assignment_type'],
                },
              ))
          .toList();
    } catch (e) {
      debugPrint('Error searching assignments: $e');
      return [];
    }
  }

  Future<List<ContentItem>> _searchResources({
    String query = '',
    String? subject,
    String? resourceType,
    String? difficulty,
    int limit = 5,
  }) async {
    try {
      final filters = <String, dynamic>{
        'is_public': true,
      };

      if (subject != null) {
        filters['subject'] = subject;
      }

      if (resourceType != null) {
        filters['resource_type'] = resourceType;
      }

      if (difficulty != null) {
        filters['difficulty'] = difficulty;
      }

      final resources = await _supabase.fetchData(
        table: 'resources',
        filters: filters,
      );

      // Filter by query if provided
      var filteredResources = resources;
      if (query.isNotEmpty) {
        filteredResources = resources.where((resource) {
          final title = (resource['title'] ?? '').toString().toLowerCase();
          final description =
              (resource['description'] ?? '').toString().toLowerCase();
          final searchQuery = query.toLowerCase();
          return title.contains(searchQuery) ||
              description.contains(searchQuery);
        }).toList();
      }

      // Limit results
      if (filteredResources.length > limit) {
        filteredResources = filteredResources.take(limit).toList();
      }

      return filteredResources
          .map<ContentItem>((resource) => ContentItem(
                id: resource['id'].toString(),
                title: resource['title'],
                type: 'resource',
                subject: resource['subject'],
                description: resource['description'],
                difficulty: resource['difficulty'],
                createdAt: DateTime.parse(resource['created_at']),
                metadata: {
                  'resource_type': resource['resource_type'],
                  'url': resource['url'],
                  'tags': resource['tags'],
                  'rating': resource['rating'],
                  'downloads': resource['downloads'],
                },
              ))
          .toList();
    } catch (e) {
      debugPrint('Error searching resources: $e');
      return [];
    }
  }
}

/// Data models for content management

enum QuestionType { multipleChoice, trueFalse, shortAnswer, essay, fillInBlank }

enum AssignmentType {
  essay,
  project,
  presentation,
  research,
  programming,
  creative
}

class QuizQuestion {
  final String questionText;
  final QuestionType type;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final int points;

  QuizQuestion({
    required this.questionText,
    required this.type,
    this.options = const [],
    required this.correctAnswer,
    this.explanation = '',
    this.points = 1,
  });

  Map<String, dynamic> toJson() => {
        'question_text': questionText,
        'type': type.toString().split('.').last,
        'options': options,
        'correct_answer': correctAnswer,
        'explanation': explanation,
        'points': points,
      };
}

class QuizResult {
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final int earnedPoints;
  final int totalPoints;

  QuizResult({
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.earnedPoints,
    required this.totalPoints,
  });

  bool get passed => score >= 70; // Default passing score

  Map<String, dynamic> toJson() => {
        'score': score,
        'correct_answers': correctAnswers,
        'total_questions': totalQuestions,
        'earned_points': earnedPoints,
        'total_points': totalPoints,
        'passed': passed,
      };
}

class ContentItem {
  final String id;
  final String title;
  final String type;
  final String subject;
  final String description;
  final String difficulty;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  ContentItem({
    required this.id,
    required this.title,
    required this.type,
    required this.subject,
    required this.description,
    required this.difficulty,
    required this.createdAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'subject': subject,
        'description': description,
        'difficulty': difficulty,
        'created_at': createdAt.toIso8601String(),
        'metadata': metadata,
      };
}

class ModuleProgress {
  final String moduleId;
  final String studentId;
  final double progressPercentage;
  final List<String> completedSections;
  final DateTime startedAt;
  final DateTime lastAccessedAt;
  final DateTime? completedAt;

  ModuleProgress({
    required this.moduleId,
    required this.studentId,
    required this.progressPercentage,
    required this.completedSections,
    required this.startedAt,
    required this.lastAccessedAt,
    this.completedAt,
  });

  bool get isCompleted => progressPercentage >= 100;
  bool get isInProgress => progressPercentage > 0 && progressPercentage < 100;
  bool get isNotStarted => progressPercentage == 0;

  Map<String, dynamic> toJson() => {
        'module_id': moduleId,
        'student_id': studentId,
        'progress_percentage': progressPercentage,
        'completed_sections': completedSections,
        'started_at': startedAt.toIso8601String(),
        'last_accessed_at': lastAccessedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'is_completed': isCompleted,
        'is_in_progress': isInProgress,
        'is_not_started': isNotStarted,
      };
}
