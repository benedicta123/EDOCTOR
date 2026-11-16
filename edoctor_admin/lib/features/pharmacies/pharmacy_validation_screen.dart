import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/badge_chip.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/pharmacy_model.dart';
import 'pharmacy_detail_modal.dart';

class PharmacyValidationScreen extends StatefulWidget {
  const PharmacyValidationScreen({super.key});

  @override
  State<PharmacyValidationScreen> createState() => _PharmacyValidationScreenState();
}

class _PharmacyValidationScreenState extends State<PharmacyValidationScreen> {
  List<PharmacyModel> _pharmacies = [];
  bool _loading = true;
  String _statusFilter = 'tous';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Pagination côté serveur
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalPharmacies = 0;
  int _from = 0;
  int _to = 0;
  int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getPaginatedPharmacies(
        status: _statusFilter,
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        page: _currentPage,
        perPage: _perPage,
      );
      if (mounted) {
        setState(() {
          _pharmacies = res.data;
          _currentPage = res.currentPage;
          _lastPage = res.lastPage;
          _totalPharmacies = res.total;
          _from = res.from;
          _to = res.to;
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

  void _goToPage(int page) {
    if (page < 1 || page > _lastPage || page == _currentPage || _loading) return;
    setState(() => _currentPage = page);
    _load();
  }

  Future<void> _verify(PharmacyModel p) async {
    try {
      await ApiService.verifyPharmacy(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Partenariat validé ! "${p.name}" est agréée sur le réseau eDoctor.'),
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

  Future<void> _reject(PharmacyModel p, String reason) async {
    try {
      await ApiService.rejectPharmacy(p.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dossier de "${p.name}" rejeté avec notification.'),
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

  Future<void> _suspend(PharmacyModel p, String reason) async {
    try {
      await ApiService.suspendPharmacy(p.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partenariat de "${p.name}" suspendu.'),
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

  Future<void> _reactivate(PharmacyModel p) async {
    try {
      await ApiService.reactivatePharmacy(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ L\'officine "${p.name}" a été réactivée avec succès.'),
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

  void _openDetail(PharmacyModel p) {
    PharmacyDetailModal.show(
      context: context,
      pharmacy: p,
      onVerify: _verify,
      onReject: _reject,
      onSuspend: _suspend,
      onReactivate: _reactivate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminSection.pharmacies,
      title: 'Accréditation des Pharmacies Partenaires (KYB/KYP)',
      subtitle: 'Vérification documentaire, inscription ordinale et agrément des officines partenaires',
      onRefresh: _load,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre d'outils
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('Toutes les officines', 'tous'),
                    _buildFilterChip('En attente de validation', 'en_attente'),
                    _buildFilterChip('Officines Agréées', 'verifie'),
                    _buildFilterChip('Rejetées', 'rejete'),
                    _buildFilterChip('Suspendues', 'suspendu'),
                  ],
                ),
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher officine, titulaire, réf...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _searchDebounce?.cancel();
                                setState(() {
                                  _searchQuery = '';
                                  _currentPage = 1;
                                });
                                _load();
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                    onChanged: (val) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                        setState(() {
                          _searchQuery = val;
                          _currentPage = 1;
                        });
                        _load();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tableau des Pharmacies
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _pharmacies.isEmpty
                      ? const EmptyState(
                          icon: Icons.local_pharmacy_outlined,
                          title: 'Aucune officine trouvée',
                          message: 'Aucune pharmacie ne correspond aux critères de filtre sélectionnés.',
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
                                      itemCount: _pharmacies.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                                      itemBuilder: (context, index) {
                                        final p = _pharmacies[index];
                                        return _buildPharmacyRow(p);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
            if (!_loading && _pharmacies.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPaginationFooter(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 750;

          // Infos et sélecteur par page
          final leftSection = Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Affichage de $_from à $_to sur $_totalPharmacies officine${_totalPharmacies > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Par page :', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _perPage,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 15, child: Text('15')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _perPage) {
                            setState(() {
                              _perPage = val;
                              _currentPage = 1;
                            });
                            _load();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          // Contrôles de navigation (Précédent / Numéros / Suivant)
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.chevron_left_rounded, size: 16),
                label: const Text('Précédent', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _currentPage > 1 ? AppColors.textPrimary : AppColors.textMuted,
                  side: BorderSide(color: _currentPage > 1 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _currentPage > 1 && !_loading ? () => _goToPage(_currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              ..._buildPageNumberButtons(),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.chevron_right_rounded, size: 16),
                label: const Text('Suivant', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _currentPage < _lastPage ? AppColors.textPrimary : AppColors.textMuted,
                  side: BorderSide(color: _currentPage < _lastPage ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _currentPage < _lastPage && !_loading ? () => _goToPage(_currentPage + 1) : null,
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: leftSection),
                const SizedBox(height: 10),
                Center(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: controls)),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              leftSection,
              controls,
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPageNumberButtons() {
    final List<Widget> widgets = [];
    final maxPages = _lastPage < 1 ? 1 : _lastPage;

    final Set<int> pagesToShow = {};
    pagesToShow.add(1);
    pagesToShow.add(maxPages);
    for (int i = _currentPage - 1; i <= _currentPage + 1; i++) {
      if (i >= 1 && i <= maxPages) {
        pagesToShow.add(i);
      }
    }

    final sortedPages = pagesToShow.toList()..sort();
    int? prevPage;

    for (final page in sortedPages) {
      if (prevPage != null && page - prevPage > 1) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
        );
      }

      final isCurrent = page == _currentPage;
      widgets.add(
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: isCurrent || _loading ? null : () => _goToPage(page),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isCurrent ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              '$page',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
      prevPage = page;
    }

    return widgets;
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected && _statusFilter != value) {
          setState(() {
            _statusFilter = value;
            _currentPage = 1;
          });
          _load();
        }
      },
      selectedColor: const Color(0xFF0D9488),
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      side: BorderSide(color: isSelected ? const Color(0xFF0D9488) : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildPharmacyRow(PharmacyModel p) {
    return InkWell(
      onTap: () => _openDetail(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.isVerified
                    ? AppColors.verifiedBg
                    : p.isPending
                        ? AppColors.pendingBg
                        : AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_pharmacy_rounded,
                color: p.isVerified
                    ? AppColors.verified
                    : p.isPending
                        ? AppColors.pending
                        : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Nom & Réf
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDim,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.referenceId ?? 'RÉF NON DÉFINIE',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.address ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Pharmacien Titulaire
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.owner?.name ?? 'Non assigné',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.owner?.phone ?? p.phone ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // N° Licence & Ordre
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Licence : ${p.licenseNumber ?? "N/A"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ordre : ${p.orderNumber ?? "N/A"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Statut
            SizedBox(
              width: 150,
              child: Align(
                alignment: Alignment.centerLeft,
                child: BadgeChip.status(p.status),
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
                  onPressed: () => _openDetail(p),
                ),
                const SizedBox(width: 8),
                if (p.isPending) ...[
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded, color: AppColors.verified, size: 22),
                    tooltip: 'Valider l\'agrément d\'officine',
                    onPressed: () async {
                      final confirm = await ConfirmActionDialog.show(
                        context: context,
                        title: 'Valider l\'agrément de l\'officine',
                        message: 'Confirmez-vous que la pharmacie ${p.name} remplit les conditions de licence et d\'exercice ?',
                        confirmLabel: 'Homologuer',
                        confirmColor: AppColors.verified,
                        icon: Icons.verified_rounded,
                      );
                      if (confirm != null) _verify(p);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: AppColors.rejected, size: 22),
                    tooltip: 'Rejeter la demande',
                    onPressed: () async {
                      final reason = await ConfirmActionDialog.show(
                        context: context,
                        title: 'Rejeter la demande d\'agrément',
                        message: 'Précisez le motif du rejet pour l\'officine ${p.name} :',
                        confirmLabel: 'Rejeter',
                        confirmColor: AppColors.rejected,
                        icon: Icons.cancel_outlined,
                        requireReason: true,
                        quickReasons: ['Diplôme de docteur manquant', 'Licence d\'officine invalide'],
                      );
                      if (reason != null) _reject(p, reason);
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
