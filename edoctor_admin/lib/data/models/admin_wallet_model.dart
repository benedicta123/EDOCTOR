class AdminWalletSummaryModel {
  final double totalAvailableBalance;
  final double totalEscrowPendingBalance;
  final double totalEcosystemBalance;
  final int walletsCount;

  const AdminWalletSummaryModel({
    required this.totalAvailableBalance,
    required this.totalEscrowPendingBalance,
    required this.totalEcosystemBalance,
    required this.walletsCount,
  });

  factory AdminWalletSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdminWalletSummaryModel(
      totalAvailableBalance: double.tryParse(json['total_available_balance']?.toString() ?? '0') ?? 0.0,
      totalEscrowPendingBalance: double.tryParse(json['total_escrow_pending_balance']?.toString() ?? '0') ?? 0.0,
      totalEcosystemBalance: double.tryParse(json['total_ecosystem_balance']?.toString() ?? '0') ?? 0.0,
      walletsCount: json['wallets_count'] as int? ?? 0,
    );
  }
}

class AdminWalletItemModel {
  final int id;
  final String holderType;
  final int holderId;
  final String holderName;
  final double balance;
  final double pendingBalance;
  final String currency;
  final String? payoutChannel;
  final String? payoutAccount;
  final String? payoutAccountName;
  final bool isActive;
  final String createdAt;

  const AdminWalletItemModel({
    required this.id,
    required this.holderType,
    required this.holderId,
    required this.holderName,
    required this.balance,
    required this.pendingBalance,
    required this.currency,
    this.payoutChannel,
    this.payoutAccount,
    this.payoutAccountName,
    required this.isActive,
    required this.createdAt,
  });

  double get totalBalance => balance + pendingBalance;

  String get holderTypeLabel {
    switch (holderType) {
      case 'Pharmacy':
        return 'Pharmacie';
      case 'Hospital':
        return 'Hôpital';
      case 'User':
        return 'Médecin Libéral';
      default:
        return holderType;
    }
  }

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

  factory AdminWalletItemModel.fromJson(Map<String, dynamic> json) {
    return AdminWalletItemModel(
      id: json['id'] as int? ?? 0,
      holderType: json['holder_type'] as String? ?? 'Partner',
      holderId: json['holder_id'] as int? ?? 0,
      holderName: json['holder_name'] as String? ?? 'Partenaire eDoctor',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      pendingBalance: double.tryParse(json['pending_balance']?.toString() ?? '0') ?? 0.0,
      currency: json['currency'] as String? ?? 'XOF',
      payoutChannel: json['payout_channel'] as String?,
      payoutAccount: json['payout_account'] as String?,
      payoutAccountName: json['payout_account_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class AdminPayoutRequestModel {
  final int id;
  final int walletId;
  final String partnerName;
  final String partnerType;
  final double amount;
  final double fee;
  final double netAmount;
  final String payoutMethod;
  final String accountNumber;
  final String? accountName;
  final String status;
  final String? transactionRef;
  final String? notes;
  final String? processedByName;
  final String? processedAt;
  final String createdAt;

  const AdminPayoutRequestModel({
    required this.id,
    required this.walletId,
    required this.partnerName,
    required this.partnerType,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.payoutMethod,
    required this.accountNumber,
    this.accountName,
    required this.status,
    this.transactionRef,
    this.notes,
    this.processedByName,
    this.processedAt,
    required this.createdAt,
  });

  bool get isPending => status == 'en_attente';
  bool get isProcessed => status == 'traite';
  bool get isRejected => status == 'rejete';

  String get statusLabel {
    switch (status) {
      case 'en_attente':
        return 'En attente de virement';
      case 'traite':
        return 'Virement validé & payé';
      case 'rejete':
        return 'Rejeté & remboursé';
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
        return 'Virement Bancaire (UEMOA)';
      default:
        return payoutMethod;
    }
  }

  factory AdminPayoutRequestModel.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] as Map<String, dynamic>? ?? {};
    final holder = wallet['holder'] as Map<String, dynamic>? ?? {};
    final processor = json['processor'] as Map<String, dynamic>?;

    return AdminPayoutRequestModel(
      id: json['id'] as int? ?? 0,
      walletId: json['wallet_id'] as int? ?? 0,
      partnerName: (holder['name'] as String?) ?? 'Partenaire eDoctor',
      partnerType: (wallet['holder_type'] != null) ? classBasename(wallet['holder_type'].toString()) : 'Partenaire',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      fee: double.tryParse(json['fee']?.toString() ?? '0') ?? 0.0,
      netAmount: double.tryParse(json['net_amount']?.toString() ?? '0') ?? 0.0,
      payoutMethod: json['payout_method'] as String? ?? 't-money',
      accountNumber: json['account_number'] as String? ?? '',
      accountName: json['account_name'] as String?,
      status: json['status'] as String? ?? 'en_attente',
      transactionRef: json['transaction_ref'] as String?,
      notes: json['notes'] as String?,
      processedByName: processor?['name'] as String?,
      processedAt: json['processed_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  static String classBasename(String full) {
    if (full.contains('\\')) {
      return full.split('\\').last;
    }
    return full;
  }
}
