import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_service.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  final client = Supabase.instance.client;
  return AdminService(client);
});

final mentorApplicationsStreamProvider = StreamProvider((ref) {
  return ref.read(adminServiceProvider).watchMentorApplications();
});

final callLogsStreamProvider = StreamProvider((ref) {
  return ref.read(adminServiceProvider).watchCallLogs();
});

final disputesStreamProvider = StreamProvider((ref) {
  return ref.read(adminServiceProvider).watchDisputes();
});

final activeBansStreamProvider = StreamProvider((ref) {
  return ref.read(adminServiceProvider).watchActiveBans();
});

final refundsStreamProvider = StreamProvider((ref) {
  return ref.read(adminServiceProvider).watchRefunds();
});
