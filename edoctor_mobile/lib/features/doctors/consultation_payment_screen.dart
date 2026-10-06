import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/consultation_model.dart';
import 'consultation_screen.dart';

enum PaymentMethodType {
  tmoney,
  flooz,
  card,
}

class ConsultationPaymentScreen extends StatefulWidget {
  final DoctorModel? doctor;
  final ConsultationModel? existingConsultation;

  const ConsultationPaymentScreen({
    super.key,
    this.doctor,
    this.existingConsultation,
  }) : assert(doctor != null || existingConsultation != null,
            'Either doctor or existingConsultation must be provided');

  @override
  State<ConsultationPaymentScreen> createState() =>
      _ConsultationPaymentScreenState();
}

class _ConsultationPaymentScreenState extends State<ConsultationPaymentScreen> {
  late final DoctorModel _doctor;
  PaymentMethodType _selectedMethod = PaymentMethodType.tmoney;
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.doctor != null) {
      _doctor = widget.doctor!;
    } else {
      final c = widget.existingConsultation!;
      _doctor = DoctorModel(
        id: c.doctorId,
        name: c.doctorName.isNotEmpty ? c.doctorName : 'Médecin',
        specialty: 'Téléconsultation',
        consultationFee: c.consultationFee,
        edoctorFee: c.edoctorFee,
        totalAmount: c.totalAmount,
      );
    }
    _loadUserPhone();
  }

  Future<void> _loadUserPhone() async {
    final user = await StorageService.getUser();
    if (user != null && user.phone != null && user.phone!.isNotEmpty) {
      // Nettoyer le préfixe +228 si présent pour affichage direct
      var p = user.phone!.replaceAll('+228', '').replaceAll(' ', '').trim();
      setState(() {
        _phoneController.text = p;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Consultation : existante ou nouvelle demande
      final consultation = widget.existingConsultation ??
          await ApiService.requestConsultation(_doctor.id);

      // 2. Initialisation de la transaction FedaPay
      Map<String, dynamic>? fedapayRes;
      try {
        fedapayRes =
            await ApiService.initiateFedaPayConsultation(consultation.id);
      } catch (e) {
        // En cas d'erreur spécifique sur FedaPay, on relance avec le message
        throw Exception(
            'Erreur lors de l\'initialisation du paiement FedaPay : $e');
      }

      final checkoutUrl = fedapayRes['checkout_url'] as String?;
      final dynamic rawTxId = fedapayRes['transaction_id'];
      final int? transactionId = rawTxId is num
          ? rawTxId.toInt()
          : (rawTxId != null ? int.tryParse(rawTxId.toString()) : null);
      final isSimulated = fedapayRes['simulated'] == true;

      if (!mounted) return;

      // 3. Cas réel : ouverture du lien de paiement FedaPay sécurisé
      if (checkoutUrl != null && !isSimulated) {
        final uri = Uri.parse(checkoutUrl);
        bool opened = false;
        try {
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
        if (!opened) {
          try {
            opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          } catch (_) {
            await launchUrl(uri);
          }
        }

        if (!mounted) return;
        final confirmed = await _showVerificationDialog(transactionId);

        if (confirmed == true) {
          final verifyRes = await ApiService.verifyFedaPayConsultation(
            consultation.id,
            transactionId: transactionId,
          );

          if (verifyRes['is_approved'] == true ||
              verifyRes['status'] == 'paye') {
            _onPaymentSuccess(consultation);
            return;
          } else {
            throw Exception(
                'Le paiement n\'a pas encore été validé sur FedaPay.');
          }
        } else {
          // Annulation par le patient
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else {
        // 4. Cas test / simulation : Affichage de la boîte de validation Mobile Money
        if (!mounted) return;
        final confirmed = await _showSimulationPaymentDialog();

        if (confirmed == true) {
          // Validation de la consultation payée
          await ApiService.payConsultation(
            consultation.id,
            paymentMethod: _selectedMethod == PaymentMethodType.card
                ? 'carte'
                : 'mobile_money',
          );

          _onPaymentSuccess(consultation);
          return;
        } else {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onPaymentSuccess(ConsultationModel consultation) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Paiement validé avec succès (${_doctor.totalAmount.toInt()} FCFA) ! Appel transmis au ${_doctor.name}.',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
      ),
    );

    // Redirection immédiate vers la consultation en direct
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PatientConsultationScreen(consultation: consultation),
      ),
    );
  }

  Future<bool?> _showVerificationDialog(int? transactionId) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_android_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              'Paiement Mobile Money',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La page de paiement FedaPay a été ouverte pour régler ${_doctor.totalAmount.toInt()} FCFA.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Une fois votre paiement validé avec votre code secret Mobile Money, cliquez sur "J\'ai validé mon paiement" ci-dessous pour lancer l\'appel.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'J\'ai validé mon paiement',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSimulationPaymentDialog() {
    final methodLabel = _selectedMethod == PaymentMethodType.tmoney
        ? 'T-Money (Togocom)'
        : _selectedMethod == PaymentMethodType.flooz
            ? 'Moov Money (Flooz)'
            : 'Carte Bancaire';

    final phoneStr = _phoneController.text.trim().isNotEmpty
        ? '+228 ${_phoneController.text.trim()}'
        : 'Numéro de test patient';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.payment_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              'Validation du Paiement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Opérateur : $methodLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ligne : $phoneStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total à débiter :',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_doctor.totalAmount.toInt()} FCFA',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Confirmez-vous le débit pour démarrer la téléconsultation avec le praticien ? Le médecin sera prévenu dès confirmation.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Confirmer le paiement',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Paiement Consultation',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Synthèse du Médecin ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _doctor.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_doctor.specialty}${_doctor.hospitalName != null ? ' • ${_doctor.hospitalName}' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Téléconsultation vidéo directe',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── 2. Détail Financier Transparent ────────────────────
            const Text(
              'Détail des frais',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Honoraires praticien (Hôpital) :',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${_doctor.consultationFee.toInt()} FCFA',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Frais de service eDoctor (10%) :',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${_doctor.edoctorFee.toInt()} FCFA',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total net à payer :',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_doctor.totalAmount.toInt()} FCFA',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 3. Choix du Mode de Paiement ───────────────────────
            const Text(
              'Mode de paiement sécurisé',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            _buildPaymentOption(
              type: PaymentMethodType.tmoney,
              title: 'T-Money (Togocom)',
              subtitle: 'Paiement direct Mobile Money',
              icon: Icons.phone_android_rounded,
              color: const Color(0xFF008751), // Vert Togocom
            ),

            const SizedBox(height: 10),

            _buildPaymentOption(
              type: PaymentMethodType.flooz,
              title: 'Moov Money (Flooz)',
              subtitle: 'Paiement direct Moov Africa',
              icon: Icons.smartphone_rounded,
              color: const Color(0xFFFF6600), // Orange Moov
            ),

            const SizedBox(height: 10),

            _buildPaymentOption(
              type: PaymentMethodType.card,
              title: 'Carte Bancaire (Visa / Mastercard)',
              subtitle: 'Paiement par carte via passerelle FedaPay',
              icon: Icons.credit_card_rounded,
              color: const Color(0xFF1A1F71), // Visa bleu
            ),

            if (_selectedMethod == PaymentMethodType.tmoney ||
                _selectedMethod == PaymentMethodType.flooz) ...[
              const SizedBox(height: 16),
              const Text(
                'Numéro de compte Mobile Money',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    prefixIcon: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+228',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            height: 20,
                            child: VerticalDivider(
                              width: 1,
                              color: AppColors.border,
                            ),
                          ),
                        ],
                      ),
                    ),
                    hintText: '90 12 34 56',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ─── 4. Bouton de Paiement ──────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Sécurisation du paiement...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Payer ${_doctor.totalAmount.toInt()} FCFA',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 14),

            // Mention de réassurance
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined,
                    size: 15, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text(
                  'Passerelle sécurisée FedaPay • Clôture sous contrôle DG',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required PaymentMethodType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMethod == type;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = type;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
