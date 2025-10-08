/// Enhanced wallet and payment models based on the payments architecture document
/// Designed for Supabase backend with PostgreSQL storage

// =============================================================================
// ENUMS
// =============================================================================

enum PaymentGateway { stripe, razorpay }

enum PaymentMode { wallet, direct }

enum SessionStatus { booked, ongoing, completed, cancelled }

enum TransactionType {
  topup,
  reserve,
  release,
  capture,
  refund,
  payout,
  fee,
  mentorLock,
  mentorRelease
}

enum TransactionDirection { debit, credit }

enum AccountType {
  studentAvailable,
  studentLocked,
  mentorAvailable,
  mentorLocked,
  platformRevenue,
  externalGateway
}

enum PayoutStatus { created, pending, paid, failed }

enum KYCStatus { unverified, pending, verified }

// =============================================================================
// USER & KYC MODELS
// =============================================================================

class UserPaymentProfile {
  final String uid;
  final List<String> roles; // ["student", "mentor"]
  final KYCStatus kycStatus;
  final StripeInfo? stripe;
  final RazorpayInfo? razorpay;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPaymentProfile({
    required this.uid,
    required this.roles,
    required this.kycStatus,
    this.stripe,
    this.razorpay,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'roles': roles,
      'kycStatus': kycStatus.name,
      'stripe': stripe?.toMap(),
      'razorpay': razorpay?.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserPaymentProfile.fromMap(Map<String, dynamic> map) {
    return UserPaymentProfile(
      uid: map['uid'] ?? '',
      roles: List<String>.from(map['roles'] ?? []),
      kycStatus: KYCStatus.values.firstWhere(
        (e) => e.name == map['kycStatus'],
        orElse: () => KYCStatus.unverified,
      ),
      stripe: map['stripe'] != null ? StripeInfo.fromMap(map['stripe']) : null,
      razorpay: map['razorpay'] != null
          ? RazorpayInfo.fromMap(map['razorpay'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }
}

class StripeInfo {
  final String? accountId;
  final String? customerId;
  final bool connectEnabled;

  const StripeInfo({
    this.accountId,
    this.customerId,
    this.connectEnabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'customerId': customerId,
      'connectEnabled': connectEnabled,
    };
  }

  factory StripeInfo.fromMap(Map<String, dynamic> map) {
    return StripeInfo(
      accountId: map['accountId'],
      customerId: map['customerId'],
      connectEnabled: map['connectEnabled'] ?? false,
    );
  }
}

class RazorpayInfo {
  final String? contactId;
  final String? fundAccountId;

  const RazorpayInfo({
    this.contactId,
    this.fundAccountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'contactId': contactId,
      'fundAccountId': fundAccountId,
    };
  }

  factory RazorpayInfo.fromMap(Map<String, dynamic> map) {
    return RazorpayInfo(
      contactId: map['contactId'],
      fundAccountId: map['fundAccountId'],
    );
  }
}

// =============================================================================
// WALLET MODELS
// =============================================================================

class EnhancedWallet {
  final String uid;
  final String currency;
  final int balanceAvailable; // in minor units (cents/paise)
  final int balanceLocked;
  final DateTime updatedAt;

  const EnhancedWallet({
    required this.uid,
    required this.currency,
    required this.balanceAvailable,
    required this.balanceLocked,
    required this.updatedAt,
  });

  /// Get total balance in major units (dollars/rupees)
  double get totalBalanceMajor => (balanceAvailable + balanceLocked) / 100.0;

  /// Get available balance in major units
  double get availableBalanceMajor => balanceAvailable / 100.0;

  /// Get locked balance in major units
  double get lockedBalanceMajor => balanceLocked / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'currency': currency,
      'balance_available': balanceAvailable,
      'balance_locked': balanceLocked,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EnhancedWallet.fromMap(Map<String, dynamic> map, String uid) {
    return EnhancedWallet(
      uid: uid,
      currency: map['currency'] ?? 'USD',
      balanceAvailable: map['balance_available'] ?? 0,
      balanceLocked: map['balance_locked'] ?? 0,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  EnhancedWallet copyWith({
    String? currency,
    int? balanceAvailable,
    int? balanceLocked,
    DateTime? updatedAt,
  }) {
    return EnhancedWallet(
      uid: uid,
      currency: currency ?? this.currency,
      balanceAvailable: balanceAvailable ?? this.balanceAvailable,
      balanceLocked: balanceLocked ?? this.balanceLocked,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MentorEarnings {
  final String mentorUid;
  final String currency;
  final int earningsAvailable; // in minor units
  final int earningsLocked;
  final DateTime updatedAt;

  const MentorEarnings({
    required this.mentorUid,
    required this.currency,
    required this.earningsAvailable,
    required this.earningsLocked,
    required this.updatedAt,
  });

  /// Get total earnings in major units
  double get totalEarningsMajor => (earningsAvailable + earningsLocked) / 100.0;

  /// Get available earnings in major units
  double get availableEarningsMajor => earningsAvailable / 100.0;

  /// Get locked earnings in major units
  double get lockedEarningsMajor => earningsLocked / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'mentorUid': mentorUid,
      'currency': currency,
      'earnings_available': earningsAvailable,
      'earnings_locked': earningsLocked,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MentorEarnings.fromMap(Map<String, dynamic> map, String mentorUid) {
    return MentorEarnings(
      mentorUid: mentorUid,
      currency: map['currency'] ?? 'USD',
      earningsAvailable: map['earnings_available'] ?? 0,
      earningsLocked: map['earnings_locked'] ?? 0,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  MentorEarnings copyWith({
    String? currency,
    int? earningsAvailable,
    int? earningsLocked,
    DateTime? updatedAt,
  }) {
    return MentorEarnings(
      mentorUid: mentorUid,
      currency: currency ?? this.currency,
      earningsAvailable: earningsAvailable ?? this.earningsAvailable,
      earningsLocked: earningsLocked ?? this.earningsLocked,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// =============================================================================
// SESSION MODEL
// =============================================================================

class PaymentSession {
  final String sessionId;
  final String studentId;
  final String mentorId;
  final int price; // in minor units
  final String currency;
  final SessionStatus status;
  final PaymentMode paymentMode;
  final PaymentGateway? gateway;
  final GatewayRefs gatewayRefs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentSession({
    required this.sessionId,
    required this.studentId,
    required this.mentorId,
    required this.price,
    required this.currency,
    required this.status,
    required this.paymentMode,
    this.gateway,
    required this.gatewayRefs,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get price in major units
  double get priceMajor => price / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'studentId': studentId,
      'mentorId': mentorId,
      'price': price,
      'currency': currency,
      'status': status.name,
      'paymentMode': paymentMode.name,
      'gateway': gateway?.name,
      'gatewayRefs': gatewayRefs.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PaymentSession.fromMap(Map<String, dynamic> map) {
    return PaymentSession(
      sessionId: map['sessionId'] ?? '',
      studentId: map['studentId'] ?? '',
      mentorId: map['mentorId'] ?? '',
      price: map['price'] ?? 0,
      currency: map['currency'] ?? 'USD',
      status: SessionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SessionStatus.booked,
      ),
      paymentMode: PaymentMode.values.firstWhere(
        (e) => e.name == map['paymentMode'],
        orElse: () => PaymentMode.wallet,
      ),
      gateway: map['gateway'] != null
          ? PaymentGateway.values.firstWhere((e) => e.name == map['gateway'])
          : null,
      gatewayRefs: GatewayRefs.fromMap(map['gatewayRefs'] ?? {}),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }
}

class GatewayRefs {
  final String? paymentIntentId;
  final String? chargeId;
  final String? orderId;
  final String? authId;

  const GatewayRefs({
    this.paymentIntentId,
    this.chargeId,
    this.orderId,
    this.authId,
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentIntentId': paymentIntentId,
      'chargeId': chargeId,
      'orderId': orderId,
      'authId': authId,
    };
  }

  factory GatewayRefs.fromMap(Map<String, dynamic> map) {
    return GatewayRefs(
      paymentIntentId: map['paymentIntentId'],
      chargeId: map['chargeId'],
      orderId: map['orderId'],
      authId: map['authId'],
    );
  }
}

// =============================================================================
// TRANSACTION MODEL (Append-only Ledger)
// =============================================================================

class LedgerTransaction {
  final String txId;
  final TransactionType type;
  final TransactionDirection direction;
  final int amount; // in minor units
  final String currency;
  final AccountType fromAccount;
  final AccountType toAccount;
  final String? userId;
  final String? counterpartyUserId;
  final String? sessionId;
  final PaymentGateway? gateway;
  final String? gatewayId;
  final String idempotencyKey;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const LedgerTransaction({
    required this.txId,
    required this.type,
    required this.direction,
    required this.amount,
    required this.currency,
    required this.fromAccount,
    required this.toAccount,
    this.userId,
    this.counterpartyUserId,
    this.sessionId,
    this.gateway,
    this.gatewayId,
    required this.idempotencyKey,
    required this.createdAt,
    this.metadata,
  });

  /// Get amount in major units
  double get amountMajor => amount / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'txId': txId,
      'type': type.name,
      'direction': direction.name,
      'amount': amount,
      'currency': currency,
      'fromAccount': fromAccount.name,
      'toAccount': toAccount.name,
      'userId': userId,
      'counterpartyUserId': counterpartyUserId,
      'sessionId': sessionId,
      'gateway': gateway?.name,
      'gatewayId': gatewayId,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory LedgerTransaction.fromMap(Map<String, dynamic> map) {
    return LedgerTransaction(
      txId: map['txId'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.topup,
      ),
      direction: TransactionDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => TransactionDirection.credit,
      ),
      amount: map['amount'] ?? 0,
      currency: map['currency'] ?? 'USD',
      fromAccount: AccountType.values.firstWhere(
        (e) => e.name == map['fromAccount'],
        orElse: () => AccountType.externalGateway,
      ),
      toAccount: AccountType.values.firstWhere(
        (e) => e.name == map['toAccount'],
        orElse: () => AccountType.studentAvailable,
      ),
      userId: map['userId'],
      counterpartyUserId: map['counterpartyUserId'],
      sessionId: map['sessionId'],
      gateway: map['gateway'] != null
          ? PaymentGateway.values.firstWhere((e) => e.name == map['gateway'])
          : null,
      gatewayId: map['gatewayId'],
      idempotencyKey: map['idempotencyKey'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      metadata: map['metadata'],
    );
  }
}

// =============================================================================
// PAYOUT MODEL
// =============================================================================

class PayoutRequest {
  final String payoutId;
  final String mentorId;
  final int amount; // in minor units
  final String currency;
  final PayoutStatus status;
  final PaymentGateway gateway;
  final String? gatewayPayoutId;
  final String? failureCode;
  final String? failureMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PayoutRequest({
    required this.payoutId,
    required this.mentorId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.gateway,
    this.gatewayPayoutId,
    this.failureCode,
    this.failureMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get amount in major units
  double get amountMajor => amount / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'payoutId': payoutId,
      'mentorId': mentorId,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'gateway': gateway.name,
      'gatewayPayoutId': gatewayPayoutId,
      'failureCode': failureCode,
      'failureMessage': failureMessage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PayoutRequest.fromMap(Map<String, dynamic> map) {
    return PayoutRequest(
      payoutId: map['payoutId'] ?? '',
      mentorId: map['mentorId'] ?? '',
      amount: map['amount'] ?? 0,
      currency: map['currency'] ?? 'USD',
      status: PayoutStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PayoutStatus.created,
      ),
      gateway: PaymentGateway.values.firstWhere(
        (e) => e.name == map['gateway'],
        orElse: () => PaymentGateway.stripe,
      ),
      gatewayPayoutId: map['gatewayPayoutId'],
      failureCode: map['failureCode'],
      failureMessage: map['failureMessage'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  PayoutRequest copyWith({
    PayoutStatus? status,
    String? gatewayPayoutId,
    String? failureCode,
    String? failureMessage,
    DateTime? updatedAt,
  }) {
    return PayoutRequest(
      payoutId: payoutId,
      mentorId: mentorId,
      amount: amount,
      currency: currency,
      status: status ?? this.status,
      gateway: gateway,
      gatewayPayoutId: gatewayPayoutId ?? this.gatewayPayoutId,
      failureCode: failureCode ?? this.failureCode,
      failureMessage: failureMessage ?? this.failureMessage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// =============================================================================
// HELPER UTILITIES
// =============================================================================

class CurrencyUtils {
  /// Convert major units to minor units (e.g., $1.50 -> 150 cents)
  static int toMinorUnits(double majorAmount, {String currency = 'USD'}) {
    return (majorAmount * 100).round();
  }

  /// Convert minor units to major units (e.g., 150 cents -> $1.50)
  static double toMajorUnits(int minorAmount, {String currency = 'USD'}) {
    return minorAmount / 100.0;
  }

  /// Format amount in major units with currency symbol
  static String formatAmount(int minorAmount, {String currency = 'USD'}) {
    final major = toMajorUnits(minorAmount);
    switch (currency) {
      case 'INR':
        return '₹${major.toStringAsFixed(2)}';
      case 'USD':
        return '\$${major.toStringAsFixed(2)}';
      default:
        return '${major.toStringAsFixed(2)} $currency';
    }
  }
}
