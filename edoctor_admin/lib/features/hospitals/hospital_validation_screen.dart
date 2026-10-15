import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/badge_chip.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/hospital_model.dart';
import 'hospital_detail_modal.dart';

class HospitalValidationScreen extends StatefulWidget {
  const HospitalValidationScreen({super.key});

  @override
  State<HospitalValidationScreen> createState() => _HospitalValidationScreenState();
}

class _HospitalValidationScreenState extends State<HospitalValidationScreen> {
  List<HospitalModel> _hospitals = [];
  bool _loading = true;
  String _statusFilter = 'tous';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getHospitals(
        status: _statusFilter,
        search: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _hospitals = list;
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

  Future<void> _verify(HospitalModel h) async {
    try {
      await ApiService.verifyHospital(h.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Partenariat validé ! "${h.name}" est désormais certifié sur le réseau eDoctor.'),
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

  Future<void> _reject(HospitalModel h, String reason) async {
    try {
      await ApiService.rejectHospital(h.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dossier de "${h.name}" rejeté avec notification.'),
            backgroundColor: AppColors.rejected,
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

  Future<void> _suspend(HospitalModel h, String reason) async {
    try {
      await ApiService.suspendHospital(h.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activité de "${h.name}" suspendue.'),
            backgroundColor: AppColors.suspended,
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

  Future<void> _reactivate(HospitalModel h) async {
    try {
      await ApiService.reactivateHospital(h.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ L\'établissement "${h.name}" a été réactivé.'),
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

  void _openDetail(HospitalModel h) {
    HospitalDetailModal.show(
      context: context,
      hospital: h,
      onVerify: _verify,
      onReject: _reject,
      onSuspend: _suspend,
      onReactivate: _reactivate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminSection.hospitals,
      title: 'Accréditation & Conformité des Hôpitaux',
      subtitle: 'Audit documentaire KYB/KYP et validation des établissements de santé partenaires',
      onRefresh: _load,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre d'outils (Filtres statut & Recherche)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Onglets de filtre statut
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('Tous les établissements', 'tous'),
                    _buildFilterChip('En attente d\'audit', 'en_attente'),
                    _buildFilterChip('Partenaires Certifiés', 'verifie'),
                    _buildFilterChip('Rejetés', 'rejete'),
                    _buildFilterChip('Suspendus', 'suspendu'),
                  ],
                ),

                // Champ Recherche
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un hôpital, agrément...',
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

            // Tableau des Hôpitaux
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _hospitals.isEmpty
                      ? const EmptyState(
                          icon: Icons.local_hospital_outlined,
                          title: 'Aucun établissement trouvé',
                          message: 'Aucun hôpital ne correspond aux critères de filtre sélectionnés.',
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
                                      itemCount: _hospitals.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                                      itemBuilder: (context, index) {
                                        final h = _hospitals[index];
                                        return _buildHospitalRow(h);
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
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildHospitalRow(HospitalModel h) {
    return InkWell(
      onTap: () => _openDetail(h),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: h.isVerified
                    ? AppColors.verifiedBg
                    : h.isPending
                        ? AppColors.pendingBg
                        : AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_hospital_rounded,
                color: h.isVerified
                    ? AppColors.verified
                    : h.isPending
                        ? AppColors.pending
                        : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Nom & Adresse
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    h.address ?? 'Adresse non renseignée',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // N° Agrément MSHP & NIF
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          h.licenseNumber ?? 'N/A',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NIF: ${h.taxNumber ?? "Non renseigné"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Soignants
            Expanded(
              flex: 2,
              child: Text(
                '${h.doctorsCount} médecin(s)\n${h.staffCount} personnel soignant',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
              ),
            ),

            // Statut
            SizedBox(
              width: 150,
              child: Align(
                alignment: Alignment.centerLeft,
                child: BadgeChip.status(h.status),
              ),
            ),

            // Actions rapides
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Auditer'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openDetail(h),
                ),
                const SizedBox(width: 8),
                if (h.isPending) ...[
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded, color: AppColors.verified, size: 22),
                    tooltip: 'Valider le partenariat & Activer',
                    onPressed: () async {
                      final confirm = await ConfirmActionDialog.show(
                        context: context,
                        title: 'Valider le partenariat',
                        message: 'Confirmez-vous que l\'établissement ${h.name} a fourni des pièces conformes ?',
                        confirmLabel: 'Valider',
                        confirmColor: AppColors.verified,
                        icon: Icons.verified_rounded,
                      );
                      if (confirm != null) _verify(h);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: AppColors.rejected, size: 22),
                    tooltip: 'Rejeter la demande',
                    onPressed: () async {
                      final reason = await ConfirmActionDialog.show(
                        context: context,
                        title: 'Rejeter la demande',
                        message: 'Précisez le motif de non-conformité pour ${h.name} :',
                        confirmLabel: 'Rejeter',
                        confirmColor: AppColors.rejected,
                        icon: Icons.cancel_outlined,
                        requireReason: true,
                        quickReasons: ['Pièces justificatives illisibles', 'Numéro d\'autorisation non vérifiable', 'Informations légales non concordantes'],
                      );
                      if (reason != null) _reject(h, reason);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
