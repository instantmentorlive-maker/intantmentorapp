import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Advanced messaging and collaboration service
class AdvancedMessagingService {
  static AdvancedMessagingService? _instance;
  static AdvancedMessagingService get instance =>
      _instance ??= AdvancedMessagingService._();

  AdvancedMessagingService._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Create a new chat channel
  Future<String?> createChatChannel({
    required String name,
    required String type, // 'direct', 'group', 'study_group', 'class'
    required String creatorId,
    List<String> memberIds = const [],
    String description = '',
    bool isPrivate = false,
    Map<String, dynamic> settings = const {},
  }) async {
    try {
      final channelData = {
        'name': name,
        'type': type,
        'creator_id': creatorId,
        'description': description,
        'is_private': isPrivate,
        'member_count': memberIds.length + 1, // +1 for creator
        'settings': settings,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'chat_channels',
        data: channelData,
      );

      final channelId = result.first['id'].toString();

      // Add creator as member
      await _addChannelMember(
        channelId: channelId,
        userId: creatorId,
        role: 'admin',
      );

      // Add other members
      for (final memberId in memberIds) {
        await _addChannelMember(
          channelId: channelId,
          userId: memberId,
          role: 'member',
        );
      }

      return channelId;
    } catch (e) {
      debugPrint('Error creating chat channel: $e');
      return null;
    }
  }

