import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/badge_chip.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/claim_model.dart';

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  List<ClaimModel> _claims = [];
  bool _loading = true;
  String _statusFilter = 'tous';
  String _priorityFilter = 'tous';
  final String _categoryFilter = 'tous';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getClaims(
        status: _statusFilter,
        priority: _priorityFilter,
        category: _categoryFilter,
        search: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _claims = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        final err = e.toString().replaceFirst('Exception: ', '');
        if (!err.toLowerCase().contains('session expirée') && !err.toLowerCase().contains('unauthenticated')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.rejected),
          );
        }
      }
    }
  }

  Future<void> _resolve(ClaimModel c, String notes) async {
    try {
      await ApiService.resolveClaim(c.id, notes: notes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Réclamation ${c.referenceId} résolue avec notification au plaignant.'),
            backgroundColor: AppColors.verified,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.rejected),
        );
      }
    }
  }

  Future<void> _updateStatus(ClaimModel c, String status, {String? notes}) async {
    try {
      await ApiService.updateClaimStatus(c.id, status: status, notes: notes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut de la réclamation ${c.referenceId} mis à jour ($status).'),
            backgroundColor: AppColors.primary,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.rejected),
        );
      }
    }
  }

  void _openClaimDetail(ClaimModel c) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750, maxHeight: 800),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  color: AppColors.sidebarBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.report_problem_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  c.referenceId,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                BadgeChip.priority(c.priority),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Réclamation enregistrée le ${Formatters.formatDateTime(c.createdAt)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statut actuel & Résolution si existante
                      Row(
                        children: [
                          const Text('Statut actuel :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(width: 8),
                          BadgeChip(
                            label: c.statusLabel,
                            textColor: c.isResolved ? AppColors.verified : (c.isInProgress ? AppColors.pending : AppColors.priorityHigh),
                            backgroundColor: c.isResolved ? AppColors.verifiedBg : (c.isInProgress ? AppColors.pendingBg : const Color(0xFFFFEDD5)),
                            borderColor: c.isResolved ? AppColors.verifiedBorder : (c.isInProgress ? AppColors.pendingBorder : const Color(0xFFFED7AA)),
                          ),
                          const Spacer(),
                          Text('Catégorie : ${c.categoryLabel}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Identité plaignant & cible
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDim,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Émis par (Plaignant) :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                                  const SizedBox(height: 4),
                                  Text(c.user?.name ?? 'Utilisateur ID ${c.userId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  Text('${c.user?.email ?? ""} • ${c.user?.phone ?? ""}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: AppColors.border),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Entité mise en cause :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.targetType != null ? c.targetType!.toUpperCase() : 'PLATEFORME GLOBALE',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                  Text('Cible réf: ${c.targetId != null ? "#${c.targetId}" : "Service général"}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Objet & Description du litige
                      const Text('Objet de la réclamation :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(c.subject, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),

                      const Text('Exposé détaillé des faits :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          c.description,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                        ),
                      ),

                      // Notes de résolution si existantes
                      if (c.resolutionNotes != null && c.resolutionNotes!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.verifiedBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.verifiedBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.gavel_rounded, color: AppColors.verified, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Arbitrage & Conclusions de Résolution (par ${c.resolver?.name ?? "Super-Admin"}) :',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.verified),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                c.resolutionNotes!,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fermer'),
                    ),
                    if (!c.isResolved) ...[
                      Row(
                        children: [
                          if (c.isOpen) ...[
                            OutlinedButton.icon(
                              icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                              label: const Text('Prendre en instruction'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateStatus(c, 'en_cours');
                              },
                            ),
                            const SizedBox(width: 10),
                          ],
                          ElevatedButton.icon(
                            icon: const Icon(Icons.gavel_rounded, size: 16),
                            label: const Text('Régler & Clôturer le litige'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verified, foregroundColor: Colors.white),
                            onPressed: () async {
                              final notes = await ConfirmActionDialog.show(
                                context: context,
                                title: 'Régler la réclamation',
                                message: 'Saisissez les conclusions d\'arbitrage ou les mesures de conciliation prises :',
                                confirmLabel: 'Clôturer le litige',
                                confirmColor: AppColors.verified,
                                icon: Icons.gavel_rounded,
                                requireReason: true,
                                reasonHint: 'Conclusions d\'arbitrage, remboursement, avertissement...',
                                quickReasons: [
                                  'Remboursement immédiat effectué au patient',
                                  'Avertissement formel notifié au praticien',
                                  'Incident technique résolu par l\'équipe support',
                                  'Médiation réussie entre les deux parties',
                                ],
                              );
                              if (notes != null && context.mounted) {
                                Navigator.pop(ctx);
                                _resolve(c, notes);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminSection.claims,
      title: 'Journal des Réclamations & Arbitrage des Litiges',
      subtitle: 'Registre officiel des incidents patients/médecins, litiges financiers et conciliation',
      onRefresh: _load,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre d'outils (Filtres statut, priorité & recherche)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filtre Statut
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('Toutes les réclamations', 'tous'),
                        _buildFilterChip('Ouvertes', 'ouvert'),
                        _buildFilterChip('En instruction', 'en_cours'),
                        _buildFilterChip('Résolues', 'resolu'),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Filtre Priorité
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _priorityFilter,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          items: const [
                            DropdownMenuItem(value: 'tous', child: Text('Toutes priorités')),
                            DropdownMenuItem(value: 'urgente', child: Text('🔥 Urgente')),
                            DropdownMenuItem(value: 'haute', child: Text('⚠️ Haute')),
                            DropdownMenuItem(value: 'normale', child: Text('Normale')),
                            DropdownMenuItem(value: 'faible', child: Text('Faible')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _priorityFilter = val);
                              _load();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Recherche
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher réf, plaignant, objet...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tableau des Réclamations
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _claims.isEmpty
                      ? const EmptyState(
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Aucune réclamation trouvée',
                          message: 'Aucun dossier de litige ne correspond aux filtres actuels.',
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const minWidth = 1050.0;
                                final tableWidth = constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: ListView.separated(
                                      itemCount: _claims.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                                      itemBuilder: (context, index) {
                                        final c = _claims[index];
                                        return _buildClaimRow(c);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _statusFilter = value);
          _load();
        }
      },
      selectedColor: const Color(0xFFEA580C),
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      side: BorderSide(color: isSelected ? const Color(0xFFEA580C) : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildClaimRow(ClaimModel c) {
    return InkWell(
      onTap: () => _openClaimDetail(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Badge Priorité
            BadgeChip.priority(c.priority),
            const SizedBox(width: 14),

            // Réf & Date
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.referenceId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(Formatters.formatRelative(c.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),

            // Plaignant
            SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.user?.name ?? 'Utilisateur #${c.userId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.user?.roleLabel ?? 'Particulier',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Objet & Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Statut
            SizedBox(
              width: 140,
              child: Align(
                alignment: Alignment.centerLeft,
                child: BadgeChip(
                  label: c.statusLabel,
                  textColor: c.isResolved ? AppColors.verified : (c.isInProgress ? AppColors.pending : AppColors.priorityHigh),
                  backgroundColor: c.isResolved ? AppColors.verifiedBg : (c.isInProgress ? AppColors.pendingBg : const Color(0xFFFFEDD5)),
                  borderColor: c.isResolved ? AppColors.verifiedBorder : (c.isInProgress ? AppColors.pendingBorder : const Color(0xFFFED7AA)),
                ),
              ),
            ),

            // Action
            OutlinedButton.icon(
              icon: const Icon(Icons.gavel_rounded, size: 14),
              label: const Text('Arbitrer'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _openClaimDetail(c),
            ),
          ],
        ),
      ),
    );
  }
}
