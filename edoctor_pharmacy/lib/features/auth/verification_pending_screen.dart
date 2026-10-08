import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';

class VerificationPendingScreen extends StatefulWidget {
  final String? pharmacyName;
  final String? pharmacistName;
  final String? orderNumber;
  final String? referenceId;

  const VerificationPendingScreen({
    super.key,
    this.pharmacyName,
    this.pharmacistName,
    this.orderNumber,
    this.referenceId,
  });

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  bool _isRefreshing = false;
  String? _pharmacyName;
  String? _pharmacistName;
  String? _orderNumber;
  String? _referenceId;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _pharmacyName = widget.pharmacyName;
    _pharmacistName = widget.pharmacistName;
    _orderNumber = widget.orderNumber;
    _referenceId = widget.referenceId;
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final stored = await StorageService.getPendingApplication();
    if (stored != null && mounted) {
      setState(() {
        _pharmacyName ??= stored['pharmacyName'] as String?;
        _pharmacistName ??= stored['pharmacistName'] as String?;
        _orderNumber ??= stored['orderNumber'] as String?;
        _referenceId ??= stored['referenceId'] as String?;
        _status = (stored['status'] as String?) ?? 'pending';
      });
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isRefreshing = true);

    try {
      final lookupQuery = _referenceId ?? widget.referenceId;
      if (lookupQuery != null && lookupQuery.isNotEmpty) {
        final result = await ApiService.trackPharmacyStatus(lookupQuery);
        final status = result['status'] as String? ?? 'en_attente';

        if (status == 'verifie') {
          await StorageService.clearPendingApplication();
          if (!mounted) return;
          setState(() {
            _isRefreshing = false;
            _status = 'approved';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Félicitations ! Votre officine a été agréée par eDoctor. Accès au tableau de bord...'),
              backgroundColor: AppColors.inStock,
              duration: Duration(seconds: 3),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/dashboard');
          return;
        }
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));
    final stored = await StorageService.getPendingApplication();
    final status = (stored?['status'] as String?) ?? _status;

    if (!mounted) return;
    setState(() {
      _isRefreshing = false;
      _status = status;
    });

    if (status == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Félicitations ! Votre officine a été agréée par eDoctor. Accès au tableau de bord...'),
          backgroundColor: AppColors.inStock,
          duration: Duration(seconds: 3),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dossier toujours en cours d\'examen par l\'équipe Conformité eDoctor. Vous recevrez une notification par email dès finalisation.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _logout() async {
    await StorageService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final pharmacy = _pharmacyName ?? 'Pharmacie en cours d\'agrément';
    final pharmacist = _pharmacistName ?? 'Docteur en Pharmacie';
    final orderNum = _orderNumber ?? 'ONPT-XXXX';
    final ref = _referenceId ?? 'KYP-2026-TG892';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Halos d'ambiance doux en arrière-plan
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5E2).withValues(alpha: 0.65),
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: isDesktop ? size.width * 0.08 : -60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryLight.withValues(alpha: 0.35),
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.background.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : 20,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    children: [
                      // Header supérieur avec Logo officiel
                      _buildHeader(),
                      const SizedBox(height: 36),

                      // Carte principale de statut
                      _buildMainCard(
                        isDesktop: isDesktop,
                        pharmacy: pharmacy,
                        pharmacist: pharmacist,
                        orderNum: orderNum,
                        ref: ref,
                      ),
                      const SizedBox(height: 28),

                      // Assistance et mentions
                      _buildSupportSection(isDesktop),
                      const SizedBox(height: 24),
                      const Text(
                        '© 2026 eDoctor Pharmacie • République Togolaise. Plateforme Nationale de Santé Numérique.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 44,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Row(
                children: [
                  Icon(Icons.local_pharmacy_rounded, color: AppColors.primary, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'eDoctor',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: const Text(
                'ESPACE PHARMACIE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),

        // Bouton Déconnexion / Retour Accueil
        TextButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.textSecondary),
          label: const Text(
            'Se déconnecter',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainCard({
    required bool isDesktop,
    required String pharmacy,
    required String pharmacist,
    required String orderNum,
    required String ref,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40 : 22,
              vertical: 36,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.95), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Badge et statut supérieur
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 15),
                          SizedBox(width: 7),
                          Text(
                            'DOSSIER EN COURS D\'AUDIT SANITAIRE',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Réf: $ref',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Grand titre d'attente chaleureux
                const Text(
                  'Votre dossier a bien été reçu et est en cours d\'audit',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                    letterSpacing: -0.5,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Pour assurer la sécurité absolue des patients et la conformité avec l\'Ordre National des Pharmaciens, '
                  'l\'équipe Conformité eDoctor vérifie systématiquement l\'Arrêté Ministériel et les habilitations de chaque officine.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),

                // Délai moyen dans un bandeau vert doux
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: AppColors.primary, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Délai moyen de traitement : 24h à 48h ouvrées. Vous recevrez un email de confirmation dès activation.',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryHover,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Timeline visuelle des 4 étapes
                const Text(
                  'Progression de la vérification de conformité',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTimeline(),
                const SizedBox(height: 36),

                // Récapitulatif de l'officine soumise
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RÉCAPITULATIF DU DOSSIER ENREGISTRÉ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 24,
                        runSpacing: 14,
                        children: [
                          _buildRecapItem('Officine', pharmacy, Icons.local_pharmacy_outlined),
                          _buildRecapItem('Pharmacien Titulaire', pharmacist, Icons.person_outline),
                          _buildRecapItem('N° Ordre National', orderNum, Icons.verified_outlined),
                          _buildRecapItem('Statut Actuel', 'Audit des pièces (Étape 2/4)', Icons.pending_actions_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Boutons d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isRefreshing ? null : _checkStatus,
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Actualiser le statut'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Le support de conformité est joignable à : conformite@edoctor.tg'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.headset_mic_outlined, size: 18, color: Colors.white),
                      label: const Text('Contacter la Conformité'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecapItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    final steps = [
      _TimelineStep(
        number: '1',
        title: 'Dossier Reçu',
        subtitle: 'Formulaire & documents transmis avec succès',
        status: _StepStatus.completed,
      ),
      _TimelineStep(
        number: '2',
        title: 'Audit des Pièces',
        subtitle: 'Contrôle Arrêté Ministériel & N° Ordre des Pharmaciens',
        status: _StepStatus.inProgress,
      ),
      _TimelineStep(
        number: '3',
        title: 'Appel de Sécurité',
        subtitle: 'Contre-appel protocolaire au standard fixe officiel',
        status: _StepStatus.pending,
      ),
      _TimelineStep(
        number: '4',
        title: 'Validation Finale',
        subtitle: 'Attribution du badge "Officine Agréée" & accès ouvert',
        status: _StepStatus.pending,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        if (isNarrow) {
          return Column(
            children: steps.map((s) => _buildVerticalStepTile(s)).toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Expanded(child: _buildHorizontalStepTile(steps[i])),
              if (i < steps.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Container(
                    width: 24,
                    height: 2,
                    color: steps[i].status == _StepStatus.completed
                        ? AppColors.primary
                        : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHorizontalStepTile(_TimelineStep step) {
    Color iconBg;
    Widget iconContent;

    switch (step.status) {
      case _StepStatus.completed:
        iconBg = AppColors.primary;
        iconContent = const Icon(Icons.check, size: 16, color: Colors.white);
        break;
      case _StepStatus.inProgress:
        iconBg = const Color(0xFFFEF3C7);
        iconContent = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFD97706),
          ),
        );
        break;
      case _StepStatus.pending:
        iconBg = const Color(0xFFF1F5F9);
        iconContent = Text(
          step.number,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: step.status == _StepStatus.inProgress
                    ? const Color(0xFFF59E0B)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Center(child: iconContent),
          ),
          const SizedBox(height: 10),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: step.status == _StepStatus.pending
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalStepTile(_TimelineStep step) {
    Color iconBg;
    Widget iconContent;

    switch (step.status) {
      case _StepStatus.completed:
        iconBg = AppColors.primary;
        iconContent = const Icon(Icons.check, size: 16, color: Colors.white);
        break;
      case _StepStatus.inProgress:
        iconBg = const Color(0xFFFEF3C7);
        iconContent = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFD97706),
          ),
        );
        break;
      case _StepStatus.pending:
        iconBg = const Color(0xFFF1F5F9);
        iconContent = Text(
          step.number,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Center(child: iconContent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: step.status == _StepStatus.pending ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.secondary, size: 22),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Une question sur votre demande d\'agrément ?',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Notre cellule de conformité médicale est disponible du lundi au vendredi de 8h à 18h au +228 22 00 00 00 ou par email à conformite@edoctor.tg',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepStatus { completed, inProgress, pending }

class _TimelineStep {
  final String number;
  final String title;
  final String subtitle;
  final _StepStatus status;

  _TimelineStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.status,
  });
}
