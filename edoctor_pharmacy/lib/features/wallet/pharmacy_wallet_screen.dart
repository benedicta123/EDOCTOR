import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pharmacy_shell.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/pharmacy_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/wallet_model.dart';

class PharmacyWalletScreen extends StatefulWidget {
  const PharmacyWalletScreen({super.key});

  @override
  State<PharmacyWalletScreen> createState() => _PharmacyWalletScreenState();
}

class _PharmacyWalletScreenState extends State<PharmacyWalletScreen> {
  UserModel? _user;
  PharmacyModel? _pharmacy;
  WalletModel? _wallet;
  List<WalletTransactionModel> _transactions = [];
  bool _loading = true;
  String _txFilter = 'toutes';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final pharmacy = await StorageService.getPharmacy();
      final wallet = await ApiService.getWallet();
      final transactions = await ApiService.getWalletTransactions();

      if (mounted) {
        setState(() {
          _user = user;
          _pharmacy = pharmacy;
          _wallet = wallet;
          _transactions = transactions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.outOfStock,
          ),
        );
      }
    }
  }

  List<WalletTransactionModel> get _filteredTransactions {
    if (_txFilter == 'credits') {
      return _transactions.where((t) => t.isCredit).toList();
    }
    if (_txFilter == 'debits') {
      return _transactions.where((t) => t.isDebit).toList();
    }
    return _transactions;
  }

  Future<void> _promptPayoutRequest() async {
    if (_wallet == null) return;
    if (_wallet!.balance < 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le solde disponible minimum pour effectuer un retrait est de 2 000 FCFA.'),
          backgroundColor: AppColors.orderPending,
        ),
      );
      return;
    }

    final amountController = TextEditingController(text: _wallet!.balance.toInt().toString());
    final accountController = TextEditingController(text: _wallet!.payoutAccount ?? '');
    final nameController = TextEditingController(text: _wallet!.payoutAccountName ?? (_user?.name ?? ''));
    final messenger = ScaffoldMessenger.of(context);
    String selectedMethod = _wallet!.payoutChannel ?? 't-money';
    bool submitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (subCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.inStockLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.send_to_mobile_rounded, color: AppColors.inStock, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Demande de virement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDim,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Solde retirable :', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            Text(
                              Formatters.currency(_wallet!.balance),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.inStock),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Montant
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Montant à retirer (FCFA)',
                          hintText: 'Ex: 50000',
                          suffixText: 'FCFA',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Opérateur de retrait
                      const Text('Moyen de réception :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _operatorRadioTile(
                              title: 'T-Money',
                              value: 't-money',
                              groupValue: selectedMethod,
                              onChanged: (v) => setDialogState(() => selectedMethod = v!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _operatorRadioTile(
                              title: 'Moov Flooz',
                              value: 'flooz',
                              groupValue: selectedMethod,
                              onChanged: (v) => setDialogState(() => selectedMethod = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _operatorRadioTile(
                        title: 'Virement bancaire national',
                        value: 'virement_bancaire',
                        groupValue: selectedMethod,
                        onChanged: (v) => setDialogState(() => selectedMethod = v!),
                      ),
                      const SizedBox(height: 16),

                      // Numéro de compte
                      TextField(
                        controller: accountController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: selectedMethod == 'virement_bancaire' ? 'IBAN ou Numéro de compte' : 'Numéro de téléphone Mobile Money',
                          hintText: selectedMethod == 'virement_bancaire' ? 'TG00...' : 'Ex: 90 12 34 56',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Nom du bénéficiaire
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nom complet du titulaire du compte',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: AppColors.outOfStock, fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.inStock),
                  onPressed: submitting
                      ? null
                      : () async {
                          final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                          final account = accountController.text.trim();
                          final name = nameController.text.trim();

                          if (amount < 2000) {
                            setDialogState(() => errorMessage = 'Le montant minimum est de 2 000 FCFA.');
                            return;
                          }
                          if (amount > _wallet!.balance) {
                            setDialogState(() => errorMessage = 'Solde insuffisant pour ce montant.');
                            return;
                          }
                          if (account.isEmpty) {
                            setDialogState(() => errorMessage = 'Le numéro de compte ou téléphone est obligatoire.');
                            return;
                          }

                          setDialogState(() {
                            submitting = true;
                            errorMessage = null;
                          });

                          try {
                            await ApiService.requestPayout(
                              amount: amount,
                              payoutMethod: selectedMethod,
                              accountNumber: account,
                              accountName: name.isNotEmpty ? name : null,
                            );

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Demande de retrait de ${Formatters.currency(amount)} enregistrée avec succès. Virement en cours.',
                                  ),
                                  backgroundColor: AppColors.inStock,
                                ),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              errorMessage = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirmer le retrait'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _promptUpdatePayoutAccount() async {
    if (_wallet == null) return;

    final accountController = TextEditingController(text: _wallet!.payoutAccount ?? '');
    final nameController = TextEditingController(text: _wallet!.payoutAccountName ?? (_user?.name ?? ''));
    final messenger = ScaffoldMessenger.of(context);
    String selectedMethod = _wallet!.payoutChannel ?? 't-money';
    bool submitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (subCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Coordonnées de versement par défaut', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedMethod,
                      decoration: InputDecoration(
                        labelText: 'Opérateur principal',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 't-money', child: Text('T-Money (Togocom)')),
                        DropdownMenuItem(value: 'flooz', child: Text('Moov Money (Flooz)')),
                        DropdownMenuItem(value: 'virement_bancaire', child: Text('Virement bancaire')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedMethod = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: accountController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de compte / Téléphone',
                        hintText: 'Ex: 90 12 34 56',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom du titulaire',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(errorMessage!, style: const TextStyle(color: AppColors.outOfStock, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final acc = accountController.text.trim();
                          final name = nameController.text.trim();
                          if (acc.isEmpty) {
                            setDialogState(() => errorMessage = 'Le numéro est requis');
                            return;
                          }
                          setDialogState(() => submitting = true);
                          try {
                            await ApiService.updatePayoutAccount(
                              payoutChannel: selectedMethod,
                              payoutAccount: acc,
                              payoutAccountName: name.isNotEmpty ? name : null,
                            );
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Coordonnées de versement mises à jour avec succès.'),
                                  backgroundColor: AppColors.inStock,
                                ),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              errorMessage = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _operatorRadioTile({
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PharmacyShell(
      currentSection: PharmacySection.wallet,
      title: 'Caisse & Versements',
      user: _user,
      pharmacy: _pharmacy,
      onRefresh: _loadData,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête Bento des Soldes
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 960 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: cols == 3 ? 1.8 : 2.2,
                        children: [
                          _buildBalanceCard(
                            title: 'Solde Disponible (Retirable)',
                            amount: _wallet?.balance ?? 0.0,
                            subtitle: 'Fonds immédiatement transférables vers votre compte Mobile Money',
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: AppColors.inStock,
                            iconBg: AppColors.inStockLight,
                            actionLabel: 'Retirer des fonds',
                            onAction: _promptPayoutRequest,
                          ),
                          _buildBalanceCard(
                            title: 'En attente (Sous séquestre)',
                            amount: _wallet?.pendingBalance ?? 0.0,
                            subtitle: 'Commandes en cours de préparation ou livraison',
                            icon: Icons.hourglass_top_rounded,
                            iconColor: AppColors.orderPending,
                            iconBg: AppColors.orderPendingLight,
                          ),
                          _buildBalanceCard(
                            title: 'Total Encaissé eDoctor',
                            amount: _wallet?.totalBalance ?? 0.0,
                            subtitle: 'Solde disponible + fonds en cours de libération',
                            icon: Icons.insights_rounded,
                            iconColor: AppColors.primary,
                            iconBg: AppColors.primaryContainer,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Carte Compte de versement par défaut
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Coordonnées de versement par défaut',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _wallet?.payoutAccount != null
                                      ? '${_wallet!.payoutChannelLabel} • ${_wallet!.payoutAccount!} (${_wallet!.payoutAccountName ?? _user?.name ?? ""})'
                                      : 'Aucun compte configuré. Cliquez sur configurer pour recevoir vos fonds plus rapidement.',
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            onPressed: _promptUpdatePayoutAccount,
                            label: Text(_wallet?.payoutAccount != null ? 'Modifier' : 'Configurer'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Historique des Transactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Historique des mouvements financiers',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          _txFilterChip('toutes', 'Toutes (${_transactions.length})'),
                          _txFilterChip('credits', 'Encaissements'),
                          _txFilterChip('debits', 'Retraits'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_filteredTransactions.isEmpty)
                    const EmptyStateView(
                      icon: Icons.receipt_long_outlined,
                      title: 'Aucune transaction enregistrée',
                      message: 'Les ventes de médicaments encaissées apparaîtront ici avec le détail des versements.',
                    )
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredTransactions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final tx = _filteredTransactions[idx];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: tx.isCredit ? AppColors.inStockLight : (tx.isDebit ? AppColors.outOfStockLight : AppColors.surfaceDim),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                tx.isCredit ? Icons.arrow_downward_rounded : (tx.isDebit ? Icons.arrow_upward_rounded : Icons.lock_outline_rounded),
                                color: tx.isCredit ? AppColors.inStock : (tx.isDebit ? AppColors.outOfStock : AppColors.textSecondary),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              tx.description,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            subtitle: Text(
                              '${Formatters.dateTime(tx.createdAt)} • ${tx.typeLabel}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${tx.isCredit ? "+" : (tx.isDebit ? "-" : "")}${Formatters.currency(tx.amount)}',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: tx.isCredit ? AppColors.inStock : (tx.isDebit ? AppColors.outOfStock : AppColors.textPrimary),
                                  ),
                                ),
                                Text(
                                  'Solde : ${Formatters.currency(tx.balanceAfter)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Formatters.currency(amount),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.inStock,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  onPressed: onAction,
                  label: Text(actionLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _txFilterChip(String key, String label) {
    final selected = _txFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12.5,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      onSelected: (_) => setState(() => _txFilter = key),
    );
  }
}
