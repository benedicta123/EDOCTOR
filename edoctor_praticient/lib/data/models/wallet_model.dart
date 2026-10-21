class WalletTransactionModel {
  final int id;
  final String type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? sourceType;
  final int? sourceId;
  final String description;
  final String createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.sourceType,
    this.sourceId,
    required this.description,
    required this.createdAt,
  });

  bool get isCredit => type == 'credit' || type == 'release';
  bool get isDebit => type == 'debit';
  bool get isHold => type == 'hold';

  String get typeLabel {
    switch (type) {
      case 'credit':
        return 'Honoraires versés';
      case 'hold':
        return 'Séquestre consultation';
      case 'release':
        return 'Honoraires libérés';
      case 'debit':
        return 'Retrait Mobile Money';
      case 'refund':
        return 'Restitution solde';
      case 'cancel_hold':
        return 'Annulation séquestre';
      default:
        return type;
    }
  }

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? 'credit',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      balanceBefore: double.tryParse(json['balance_before']?.toString() ?? '0') ?? 0.0,
      balanceAfter: double.tryParse(json['balance_after']?.toString() ?? '0') ?? 0.0,
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id'] as int?,
      description: json['description'] as String? ?? 'Mouvement de fonds',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class PayoutRequestModel {
  final int id;
  final double amount;
  final double fee;
  final double netAmount;
  final String payoutMethod;
  final String accountNumber;
  final String? accountName;
  final String status;
  final String? transactionRef;
  final String? notes;
  final String createdAt;

  const PayoutRequestModel({
    required this.id,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.payoutMethod,
    required this.accountNumber,
    this.accountName,
    required this.status,
    this.transactionRef,
    this.notes,
    required this.createdAt,
  });

  bool get isPending => status == 'en_attente';
  bool get isProcessed => status == 'traite';
  bool get isRejected => status == 'rejete';

  String get statusLabel {
    switch (status) {
      case 'en_attente':
        return 'En cours d\'instruction';
      case 'traite':
        return 'Virement exécuté';
      case 'rejete':
        return 'Rejeté';
      default:
        return status;
    }
  }

  String get methodLabel {
    switch (payoutMethod) {
      case 't-money':
        return 'T-Money (Togocom)';
      case 'flooz':
        return 'Moov Money (Flooz)';
      case 'virement_bancaire':
        return 'Virement Bancaire';
      default:
        return payoutMethod;
    }
  }

  factory PayoutRequestModel.fromJson(Map<String, dynamic> json) {
    return PayoutRequestModel(
      id: json['id'] as int? ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      fee: double.tryParse(json['fee']?.toString() ?? '0') ?? 0.0,
      netAmount: double.tryParse(json['net_amount']?.toString() ?? '0') ?? 0.0,
      payoutMethod: json['payout_method'] as String? ?? 't-money',
      accountNumber: json['account_number'] as String? ?? '',
      accountName: json['account_name'] as String?,
      status: json['status'] as String? ?? 'en_attente',
      transactionRef: json['transaction_ref'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class WalletModel {
  final int id;
  final String holderType;
  final int holderId;
  final double balance;
  final double pendingBalance;
  final double totalBalance;
  final String currency;
  final String? payoutChannel;
  final String? payoutAccount;
  final String? payoutAccountName;
  final bool isActive;
  final int personalDoctorConsultations;
  final double personalDoctorRevenue;
  final List<WalletTransactionModel> recentTransactions;

  const WalletModel({
    required this.id,
    required this.holderType,
    required this.holderId,
    required this.balance,
    required this.pendingBalance,
    required this.totalBalance,
    required this.currency,
    this.payoutChannel,
    this.payoutAccount,
    this.payoutAccountName,
    required this.isActive,
    this.personalDoctorConsultations = 0,
    this.personalDoctorRevenue = 0.0,
    this.recentTransactions = const [],
  });

  String get payoutChannelLabel {
    switch (payoutChannel) {
      case 't-money':
        return 'T-Money (Togocom)';
      case 'flooz':
        return 'Moov Money (Flooz)';
      case 'virement_bancaire':
        return 'Virement Bancaire';
      default:
        return payoutChannel ?? 'Non configuré';
    }
  }

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    final w = json['wallet'] as Map<String, dynamic>? ?? json;
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    final txList = (json['recent_transactions'] as List?) ?? [];

    return WalletModel(
      id: w['id'] as int? ?? 0,
      holderType: w['holder_type'] as String? ?? 'User',
      holderId: w['holder_id'] as int? ?? 0,
      balance: double.tryParse(w['balance']?.toString() ?? '0') ?? 0.0,
      pendingBalance: double.tryParse(w['pending_balance']?.toString() ?? '0') ?? 0.0,
      totalBalance: double.tryParse(w['total_balance']?.toString() ?? '0') ?? 0.0,
      currency: w['currency'] as String? ?? 'XOF',
      payoutChannel: w['payout_channel'] as String?,
      payoutAccount: w['payout_account'] as String?,
      payoutAccountName: w['payout_account_name'] as String?,
      isActive: w['is_active'] as bool? ?? true,
      personalDoctorConsultations: stats['personal_doctor_consultations'] as int? ?? 0,
      personalDoctorRevenue: double.tryParse(stats['personal_doctor_revenue']?.toString() ?? '0') ?? 0.0,
      recentTransactions: txList
          .map((t) => WalletTransactionModel.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}
