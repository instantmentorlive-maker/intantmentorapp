enum TransactionType { 
  credit, 
  debit, 
  sessionPayment, 
  sessionEarning, 
  withdrawal, 
  refund,
  bonus,
  penalty
}

class Transaction {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String description;
  final String? sessionId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    this.sessionId,
    required this.timestamp,
    this.metadata,
  });

  bool get isCredit => [
    TransactionType.credit,
    TransactionType.sessionEarning,
    TransactionType.refund,
    TransactionType.bonus,
  ].contains(type);

  bool get isDebit => !isCredit;
}

class Wallet {
  final String userId;
  final double balance;
  final double pendingAmount;
  final List<Transaction> recentTransactions;
  final DateTime lastUpdated;

  const Wallet({
    required this.userId,
    required this.balance,
    this.pendingAmount = 0.0,
    this.recentTransactions = const [],
    required this.lastUpdated,
  });

  Wallet copyWith({
    String? userId,
    double? balance,
    double? pendingAmount,
    List<Transaction>? recentTransactions,
    DateTime? lastUpdated,
  }) {
    return Wallet(
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  double get totalBalance => balance + pendingAmount;
}

class EarningsReport {
  final String mentorId;
  final double todayEarnings;
  final double weekEarnings;
  final double monthEarnings;
  final double totalEarnings;
  final int totalSessions;
  final double averageSessionValue;
  final Map<String, double> subjectEarnings;
  final DateTime generatedAt;

  const EarningsReport({
    required this.mentorId,
    required this.todayEarnings,
    required this.weekEarnings,
    required this.monthEarnings,
    required this.totalEarnings,
    required this.totalSessions,
    required this.averageSessionValue,
    this.subjectEarnings = const {},
    required this.generatedAt,
  });
}

class LeaderboardEntry {
  final String userId;
  final String userName;
  final dynamic userRole; // Use domain UserRole; kept dynamic to avoid circular import
  final double score;
  final int rank;
  final String metric; // e.g., "sessions_completed", "earnings", "rating"
  final Map<String, dynamic> additionalData;

  const LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.score,
    required this.rank,
    required this.metric,
    this.additionalData = const {},
  });
}