  /// Send a message to a chat channel
  Future<String?> sendMessage({
    required String channelId,
    required String senderId,
    required MessageType type,
    required String content,
    String? replyToId,
    List<MessageAttachment> attachments = const [],
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final messageData = {
        'channel_id': channelId,
        'sender_id': senderId,
        'message_type': type.toString().split('.').last,
        'content': content,
        'reply_to_id': replyToId,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'metadata': metadata,
        'is_edited': false,
        'is_deleted': false,
        'sent_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'messages',
        data: messageData,
      );

      final messageId = result.first['id'].toString();

      // Update channel last activity
      await _updateChannelActivity(channelId);

      // Send real-time notification
      await _sendMessageNotification(channelId, messageId, senderId);

      return messageId;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  /// Edit an existing message
  Future<bool> editMessage({
    required String messageId,
    required String userId,
    required String newContent,
  }) async {
    try {
      // Verify user owns the message
      final messages = await _supabase.fetchData(
        table: 'messages',
        filters: {
          'id': messageId,
          'sender_id': userId,
        },
      );

      if (messages.isEmpty) {
        debugPrint('Message not found or user not authorized');
        return false;
      }

      await _supabase.updateData(
        table: 'messages',
        data: {
          'content': newContent,
          'is_edited': true,
          'edited_at': DateTime.now().toIso8601String(),
        },
        column: 'id',
        value: messageId,
      );

      return true;
    } catch (e) {
      debugPrint('Error editing message: $e');
      return false;
    }
  }

  /// Delete a message
  Future<bool> deleteMessage({
    required String messageId,
    required String userId,
  }) async {
    try {
      // Verify user owns the message or is admin
      final messages = await _supabase.fetchData(
        table: 'messages',
        filters: {
          'id': messageId,
          'sender_id': userId,
        },
      );

      if (messages.isEmpty) {
        debugPrint('Message not found or user not authorized');
        return false;
      }

      await _supabase.updateData(
        table: 'messages',
        data: {
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
        },
        column: 'id',
        value: messageId,
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }

  /// Get channel messages with pagination
  Future<List<ChatMessage>> getChannelMessages({
    required String channelId,
    int limit = 50,
    int offset = 0,
    DateTime? before,
    DateTime? after,
  }) async {
    try {
      final filters = <String, dynamic>{
        'channel_id': channelId,
        'is_deleted': false,
      };

      final messages = await _supabase.fetchData(
        table: 'messages',
        filters: filters,
      );

      // Sort by sent_at descending (newest first)
      messages.sort((a, b) {
        final aTime = DateTime.parse(a['sent_at']);
        final bTime = DateTime.parse(b['sent_at']);
        return bTime.compareTo(aTime);
      });

      // Apply pagination and date filters
      var filteredMessages = messages;

      if (before != null) {
        filteredMessages = filteredMessages.where((msg) {
          final msgTime = DateTime.parse(msg['sent_at']);
          return msgTime.isBefore(before);
        }).toList();
      }

      if (after != null) {
        filteredMessages = filteredMessages.where((msg) {
          final msgTime = DateTime.parse(msg['sent_at']);
          return msgTime.isAfter(after);
        }).toList();
      }

      // Apply pagination
      if (offset > 0) {
        filteredMessages = filteredMessages.skip(offset).toList();
      }

      if (filteredMessages.length > limit) {
        filteredMessages = filteredMessages.take(limit).toList();
      }

      return filteredMessages.map((msg) => ChatMessage.fromJson(msg)).toList();
    } catch (e) {
      debugPrint('Error getting channel messages: $e');
      return [];
    }
  }

  /// Search messages in a channel
  Future<List<ChatMessage>> searchMessages({
    required String channelId,
    required String query,
    MessageType? messageType,
    DateTime? after,
    DateTime? before,
    int limit = 50,
  }) async {
    try {
      final filters = <String, dynamic>{
        'channel_id': channelId,
        'is_deleted': false,
      };

      if (messageType != null) {
        filters['message_type'] = messageType.toString().split('.').last;
      }

      final messages = await _supabase.fetchData(
        table: 'messages',
        filters: filters,
      );

      // Filter by search query
      var searchResults = messages.where((msg) {
        final content = (msg['content'] ?? '').toString().toLowerCase();
        final searchQuery = query.toLowerCase();
        return content.contains(searchQuery);
      }).toList();

      // Apply date filters
      if (after != null) {
        searchResults = searchResults.where((msg) {
          final msgTime = DateTime.parse(msg['sent_at']);
          return msgTime.isAfter(after);
        }).toList();
      }

      if (before != null) {
        searchResults = searchResults.where((msg) {
          final msgTime = DateTime.parse(msg['sent_at']);
          return msgTime.isBefore(before);
        }).toList();
      }

      // Sort by relevance (exact matches first, then by recency)
      searchResults.sort((a, b) {
        final aContent = (a['content'] ?? '').toString().toLowerCase();
        final bContent = (b['content'] ?? '').toString().toLowerCase();
        final searchQuery = query.toLowerCase();

        final aExactMatch = aContent == searchQuery;
        final bExactMatch = bContent == searchQuery;

        if (aExactMatch && !bExactMatch) return -1;
        if (!aExactMatch && bExactMatch) return 1;

        // Sort by recency
        final aTime = DateTime.parse(a['sent_at']);
        final bTime = DateTime.parse(b['sent_at']);
        return bTime.compareTo(aTime);
      });

      // Apply limit
      if (searchResults.length > limit) {
        searchResults = searchResults.take(limit).toList();
      }

      return searchResults.map((msg) => ChatMessage.fromJson(msg)).toList();
    } catch (e) {
      debugPrint('Error searching messages: $e');
      return [];
    }
  }

  /// Create a study group
  Future<String?> createStudyGroup({
    required String name,
    required String subject,
    required String creatorId,
    String description = '',
    int maxMembers = 10,
    List<String> tags = const [],
    StudyGroupType type = StudyGroupType.collaborative,
    Map<String, dynamic> settings = const {},
  }) async {
    try {
      final studyGroupData = {
        'name': name,
        'subject': subject,
        'description': description,
        'creator_id': creatorId,
        'max_members': maxMembers,
        'current_members': 1, // Creator
        'tags': tags,
        'group_type': type.toString().split('.').last,
        'settings': settings,
        'is_active': true,
        'is_public': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'study_groups',
        data: studyGroupData,
      );

      final groupId = result.first['id'].toString();

      // Add creator as admin member
      await _addStudyGroupMember(
        groupId: groupId,
        userId: creatorId,
        role: 'admin',
      );

      // Create associated chat channel
      final channelId = await createChatChannel(
        name: 'Study Group: $name',
        type: 'study_group',
        creatorId: creatorId,
        description: 'Chat for $name study group',
      );

      if (channelId != null) {
        await _supabase.updateData(
          table: 'study_groups',
          data: {'chat_channel_id': channelId},
          column: 'id',
          value: groupId,
        );
      }

      return groupId;
    } catch (e) {
      debugPrint('Error creating study group: $e');
      return null;
    }
  }

  /// Join a study group
  Future<bool> joinStudyGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Check if group exists and has space
      final groups = await _supabase.fetchData(
        table: 'study_groups',
        filters: {'id': groupId},
      );

      if (groups.isEmpty) {
        debugPrint('Study group not found');
        return false;
      }

      final group = groups.first;
      final currentMembers = group['current_members'] ?? 0;
      final maxMembers = group['max_members'] ?? 10;

      if (currentMembers >= maxMembers) {
        debugPrint('Study group is full');
        return false;
      }

      // Check if user is already a member
      final existingMembers = await _supabase.fetchData(
        table: 'study_group_members',
        filters: {
          'study_group_id': groupId,
          'user_id': userId,
        },
      );

      if (existingMembers.isNotEmpty) {
        debugPrint('User is already a member');
        return false;
      }

      // Add user as member
      await _addStudyGroupMember(
        groupId: groupId,
        userId: userId,
        role: 'member',
      );

      // Update member count
      await _supabase.updateData(
        table: 'study_groups',
        data: {'current_members': currentMembers + 1},
        column: 'id',
        value: groupId,
      );

      // Add to associated chat channel
      final channelId = group['chat_channel_id'];
      if (channelId != null) {
        await _addChannelMember(
          channelId: channelId,
          userId: userId,
          role: 'member',
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error joining study group: $e');
      return false;
    }
  }

  /// Schedule a study session
  Future<String?> scheduleStudySession({
    required String groupId,
    required String organizerId,
    required String title,
    required DateTime scheduledTime,
    required int durationMinutes,
    String description = '',
    String? location,
    bool isVirtual = true,
    Map<String, dynamic> resources = const {},
  }) async {
    try {
      final sessionData = {
        'study_group_id': groupId,
        'organizer_id': organizerId,
        'title': title,
        'description': description,
        'scheduled_time': scheduledTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'location': location,
        'is_virtual': isVirtual,
        'resources': resources,
        'status': 'scheduled',
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'study_sessions',
        data: sessionData,
      );

      final sessionId = result.first['id'].toString();

      // Notify group members
      await _notifyStudySessionScheduled(groupId, sessionId);

      return sessionId;
    } catch (e) {
      debugPrint('Error scheduling study session: $e');
      return null;
    }
  }

  /// Create a collaborative workspace
  Future<String?> createCollaborativeWorkspace({
    required String name,
    required String creatorId,
    required WorkspaceType type,
    String description = '',
    List<String> memberIds = const [],
    Map<String, dynamic> settings = const {},
  }) async {
    try {
      final workspaceData = {
        'name': name,
        'description': description,
        'creator_id': creatorId,
        'workspace_type': type.toString().split('.').last,
        'member_count': memberIds.length + 1,
        'settings': settings,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'collaborative_workspaces',
        data: workspaceData,
      );

      final workspaceId = result.first['id'].toString();

      // Add creator as admin
      await _addWorkspaceMember(
        workspaceId: workspaceId,
        userId: creatorId,
        role: 'admin',
        permissions: ['read', 'write', 'admin'],
      );

      // Add other members
      for (final memberId in memberIds) {
        await _addWorkspaceMember(
          workspaceId: workspaceId,
          userId: memberId,
          role: 'collaborator',
          permissions: ['read', 'write'],
        );
      }

      return workspaceId;
    } catch (e) {
      debugPrint('Error creating collaborative workspace: $e');
      return null;
    }
  }

  /// Share a document in workspace
  Future<String?> shareDocument({
    required String workspaceId,
    required String userId,
    required String title,
    required String content,
    required DocumentType type,
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final documentData = {
        'workspace_id': workspaceId,
        'owner_id': userId,
        'title': title,
        'content': content,
        'document_type': type.toString().split('.').last,
        'tags': tags,
        'metadata': metadata,
        'version': 1,
        'is_public': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.insertData(
        table: 'shared_documents',
        data: documentData,
      );

      return result.first['id'].toString();
    } catch (e) {
      debugPrint('Error sharing document: $e');
      return null;
    }
  }

  /// Get user's chat channels
  Future<List<ChatChannel>> getUserChannels(String userId) async {
    try {
      final memberChannels = await _supabase.fetchData(
        table: 'channel_members',
        filters: {'user_id': userId},
      );

      final channelIds = memberChannels.map((m) => m['channel_id']).toList();

      if (channelIds.isEmpty) return [];

      final channels = await _supabase.fetchData(
        table: 'chat_channels',
        filters: {},
      );

      final userChannels =
          channels.where((c) => channelIds.contains(c['id'])).toList();

      return userChannels.map((c) => ChatChannel.fromJson(c)).toList();
    } catch (e) {
      debugPrint('Error getting user channels: $e');
      return [];
    }
  }

  /// Private helper methods

  Future<bool> _addChannelMember({
    required String channelId,
    required String userId,
    required String role,
  }) async {
    try {
      final memberData = {
        'channel_id': channelId,
        'user_id': userId,
        'role': role,
        'joined_at': DateTime.now().toIso8601String(),
      };

      await _supabase.insertData(
        table: 'channel_members',
        data: memberData,
      );

      return true;
    } catch (e) {
      debugPrint('Error adding channel member: $e');
      return false;
    }
  }

  Future<bool> _addStudyGroupMember({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    try {
      final memberData = {
        'study_group_id': groupId,
        'user_id': userId,
        'role': role,
        'joined_at': DateTime.now().toIso8601String(),
      };

      await _supabase.insertData(
        table: 'study_group_members',
        data: memberData,
      );

      return true;
    } catch (e) {
      debugPrint('Error adding study group member: $e');
      return false;
    }
  }

  Future<bool> _addWorkspaceMember({
    required String workspaceId,
    required String userId,
    required String role,
    required List<String> permissions,
  }) async {
    try {
      final memberData = {
        'workspace_id': workspaceId,
        'user_id': userId,
        'role': role,
        'permissions': permissions,
        'joined_at': DateTime.now().toIso8601String(),
      };

      await _supabase.insertData(
        table: 'workspace_members',
        data: memberData,
      );

      return true;
    } catch (e) {
      debugPrint('Error adding workspace member: $e');
      return false;
    }
  }

  Future<void> _updateChannelActivity(String channelId) async {
    try {
      await _supabase.updateData(
        table: 'chat_channels',
        data: {
          'updated_at': DateTime.now().toIso8601String(),
        },
        column: 'id',
        value: channelId,
      );
    } catch (e) {
      debugPrint('Error updating channel activity: $e');
    }
  }

  Future<void> _sendMessageNotification(
    String channelId,
    String messageId,
    String senderId,
  ) async {
    try {
      // Get channel members
      final members = await _supabase.fetchData(
        table: 'channel_members',
        filters: {'channel_id': channelId},
      );

      // Send notification to all members except sender
      for (final member in members) {
        final memberId = member['user_id'];
        if (memberId != senderId) {
          await _supabase.insertData(
            table: 'notifications',
            data: {
              'user_id': memberId,
              'type': 'new_message',
              'title': 'New message',
              'message': 'You have a new message',
              'data': {
                'channel_id': channelId,
                'message_id': messageId,
                'sender_id': senderId,
              },
              'created_at': DateTime.now().toIso8601String(),
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending message notification: $e');
    }
  }

  Future<void> _notifyStudySessionScheduled(
    String groupId,
    String sessionId,
  ) async {
    try {
      // Get group members
      final members = await _supabase.fetchData(
        table: 'study_group_members',
        filters: {'study_group_id': groupId},
      );

      // Send notification to all members
      for (final member in members) {
        final memberId = member['user_id'];
        await _supabase.insertData(
          table: 'notifications',
          data: {
            'user_id': memberId,
            'type': 'study_session_scheduled',
            'title': 'Study Session Scheduled',
            'message': 'A new study session has been scheduled',
            'data': {
              'group_id': groupId,
              'session_id': sessionId,
            },
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      debugPrint('Error notifying study session scheduled: $e');
    }
  }
}

/// Data models for messaging and collaboration

enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  code,
  link,
  poll,
  announcement,
}

enum StudyGroupType {
  collaborative,
  mentored,
  peer_learning,
  exam_prep,
  project_based,
}

enum WorkspaceType {
  document_sharing,
  code_collaboration,
  research_project,
  study_materials,
  assignment_group,
}

enum DocumentType {
  text,
  presentation,
  spreadsheet,
  code,
  image,
  video,
  pdf,
  other,
}

class MessageAttachment {
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final Map<String, dynamic> metadata;

  MessageAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'file_name': fileName,
        'file_url': fileUrl,
        'file_type': fileType,
        'file_size': fileSize,
        'metadata': metadata,
      };

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        fileName: json['file_name'] ?? '',
        fileUrl: json['file_url'] ?? '',
        fileType: json['file_type'] ?? '',
        fileSize: json['file_size'] ?? 0,
        metadata: json['metadata'] ?? {},
      );
}

class ChatMessage {
  final String id;
  final String channelId;
  final String senderId;
  final MessageType type;
  final String content;
  final String? replyToId;
  final List<MessageAttachment> attachments;
  final Map<String, dynamic> metadata;
  final bool isEdited;
  final bool isDeleted;
  final DateTime sentAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  ChatMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.type,
    required this.content,
    this.replyToId,
    this.attachments = const [],
    this.metadata = const {},
    this.isEdited = false,
    this.isDeleted = false,
    required this.sentAt,
    this.editedAt,
    this.deletedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'].toString(),
        channelId: json['channel_id'],
        senderId: json['sender_id'],
        type: MessageType.values.firstWhere(
          (t) => t.toString().split('.').last == json['message_type'],
          orElse: () => MessageType.text,
        ),
        content: json['content'] ?? '',
        replyToId: json['reply_to_id'],
        attachments: (json['attachments'] as List?)
                ?.map((a) => MessageAttachment.fromJson(a))
                .toList() ??
            [],
        metadata: json['metadata'] ?? {},
        isEdited: json['is_edited'] ?? false,
        isDeleted: json['is_deleted'] ?? false,
        sentAt: DateTime.parse(json['sent_at']),
        editedAt: json['edited_at'] != null
            ? DateTime.parse(json['edited_at'])
            : null,
        deletedAt: json['deleted_at'] != null
            ? DateTime.parse(json['deleted_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'channel_id': channelId,
        'sender_id': senderId,
        'message_type': type.toString().split('.').last,
        'content': content,
        'reply_to_id': replyToId,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'metadata': metadata,
        'is_edited': isEdited,
        'is_deleted': isDeleted,
        'sent_at': sentAt.toIso8601String(),
        'edited_at': editedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };
}

class ChatChannel {
  final String id;
  final String name;
  final String type;
  final String creatorId;
  final String description;
  final bool isPrivate;
  final int memberCount;
  final Map<String, dynamic> settings;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatChannel({
    required this.id,
    required this.name,
    required this.type,
    required this.creatorId,
    required this.description,
    required this.isPrivate,
    required this.memberCount,
    required this.settings,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) => ChatChannel(
        id: json['id'].toString(),
        name: json['name'] ?? '',
        type: json['type'] ?? '',
        creatorId: json['creator_id'] ?? '',
        description: json['description'] ?? '',
        isPrivate: json['is_private'] ?? false,
        memberCount: json['member_count'] ?? 0,
        settings: json['settings'] ?? {},
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'creator_id': creatorId,
        'description': description,
        'is_private': isPrivate,
        'member_count': memberCount,
        'settings': settings,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
