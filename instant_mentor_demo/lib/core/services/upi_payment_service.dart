import 'dart:async';

/// Lightweight model representing an installed UPI application.
class UpiApp {
  final String name;
  final String packageId;

  const UpiApp({required this.name, required this.packageId});
}

/// Service that discovers available UPI apps and initiates payments.
///
/// This is a minimal placeholder implementation that returns a mocked list
/// so the demo can compile and render. Replace with real discovery logic
/// (e.g., using platform channels or existing plugins) for production use.
class UpiPaymentService {
  Future<List<UpiApp>> getAvailableUpiApps() async {
    // Simulate IO delay
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Mocked apps (adjust names to match demo color mapping)
    return const [
      UpiApp(
          name: 'Google Pay',
          packageId: 'com.google.android.apps.nbu.paisa.user'),
      UpiApp(name: 'PhonePe', packageId: 'com.phonepe.app'),
      UpiApp(name: 'Paytm', packageId: 'net.one97.paytm'),
      UpiApp(name: 'BHIM', packageId: 'in.org.npci.upiapp'),
    ];
  }

  // Placeholder for initiating a UPI payment
  Future<bool> initiatePayment({
    required String upiId,
    required int amountPaise,
    required String note,
    UpiApp? preferredApp,
  }) async {
    // In a real implementation, construct a UPI URI and invoke via intent/deep link.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return true; // Assume success in demo
  }
}
