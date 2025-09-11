import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/upi_payment_service.dart';

// UPI Payment Service Provider
final upiPaymentServiceProvider = Provider<UpiPaymentService>((ref) {
  return UpiPaymentService();
});

// Available UPI Apps Provider
final availableUpiAppsProvider = FutureProvider<List<UpiApp>>((ref) async {
  final upiService = ref.read(upiPaymentServiceProvider);
  return await upiService.getAvailableUpiApps();
});
