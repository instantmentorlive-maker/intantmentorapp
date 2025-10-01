import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/feature_flags.dart';
import '../providers/auth_provider.dart';
import '../services/websocket_service.dart';

/// WebSocket Manager handles the lifecycle and integration with auth
class WebSocketManager {
  static WebSocketManager? _instance;
  static WebSocketManager get instance => _instance ??= WebSocketManager._();

  WebSocketManager._();

  final WebSocketService _webSocketService = WebSocketService.instance;
  bool _isInitialized = false;

  /// Initialize WebSocket connection when user is authenticated
  Future<void> initializeConnection({
    required String userId,
    required String userRole,
    String? serverUrl,
  }) async {
    if (_isInitialized && _webSocketService.isConnected) {
      debugPrint('🌐 WebSocketManager: Already connected');
      return;
    }

    try {
      debugPrint(
          '🌐 WebSocketManager: Initializing connection for user: $userId');

      await _webSocketService.connect(
        userId: userId,
        userRole: userRole,
        serverUrl: serverUrl,
      );

      _isInitialized = true;
      debugPrint('✅ WebSocketManager: Connection initialized successfully');
    } catch (e) {
      debugPrint('🔴 WebSocketManager: Failed to initialize connection: $e');
      rethrow;
    }
  }

  /// Disconnect WebSocket when user logs out
  Future<void> disconnectConnection() async {
    debugPrint('🌐 WebSocketManager: Disconnecting...');

    await _webSocketService.disconnect();
    _isInitialized = false;

    debugPrint('✅ WebSocketManager: Disconnected successfully');
  }

  /// Get WebSocket service instance
  WebSocketService get webSocketService => _webSocketService;

  /// Check if WebSocket is connected
  bool get isConnected => _webSocketService.isConnected;

  /// Get connection state
  WebSocketConnectionState get connectionState =>
      _webSocketService.connectionState;

  /// Send chat message
  Future<void> sendChatMessage({
    required String receiverId,
    required String content,
    String? messageType,
    Map<String, dynamic>? metadata,
  }) async {
    await _webSocketService.sendChatMessage(
      receiverId: receiverId,
      content: content,
      messageType: messageType,
      metadata: metadata,
    );
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator({
    required String receiverId,
    required bool isTyping,
  }) async {
    await _webSocketService.sendTypingIndicator(
      receiverId: receiverId,
      isTyping: isTyping,
    );
  }

  /// Initiate video call
  Future<void> initiateVideoCall({
    required String receiverId,
    Map<String, dynamic>? callData,
  }) async {
    await _webSocketService.initiateCall(
      receiverId: receiverId,
      callType: 'video',
      callData: callData,
    );
  }

  /// Initiate audio call
  Future<void> initiateAudioCall({
    required String receiverId,
    Map<String, dynamic>? callData,
  }) async {
    await _webSocketService.initiateCall(
      receiverId: receiverId,
      callType: 'audio',
      callData: callData,
    );
  }

  /// Join session
  Future<void> joinSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
  }) async {
    await _webSocketService.joinSession(
      sessionId: sessionId,
      sessionData: sessionData,
    );
  }

  /// Handle specific message types
  void handleIncomingMessage(WebSocketMessage message) {
    switch (message.event) {
      case WebSocketEvent.messageReceived:
        _handleChatMessage(message);
        break;
      case WebSocketEvent.callInitiated:
        _handleIncomingCall(message);
        break;
      case WebSocketEvent.callAccepted:
        _handleCallAccepted(message);
        break;
      case WebSocketEvent.callRejected:
        _handleCallRejected(message);
        break;
      case WebSocketEvent.callEnded:
        _handleCallEnded(message);
        break;
      case WebSocketEvent.sessionStarted:
        _handleSessionStarted(message);
        break;
      case WebSocketEvent.userTyping:
        _handleUserTyping(message);
        break;
      case WebSocketEvent.notificationReceived:
        _handleNotification(message);
        break;
      default:
        debugPrint(
            '🔔 WebSocketManager: Unhandled message type: ${message.event.name}');
    }
  }

  void _handleChatMessage(WebSocketMessage message) {
    debugPrint(
        '💬 WebSocketManager: New chat message from ${message.senderId}');
    // Handle chat message - could trigger local notifications, update chat UI, etc.
  }

  void _handleIncomingCall(WebSocketMessage message) {
    debugPrint('📞 WebSocketManager: Incoming call from ${message.senderId}');
    // Handle incoming call - show call UI, ring notification, etc.
  }

  void _handleCallAccepted(WebSocketMessage message) {
    debugPrint('✅ WebSocketManager: Call accepted by ${message.senderId}');
    // Handle call accepted - navigate to call screen, start video/audio
  }

  void _handleCallRejected(WebSocketMessage message) {
    debugPrint('❌ WebSocketManager: Call rejected by ${message.senderId}');
    // Handle call rejected - show rejection message, cleanup call state
  }

  void _handleCallEnded(WebSocketMessage message) {
    debugPrint('📞 WebSocketManager: Call ended by ${message.senderId}');
    // Handle call ended - cleanup call state, navigate back to previous screen
  }

  void _handleSessionStarted(WebSocketMessage message) {
    debugPrint(
        '🎓 WebSocketManager: Session started: ${message.data['sessionId']}');
    // Handle session started - navigate to session screen, prepare session UI
  }

  void _handleUserTyping(WebSocketMessage message) {
    debugPrint('⌨️ WebSocketManager: User typing: ${message.senderId}');
    // Handle typing indicator - show/hide typing indicator in chat
  }

  void _handleNotification(WebSocketMessage message) {
    debugPrint(
        '🔔 WebSocketManager: System notification: ${message.data['title']}');
    // Handle system notification - show local notification, update UI
  }
}

