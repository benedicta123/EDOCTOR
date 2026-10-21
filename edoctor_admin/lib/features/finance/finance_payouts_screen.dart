import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/badge_chip.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/kpi_card.dart';
import '../../data/models/admin_wallet_model.dart';

class FinancePayoutsScreen extends StatefulWidget {
  const FinancePayoutsScreen({super.key});

  @override
  State<FinancePayoutsScreen> createState() => _FinancePayoutsScreenState();
}

class _FinancePayoutsScreenState extends State<FinancePayoutsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AdminWalletSummaryModel? _summary;
  List<AdminWalletItemModel> _wallets = [];
  List<AdminPayoutRequestModel> _payouts = [];
  bool _loading = true;
  String _payoutStatusFilter = 'tous';
  String _walletSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final walletsData = await ApiService.getWalletsData();
      final payoutsData = await ApiService.getPayoutRequests();

      if (mounted) {
        setState(() {
          _summary = walletsData['summary'] as AdminWalletSummaryModel?;
          _wallets = (walletsData['wallets'] as List<AdminWalletItemModel>?) ?? [];
          _payouts = payoutsData;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.rejected,
          ),
        );
      }
    }
  }

  List<AdminPayoutRequestModel> get _filteredPayouts {
    if (_payoutStatusFilter == 'tous') return _payouts;
    return _payouts.where((p) => p.status == _payoutStatusFilter).toList();
  }

  List<AdminWalletItemModel> get _filteredWallets {
    if (_walletSearch.trim().isEmpty) return _wallets;
    final q = _walletSearch.trim().toLowerCase();
    return _wallets.where((w) {
      return w.holderName.toLowerCase().contains(q) ||
          w.holderTypeLabel.toLowerCase().contains(q) ||
          (w.payoutAccount ?? '').contains(q);
    }).toList();
  }

  Future<void> _promptApprovePayout(AdminPayoutRequestModel payout) async {
    final refController = TextEditingController(text: 'PAYOUT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final notesController = TextEditingController();
    bool submitting = false;
    String? errorMessage;
    final messenger = ScaffoldMessenger.of(context);

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
                      color: AppColors.verified.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.verified, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Approuver le décaissement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDim,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bénéficiaire :', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(
                                '${payout.partnerName} (${payout.partnerType})',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Moyen de transfert :', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(
                                '${payout.methodLabel} • ${payout.accountNumber}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Montant net à verser :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              Text(
                                Formatters.formatCurrency(payout.amount),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.verified),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(
                        labelText: 'Référence de transaction opérateur (T-Money / Flooz / Banque)',
                        hintText: 'Ex: TMONEY-19482049',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes administratives (optionnel)',
                        hintText: 'Ex: Virement exécuté par la trésorerie',
                      ),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(errorMessage!, style: const TextStyle(color: AppColors.rejected, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verified,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() {
                            submitting = true;
                            errorMessage = null;
                          });

                          try {
                            await ApiService.approvePayout(
                              payout.id,
                              transactionRef: refController.text.trim(),
                              notes: notesController.text.trim(),
                            );

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Le reversement de ${Formatters.formatCurrency(payout.amount)} pour ${payout.partnerName} a été validé avec succès.',
                                  ),
                                  backgroundColor: AppColors.verified,
                                ),
                              );
                              _load();
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
                      : const Text('Confirmer & Marquer Exécuté'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _promptRejectPayout(AdminPayoutRequestModel payout) async {
    final reasonController = TextEditingController();
    bool submitting = false;
    String? errorMessage;
    final messenger = ScaffoldMessenger.of(context);

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
                      color: AppColors.rejected.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cancel_outlined, color: AppColors.rejected, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Rejeter la demande de retrait', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attention : Le montant de ${Formatters.formatCurrency(payout.amount)} sera immédiatement recrédité sur le portefeuille de ${payout.partnerName}.',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Motif du rejet (obligatoire)',
                        hintText: 'Ex: Numéro Mobile Money erroné, compte non actif, etc.',
                      ),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(errorMessage!, style: const TextStyle(color: AppColors.rejected, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rejected,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            setDialogState(() => errorMessage = 'Le motif du rejet est obligatoire.');
                            return;
                          }

                          setDialogState(() {
                            submitting = true;
                            errorMessage = null;
                          });

                          try {
                            await ApiService.rejectPayout(payout.id, reason: reason);

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Demande rejetée. Les fonds de ${Formatters.formatCurrency(payout.amount)} ont été restitués au partenaire.',
                                  ),
                                  backgroundColor: AppColors.rejected,
                                ),
                              );
                              _load();
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
                      : const Text('Rejeter & Recréditer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingPayouts = _payouts.where((p) => p.isPending).length;

    return AdminShell(
      currentSection: AdminSection.finance,
      title: 'Trésorerie, Portefeuilles & Reversements',
      subtitle: 'Supervision des liquidités écosystème, validation des décaissements Mobile Money & Banque',
      onRefresh: _load,
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          onPressed: _load,
        ),
      ],
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Cards de la Trésorerie Globale
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 1100 ? 4 : (constraints.maxWidth >= 650 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: cols == 4 ? 1.7 : 2.2,
                        children: [
                          KpiCard(
                            title: 'Solde Disponible Partenaires',
                            value: Formatters.formatCurrency(_summary?.totalAvailableBalance ?? 0.0),
                            subtitle: 'Fonds retirables par les prestataires',
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: AppColors.verified,
                            iconBgColor: AppColors.verifiedBg,
                          ),
                          KpiCard(
                            title: 'Escrow / Séquestre Global',
                            value: Formatters.formatCurrency(_summary?.totalEscrowPendingBalance ?? 0.0),
                            subtitle: 'En attente de clôture ou livraison',
                            icon: Icons.hourglass_top_rounded,
                            iconColor: AppColors.pending,
                            iconBgColor: AppColors.pendingBg,
                          ),
                          KpiCard(
                            title: 'Total Liquidités Réseau',
                            value: Formatters.formatCurrency(_summary?.totalEcosystemBalance ?? 0.0),
                            subtitle: 'Disponible + séquestre consolidé',
                            icon: Icons.pie_chart_rounded,
                            iconColor: AppColors.primary,
                            iconBgColor: AppColors.primaryContainer,
                          ),
                          KpiCard(
                            title: 'Portefeuilles Partenaires',
                            value: '${_summary?.walletsCount ?? _wallets.length}',
                            subtitle: '$pendingPayouts demande(s) de retrait en attente',
                            icon: Icons.hub_rounded,
                            iconColor: pendingPayouts > 0 ? AppColors.pending : AppColors.secondary,
                            iconBgColor: pendingPayouts > 0 ? AppColors.pendingBg : AppColors.secondaryContainer,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Barre d'onglets : Demandes de reversement vs Portefeuilles
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_to_mobile_rounded, size: 18),
                              const SizedBox(width: 8),
                              const Text('Demandes de Reversement', style: TextStyle(fontWeight: FontWeight.w700)),
                              if (pendingPayouts > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.pending,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$pendingPayouts',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text('Portefeuilles Actifs (${_wallets.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Contenu des onglets
                  SizedBox(
                    height: 600,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPayoutsTab(),
                        _buildWalletsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPayoutsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filtres de statut
        Wrap(
          spacing: 8,
          children: [
            _payoutFilterChip('tous', 'Toutes (${_payouts.length})'),
            _payoutFilterChip('en_attente', 'En attente (${_payouts.where((p) => p.isPending).length})'),
            _payoutFilterChip('traite', 'Payées (${_payouts.where((p) => p.isProcessed).length})'),
            _payoutFilterChip('rejete', 'Rejetées (${_payouts.where((p) => p.isRejected).length})'),
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _filteredPayouts.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Aucune demande de reversement',
                  message: 'Aucune demande ne correspond à ce filtre actuellement.',
                )
              : Card(
                  child: ListView.separated(
                    itemCount: _filteredPayouts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final p = _filteredPayouts[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: p.isPending
                                    ? AppColors.pendingBg
                                    : (p.isProcessed ? AppColors.verifiedBg : AppColors.rejectedBg),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                p.isPending
                                    ? Icons.hourglass_top_rounded
                                    : (p.isProcessed ? Icons.check_circle_rounded : Icons.cancel_rounded),
                                color: p.isPending
                                    ? AppColors.pending
                                    : (p.isProcessed ? AppColors.verified : AppColors.rejected),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        p.partnerName,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceDim,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Text(
                                          p.partnerType,
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${p.methodLabel} • Compte : ${p.accountNumber}${p.accountName != null ? " (${p.accountName})" : ""} • Date : ${Formatters.formatDate(DateTime.tryParse(p.createdAt))}',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                  ),
                                  if (p.transactionRef != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Réf virement : ${p.transactionRef}${p.processedByName != null ? " • Traité par ${p.processedByName}" : ""}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.verified, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  if (p.isRejected && p.notes != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Motif de rejet : ${p.notes}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.rejected, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Formatters.formatCurrency(p.amount),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                BadgeChip(
                                  label: p.statusLabel,
                                  textColor: p.isPending
                                      ? AppColors.pending
                                      : (p.isProcessed ? AppColors.verified : AppColors.rejected),
                                  backgroundColor: p.isPending
                                      ? AppColors.pendingBg
                                      : (p.isProcessed ? AppColors.verifiedBg : AppColors.rejectedBg),
                                ),
                              ],
                            ),
                            if (p.isPending) ...[
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Rejeter & Recréditer',
                                    icon: const Icon(Icons.close_rounded, color: AppColors.rejected),
                                    onPressed: () => _promptRejectPayout(p),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.verified,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.check_rounded, size: 16),
                                    label: const Text('Valider'),
                                    onPressed: () => _promptApprovePayout(p),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildWalletsTab() {
    return Column(
      children: [
        // Recherche
        TextField(
          decoration: const InputDecoration(
            hintText: 'Rechercher par nom de structure, médecin ou numéro de compte...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (val) => setState(() => _walletSearch = val),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _filteredWallets.isEmpty
              ? const EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Aucun portefeuille trouvé',
                  message: 'Aucun partenaire ne correspond à votre recherche.',
                )
              : Card(
                  child: ListView.separated(
                    itemCount: _filteredWallets.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final w = _filteredWallets[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryContainer,
                          child: Icon(
                            w.holderType == 'Pharmacy'
                                ? Icons.local_pharmacy_rounded
                                : (w.holderType == 'Hospital' ? Icons.local_hospital_rounded : Icons.person_rounded),
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(w.holderName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDim,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                w.holderTypeLabel,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Coordonnées : ${w.payoutChannelLabel} • ${w.payoutAccount ?? "Non renseigné"}${w.payoutAccountName != null ? " (${w.payoutAccountName})" : ""}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Disponible : ${Formatters.formatCurrency(w.balance)}',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.verified),
                            ),
                            if (w.pendingBalance > 0)
                              Text(
                                'Séquestre : ${Formatters.formatCurrency(w.pendingBalance)}',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.pending, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _payoutFilterChip(String key, String label) {
    final selected = _payoutStatusFilter == key;
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
      onSelected: (_) => setState(() => _payoutStatusFilter = key),
    );
  }
}
