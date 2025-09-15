import 'package:upi_india/upi_india.dart';

/// Result status simplified for app usage.
enum UpiResultStatus { success, submitted, failure, unknown }

/// App-level UPI result to avoid leaking package enums into UI code.
class UpiPaymentResult {
  final UpiResultStatus status;
  final String? transactionId;
  final Map<String, dynamic>? rawResponse;

  UpiPaymentResult(
      {required this.status, this.transactionId, this.rawResponse});
}

/// Simple UPI payment wrapper using `upi_india` package.
class UpiPaymentService {
  final UpiIndia _upi = UpiIndia();

  /// Returns list of installed UPI apps on the device.
  /// Each entry contains the package name and the friendly app enum.
  Future<List<UpiApp>?> getInstalledUpiApps() async {
    try {
      final apps = await _upi.getAllUpiApps();
      return apps;
    } catch (e) {
      return null;
    }
  }

  /// Helper to present available apps as a simple map of label->UpiApp.
  /// Caller can use this to build a selection UI.
  /// Returns list of app info maps: {'id': 'googlePay', 'name': 'googlePay'}
  /// This avoids leaking package types to UI code.
  Future<List<Map<String, String>>> getInstalledUpiAppInfos() async {
    final apps = await getInstalledUpiApps();
    if (apps == null) return [];
    return apps.map((a) {
      final id = a.toString().split('.').last; // e.g. googlePay
      return {'id': id, 'name': id};
    }).toList();
  }

  /// Initiate a UPI payment using Google Pay by default.
  /// Returns a simplified [UpiPaymentResult].
  Future<UpiPaymentResult?> payWithUpi({
    required double amount,
    String upiId = 'cp8137108@oksbi',
    String receiverName = 'InstantMentor',
    String? note,
    String? appId,
  }) async {
    try {
      final txnRef = DateTime.now().millisecondsSinceEpoch.toString();
      // Map appId (string) to actual UpiApp enum if possible.
      UpiApp? selectedApp;
      if (appId != null) {
        final all = await getInstalledUpiApps();
        if (all != null) {
          selectedApp = all.firstWhere(
            (a) => a.toString().split('.').last == appId,
            orElse: () => UpiApp.googlePay,
          );
        }
      }

      final response = await _upi.startTransaction(
        app: selectedApp ?? UpiApp.googlePay,
        receiverUpiId: upiId,
        receiverName: receiverName,
        transactionRefId: txnRef,
        transactionNote: note ?? 'Wallet top-up',
        amount: amount,
      );

      final status = () {
        try {
          switch (response.status) {
            case UpiPaymentStatus.SUCCESS:
              return UpiResultStatus.success;
            case UpiPaymentStatus.SUBMITTED:
              return UpiResultStatus.submitted;
            case UpiPaymentStatus.FAILURE:
              return UpiResultStatus.failure;
            default:
              return UpiResultStatus.unknown;
          }
        } catch (_) {
          return UpiResultStatus.unknown;
        }
      }();

      return UpiPaymentResult(
        status: status,
        transactionId: response.transactionId,
        rawResponse: {
          'status': response.status.toString(),
          'txnId': response.transactionId,
          // upi_india v3 exposes a different shape; include stringified
          // response as a fallback to avoid referencing removed fields.
          'raw': response.toString(),
        },
      );
    } catch (e) {
      return null;
    }
  }
}
