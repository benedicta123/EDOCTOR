import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/badge_chip.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/user_model.dart';

class UsersModerationScreen extends StatefulWidget {
  const UsersModerationScreen({super.key});

  @override
  State<UsersModerationScreen> createState() => _UsersModerationScreenState();
}

class _UsersModerationScreenState extends State<UsersModerationScreen> {
  List<UserModel> _users = [];
  bool _loading = true;
  String _roleFilter = 'tous';
  String _statusFilter = 'tous';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Pagination côté serveur
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalUsers = 0;
  int _from = 0;
  int _to = 0;
  final int _perPage = 15;

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
      final res = await ApiService.getPaginatedUsers(
        role: _roleFilter,
        status: _statusFilter,
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        page: _currentPage,
        perPage: _perPage,
      );
      if (mounted) {
        setState(() {
          _users = res.data;
          _currentPage = res.currentPage;
          _lastPage = res.lastPage;
          _totalUsers = res.total;
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

  Future<void> _suspend(UserModel u, String reason) async {
    try {
      await ApiService.suspendUser(u.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Le compte de "${u.name}" a été suspendu pour litige / impayé.'),
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

  Future<void> _reactivate(UserModel u) async {
    try {
      await ApiService.reactivateUser(u.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Le compte de "${u.name}" a été réactivé avec succès.'),
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

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminSection.users,
      title: 'Gestion des Utilisateurs & Modération Réglementaire',
      subtitle: 'Contrôle des comptes, suspension en cas de litige/impayé et réactivation administrative',
      onRefresh: _load,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre de filtres combinés
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filtre par Rôle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _roleFilter,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          items: const [
                            DropdownMenuItem(value: 'tous', child: Text('Tous les rôles')),
                            DropdownMenuItem(value: 'patient', child: Text('Patients')),
                            DropdownMenuItem(value: 'doctor', child: Text('Médecins')),
                            DropdownMenuItem(value: 'pharmacist', child: Text('Pharmaciens')),
                            DropdownMenuItem(value: 'nurse', child: Text('Infirmiers')),
                            DropdownMenuItem(value: 'admin', child: Text('Administrateurs')),
                          ],
                          onChanged: (val) {
                            if (val != null && val != _roleFilter) {
                              setState(() {
                                _roleFilter = val;
                                _currentPage = 1;
                              });
                              _load();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filtre par Statut (Tous, Actif, Suspendu)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('Tous les statuts', 'tous'),
                        _buildFilterChip('Actifs', 'actif'),
                        _buildFilterChip('Suspendus pour litige', 'suspendu'),
                      ],
                    ),
                  ],
                ),

                // Recherche
                SizedBox(
                  width: 320,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher nom, email, téléphone...',
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

            // Tableau des Utilisateurs
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _users.isEmpty
                      ? const EmptyState(
                          icon: Icons.person_off_outlined,
                          title: 'Aucun utilisateur trouvé',
                          message: 'Aucun compte ne correspond aux filtres et termes de recherche.',
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
                                      itemCount: _users.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                                      itemBuilder: (context, index) {
                                        final u = _users[index];
                                        return _buildUserRow(u);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
            if (!_loading && _totalUsers > 0) ...[
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
          final isCompact = constraints.maxWidth < 650;
          final counter = Text(
            'Affichage de $_from à $_to sur $_totalUsers utilisateur${_totalUsers > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          );

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
                Center(child: counter),
                const SizedBox(height: 10),
                Center(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: controls)),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              counter,
              controls,
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPageNumberButtons() {
    final List<Widget> widgets = [];
    if (_lastPage <= 1) return widgets;

    final Set<int> pagesToShow = {};
    pagesToShow.add(1);
    pagesToShow.add(_lastPage);
    for (int i = _currentPage - 1; i <= _currentPage + 1; i++) {
      if (i >= 1 && i <= _lastPage) {
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

  Widget _buildUserRow(UserModel u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Avatar avec initiale
          CircleAvatar(
            radius: 20,
            backgroundColor: u.isSuspended ? AppColors.suspended.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: u.isSuspended ? AppColors.suspended : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Nom & Email
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        u.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: u.isSuspended ? AppColors.suspended : AppColors.textPrimary,
                          decoration: u.isSuspended ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (u.isSuperAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                        child: const Text('SUPER-ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  u.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Rôle
          SizedBox(
            width: 150,
            child: Align(
              alignment: Alignment.centerLeft,
              child: BadgeChip.role(u.role),
            ),
          ),
          const SizedBox(width: 12),

          // Rapprochement (Hôpital ou Pharmacie)
          Expanded(
            flex: 2,
            child: Text(
              u.hospitalName != null
                  ? '🏥 ${u.hospitalName}'
                  : u.pharmacyName != null
                      ? '💊 ${u.pharmacyName}'
                      : u.specialty ?? (u.isPatient ? 'Particulier' : '—'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),

          // Téléphone
          SizedBox(
            width: 120,
            child: Text(
              u.phone ?? 'Non renseigné',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),

          // Statut Modération
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                BadgeChip.status(u.isSuspended ? 'suspendu' : 'actif'),
                if (u.isSuspended && u.suspensionReason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    u.suspensionReason!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppColors.suspended, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Bouton d'action (Suspendre / Réactiver)
          SizedBox(
            width: 120,
            child: !u.isSuperAdmin
                ? (u.isSuspended
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.restart_alt_rounded, size: 14),
                        label: const Text('Réactiver', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.verified,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final confirm = await ConfirmActionDialog.show(
                            context: context,
                            title: 'Réactiver le compte utilisateur',
                            message: 'Confirmez-vous la réactivation du compte de ${u.name} ? L\'accès à la plateforme lui sera immédiatement restauré.',
                            confirmLabel: 'Réactiver le compte',
                            confirmColor: AppColors.verified,
                            icon: Icons.check_circle_rounded,
                          );
                          if (confirm != null) _reactivate(u);
                        },
                      )
                    : OutlinedButton.icon(
                        icon: const Icon(Icons.block_rounded, size: 14),
                        label: const Text('Suspendre', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.suspended,
                          side: const BorderSide(color: AppColors.suspended),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final reason = await ConfirmActionDialog.show(
                            context: context,
                            title: 'Suspendre le compte',
                            message: 'Indiquez le motif réglementaire de la suspension pour ${u.name} (le compte sera immédiatement déconnecté) :',
                            confirmLabel: 'Suspendre le compte',
                            confirmColor: AppColors.suspended,
                            icon: Icons.block_rounded,
                            requireReason: true,
                            reasonHint: 'Ex: Litige financier, impayé de téléconsultation, comportement inapproprié...',
                            quickReasons: [
                              'Défaut de paiement / Litige sur facture',
                              'Non-respect des règles déontologiques',
                              'Signalement patient répété',
                              'Suspicion d\'usurpation d\'identité médicale',
                            ],
                          );
                          if (reason != null) _suspend(u, reason);
                        },
                      ))
                : const Center(
                    child: Text('Immunité', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ),
          ),
        ],
      ),
    );
  }
}