/// WebSocket manager provider
final webSocketManagerProvider = Provider<WebSocketManager>((ref) {
  return WebSocketManager.instance;
});

/// Provider to automatically manage WebSocket connection based on auth state
final webSocketConnectionManagerProvider = Provider<void>((ref) {
  final webSocketManager = ref.watch(webSocketManagerProvider);

  // Listen to auth state changes with delay to prevent race conditions
  ref.listen(authProvider, (previous, next) async {
    // Add a small delay to prevent race conditions during initialization
    await Future.delayed(const Duration(milliseconds: 500));

    // Debug auth state transitions
    debugPrint(
        '🌐 WebSocket: Auth state changed - Previous: ${previous?.isAuthenticated}, Next: ${next.isAuthenticated}');

    if (next.isAuthenticated && next.user != null) {
      // Only connect if we weren't already authenticated
      if (previous?.isAuthenticated != true) {
        // Respect feature flags before attempting connection
        if (!FeatureFlags.realtimeEnabled) {
          debugPrint('🌐 WebSocket: Realtime disabled (skipping auto-connect)');
          return;
        }
        // Allow WebSocket in demo mode for help requests and other features
        // Only skip if explicitly configured to do so
        debugPrint(
            '🌐 WebSocket: Proceeding with connection (demo mode allowed)');
        try {
          final userId = next.user!.id;
          final userRole = next.user!.userMetadata?['role'] ?? 'student';

          await webSocketManager.initializeConnection(
            userId: userId,
            userRole: userRole,
          );

          if (webSocketManager.isConnected) {
            debugPrint('🌐 WebSocket: Auto-connected for user $userId');
          } else {
            debugPrint(
                '🌐 WebSocket: Auto-connect attempted but not connected');
          }
        } catch (e) {
          debugPrint('🔴 WebSocket: Auto-connection failed: $e');
        }
      }
    } else if (!next.isAuthenticated && previous?.isAuthenticated == true) {
      // Only disconnect if we were previously authenticated (explicit logout)
      await webSocketManager.disconnectConnection();
      debugPrint('🌐 WebSocket: Auto-disconnected on logout');
    }
  });

  return;
});

/// Provider for WebSocket messages with filtering
final filteredWebSocketMessageProvider =
    StreamProvider.family<List<WebSocketMessage>, WebSocketEvent>(
        (ref, eventType) {
  final webSocketService = ref.watch(webSocketServiceProvider);

  return webSocketService.messageStream
      .where((message) => message.event == eventType)
      .map((message) => [message])
      .asyncExpand((messageList) => Stream.value(messageList));
});

/// Provider for chat messages
final chatMessagesProvider =
    StreamProvider.family<WebSocketMessage, String>((ref, userId) {
  final webSocketService = ref.watch(webSocketServiceProvider);

  return webSocketService.messageStream.where((message) =>
      (message.event == WebSocketEvent.messageReceived ||
          message.event == WebSocketEvent.messageSent) &&
      (message.senderId == userId || message.receiverId == userId));
});

/// Provider for call events
final callEventsProvider = StreamProvider<WebSocketMessage>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);

  return webSocketService.messageStream.where((message) =>
      message.event == WebSocketEvent.callInitiated ||
      message.event == WebSocketEvent.callAccepted ||
      message.event == WebSocketEvent.callRejected ||
      message.event == WebSocketEvent.callEnded ||
      message.event == WebSocketEvent.callRinging);
});

/// Provider for user presence
final userPresenceProvider = StreamProvider<Map<String, bool>>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  final presenceMap = <String, bool>{};

  return webSocketService.messageStream
      .where((message) =>
          message.event == WebSocketEvent.userOnline ||
          message.event == WebSocketEvent.userOffline)
      .map((message) {
    final userId = message.data['userId'] as String?;
    if (userId != null) {
      presenceMap[userId] = message.event == WebSocketEvent.userOnline;
    }
    return Map<String, bool>.from(presenceMap);
  });
});

/// Provider for typing indicators
final typingIndicatorProvider =
    StreamProvider.family<bool, String>((ref, userId) {
  final webSocketService = ref.watch(webSocketServiceProvider);

  return webSocketService.messageStream
      .where((message) =>
          (message.event == WebSocketEvent.userTyping ||
              message.event == WebSocketEvent.userStoppedTyping) &&
          message.senderId == userId)
      .map((message) => message.event == WebSocketEvent.userTyping);
});
