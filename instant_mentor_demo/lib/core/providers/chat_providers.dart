import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

final chatServiceProvider =
    Provider<ChatService>((ref) => ChatService.instance);

final chatThreadsProvider = StreamProvider<List<ChatThread>>((ref) async* {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.user == null) {
    yield const [];
    return;
  }
  final userId = auth.user!.id;
  final svc = ref.watch(chatServiceProvider);
  yield* svc.watchThreads(userId);
});

final chatMessagesFamily =
    StreamProvider.family<List<ChatMessage>, String>((ref, chatId) async* {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    yield const [];
    return;
  }
  final svc = ref.watch(chatServiceProvider);
  yield* svc.watchMessages(chatId);
});
