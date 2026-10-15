import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_shell.dart';
import '../../core/widgets/badge_chip.dart';
import '../../core/widgets/kpi_card.dart';
import '../../data/models/overview_metrics_model.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  OverviewMetricsModel? _metrics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final metrics = await ApiService.getOverview();
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceFirst('Exception: ', '');
        if (!err.toLowerCase().contains('session expirée') && !err.toLowerCase().contains('unauthenticated')) {
          setState(() {
            _error = err;
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminSection.overview,
      title: 'Vue d\'ensemble & Opérations Réseau',
      subtitle: 'Indicateurs clés d\'activité, accréditation des partenaires et flux financiers',
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.rejected, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Alertes d'action immédiate (Dossiers en attente d'agrément)
                      if ((_metrics?.hospitalsPending ?? 0) > 0 || (_metrics?.pharmaciesPending ?? 0) > 0) ...[
                        _buildActionAlerts(),
                        const SizedBox(height: 28),
                      ],

                      // Ligne 1 : Les 4 Grands Piliers Métier
                      const Text(
                        'Indicateurs d\'Activité Consolidés',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final int cols = constraints.maxWidth >= 1200 ? 4 : (constraints.maxWidth >= 680 ? 2 : 1);
                          final double cardWidth = (constraints.maxWidth - ((cols - 1) * 16)) / cols;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: KpiCard(
                                  title: 'Total Téléconsultations',
                                  value: '${_metrics?.consultationsTotal ?? 0}',
                                  subtitle: '${_metrics?.consultationsCompleted ?? 0} terminées • ${_metrics?.consultationsInProgress ?? 0} en cours',
                                  icon: Icons.video_call_rounded,
                                  iconColor: const Color(0xFF0284C7),
                                  iconBgColor: const Color(0xFFE0F2FE),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: KpiCard(
                                  title: 'Prescriptions Émises',
                                  value: '${_metrics?.prescriptionsTotal ?? 0}',
                                  subtitle: 'Ordonnances numériques sécurisées',
                                  icon: Icons.receipt_long_rounded,
                                  iconColor: const Color(0xFF0D9488),
                                  iconBgColor: const Color(0xFFCCFBF1),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: KpiCard(
                                  title: 'Chiffre d\'Affaires Global',
                                  value: Formatters.formatCurrency(_metrics?.revenueTotal ?? 0),
                                  subtitle: 'Consultations & Ventes pharmacie',
                                  icon: Icons.payments_rounded,
                                  iconColor: const Color(0xFF059669),
                                  iconBgColor: const Color(0xFFECFDF5),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: KpiCard(
                                  title: 'Dossiers Réclamations',
                                  value: '${_metrics?.claimsTotal ?? 0}',
                                  subtitle: '${_metrics?.claimsOpen ?? 0} ouverts • ${_metrics?.claimsInProgress ?? 0} en cours',
                                  icon: Icons.report_problem_rounded,
                                  iconColor: const Color(0xFFEA580C),
                                  iconBgColor: const Color(0xFFFFEDD5),
                                  trailingBadge: (_metrics?.claimsOpen ?? 0) > 0
                                      ? BadgeChip.priority('haute')
                                      : null,
                                  onTap: () => Navigator.pushNamed(context, '/claims'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // Ligne 2 : Établissements & Utilisateurs
                      const Text(
                        'Conformité des Établissements & Utilisateurs',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final int cols = constraints.maxWidth >= 1150 ? 3 : (constraints.maxWidth >= 720 ? 2 : 1);
                          final double cardWidth = (constraints.maxWidth - ((cols - 1) * 16)) / cols;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _buildEstablishmentSummaryCard(
                                  title: 'Hôpitaux Partenaires',
                                  total: _metrics?.hospitalsTotal ?? 0,
                                  verified: _metrics?.hospitalsVerified ?? 0,
                                  pending: _metrics?.hospitalsPending ?? 0,
                                  suspended: _metrics?.hospitalsSuspended ?? 0,
                                  icon: Icons.local_hospital_rounded,
                                  color: const Color(0xFF2563EB),
                                  onManage: () => Navigator.pushNamed(context, '/hospitals'),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildEstablishmentSummaryCard(
                                  title: 'Pharmacies & Officines',
                                  total: _metrics?.pharmaciesTotal ?? 0,
                                  verified: _metrics?.pharmaciesVerified ?? 0,
                                  pending: _metrics?.pharmaciesPending ?? 0,
                                  suspended: _metrics?.pharmaciesSuspended ?? 0,
                                  icon: Icons.local_pharmacy_rounded,
                                  color: const Color(0xFF0D9488),
                                  onManage: () => Navigator.pushNamed(context, '/pharmacies'),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildUsersSummaryCard(),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Ligne 3 : Listes Récentes
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 850;
                          final hospSection = _buildPendingSection(
                            title: 'Hôpitaux récents en attente de vérification',
                            count: _metrics?.pendingHospitals.length ?? 0,
                            icon: Icons.local_hospital_rounded,
                            items: (_metrics?.pendingHospitals ?? []).map((h) {
                              return _buildPendingItem(
                                title: h.name,
                                subtitle: 'Agrément / N° : ${h.licenseNumber ?? "Non renseigné"} • ${h.address ?? ""}',
                                date: Formatters.formatDate(h.createdAt),
                                onTap: () => Navigator.pushNamed(context, '/hospitals'),
                              );
                            }).toList(),
                            onViewAll: () => Navigator.pushNamed(context, '/hospitals'),
                          );

                          final pharmSection = _buildPendingSection(
                            title: 'Pharmacies récentes en attente de validation',
                            count: _metrics?.pendingPharmacies.length ?? 0,
                            icon: Icons.local_pharmacy_rounded,
                            items: (_metrics?.pendingPharmacies ?? []).map((p) {
                              return _buildPendingItem(
                                title: p.name,
                                subtitle: 'Titulaire : ${p.owner?.name ?? "—"} • Réf : ${p.referenceId ?? "—"}',
                                date: Formatters.formatDate(p.createdAt),
                                onTap: () => Navigator.pushNamed(context, '/pharmacies'),
                              );
                            }).toList(),
                            onViewAll: () => Navigator.pushNamed(context, '/pharmacies'),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                hospSection,
                                const SizedBox(height: 20),
                                pharmSection,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: hospSection),
                              const SizedBox(width: 24),
                              Expanded(child: pharmSection),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildActionAlerts() {
    final hospPending = _metrics?.hospitalsPending ?? 0;
    final pharmPending = _metrics?.pharmaciesPending ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pendingBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.pendingBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pending,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_late_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Actions de Conformité Requises',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 4),
                Text(
                  '$hospPending hôpital(aux) et $pharmPending pharmacie(s) ont déposé leurs pièces justificatives et attendent l\'accréditation eDoctor.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              if (hospPending > 0)
                OutlinedButton.icon(
                  icon: const Icon(Icons.local_hospital_rounded, size: 16),
                  label: Text('Vérifier Hôpitaux ($hospPending)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF92400E),
                    side: const BorderSide(color: Color(0xFFD97706)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/hospitals'),
                ),
              if (hospPending > 0 && pharmPending > 0) const SizedBox(width: 10),
              if (pharmPending > 0)
                ElevatedButton.icon(
                  icon: const Icon(Icons.local_pharmacy_rounded, size: 16),
                  label: Text('Vérifier Pharmacies ($pharmPending)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/pharmacies'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstablishmentSummaryCard({
    required String title,
    required int total,
    required int verified,
    required int pending,
    required int suspended,
    required IconData icon,
    required Color color,
    required VoidCallback onManage,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('$total au total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMiniMetric('Certifiés', '$verified', AppColors.verified),
              const SizedBox(width: 8),
              _buildMiniMetric('En attente', '$pending', AppColors.pending),
              const SizedBox(width: 8),
              _buildMiniMetric('Suspendus', '$suspended', AppColors.suspended),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onManage,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Gérer & Accréditer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.people_alt_rounded, color: Color(0xFF7C3AED), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'Annuaire Utilisateurs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${_metrics?.usersTotal ?? 0} inscrits', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMiniMetric('Patients', '${_metrics?.patientsCount ?? 0}', const Color(0xFF475569)),
              const SizedBox(width: 6),
              _buildMiniMetric('Médecins', '${_metrics?.doctorsCount ?? 0}', const Color(0xFF0369A1)),
              const SizedBox(width: 6),
              _buildMiniMetric('Pharmaciens', '${_metrics?.pharmacistsCount ?? 0}', const Color(0xFF0D9488)),
              const SizedBox(width: 6),
              _buildMiniMetric('Suspendus', '${_metrics?.suspendedUsersCount ?? 0}', AppColors.rejected),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/users'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Modération des Comptes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSection({
    required String title,
    required int count,
    required IconData icon,
    required List<Widget> items,
    required VoidCallback onViewAll,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('Tout voir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Aucun dossier en attente d\'audit.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ),
            )
          else
            ...items,
        ],
      ),
    );
  }

  Widget _buildPendingItem({
    required String title,
    required String subtitle,
    required String date,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BadgeChip.status('en_attente'),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
