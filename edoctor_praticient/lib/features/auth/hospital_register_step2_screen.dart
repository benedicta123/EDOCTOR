import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../hospital/hospital_dashboard.dart';

/// Étape 2/2 — Création du compte administrateur de l'hôpital.
class HospitalRegisterStep2Screen extends StatefulWidget {
  const HospitalRegisterStep2Screen({
    super.key,
    required this.hospitalName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.licenseNumber,
    required this.officialEmail,
    required this.hospitalPhone,
  });

  final String hospitalName;
  final String address;
  final double latitude;
  final double longitude;
  final String licenseNumber;
  final String officialEmail;
  final String hospitalPhone;

  @override
  State<HospitalRegisterStep2Screen> createState() =>
      _HospitalRegisterStep2ScreenState();
}

class _HospitalRegisterStep2ScreenState
    extends State<HospitalRegisterStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    _password.addListener(_refresh);
    _password2.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  bool get _passwordsMatch {
    final p1 = _password.text;
    final p2 = _password2.text;
    return p1.isNotEmpty && p2.isNotEmpty && p1 == p2;
  }

  @override
  void dispose() {
    _adminName.dispose();
    _adminEmail.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ApiService.registerHospital(
        hospitalName: widget.hospitalName,
        address: widget.address,
        latitude: widget.latitude,
        longitude: widget.longitude,
        licenseNumber: widget.licenseNumber,
        officialEmail: widget.officialEmail,
        hospitalPhone: widget.hospitalPhone,
        adminName: _adminName.text.trim(),
        adminEmail: _adminEmail.text.trim(),
        password: _password.text,
        passwordConfirmation: _password2.text,
      );
      if (!mounted) return;
      showMsg(context, 'Hôpital inscrit avec succès. Bienvenue !');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HospitalDashboard()),
        (r) => false,
      );
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Contenu défilable
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête
                          Row(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.local_hospital_rounded,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'eDoctor Praticien',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Compte sécurisé',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Barre de progression Étape 2/2
                          _StepProgressBar(currentStep: 2),

                          const SizedBox(height: 16),

                          // Titre
                          const Text(
                            'Compte administrateur',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Identifiants du responsable médical',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Récapitulatif hôpital
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.apartment_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.hospitalName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.address,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    '✓ Étape 1',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Section : Identité de l'administrateur
                          _SectionHeader(
                            icon: Icons.manage_accounts_rounded,
                            title: 'Identité du responsable',
                          ),
                          const SizedBox(height: 12),

                          _ResponsivePair(
                            first: CustomTextField(
                              controller: _adminName,
                              label: 'Nom complet du directeur / responsable',
                              hint: 'Dr. Kouamé Jean-Baptiste',
                              icon: Icons.person_outline,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Requis' : null,
                            ),
                            second: CustomTextField(
                              controller: _adminEmail,
                              label: 'Email du compte administrateur',
                              hint: 'admin@chu-lome.tg',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Email invalide'
                                  : null,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Section : Mot de passe
                          _SectionHeader(
                            icon: Icons.lock_outline_rounded,
                            title: 'Sécurité du compte',
                          ),
                          const SizedBox(height: 12),

                          _ResponsivePair(
                            first: _PasswordField(
                              controller: _password,
                              label: 'Mot de passe',
                              hint: 'Minimum 8 caractères',
                              obscure: _obscure1,
                              onToggle: () =>
                                  setState(() => _obscure1 = !_obscure1),
                              validator: (v) => v == null || v.length < 8
                                  ? '8 caractères minimum'
                                  : null,
                            ),
                            second: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Confirmer le mot de passe',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_passwordsMatch)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.successLight,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.success.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 12,
                                              color: AppColors.success,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Mots de passe identiques',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _password2,
                                  obscureText: _obscure2,
                                  validator: (v) => v != _password.text
                                      ? 'Mots de passe non identiques'
                                      : null,
                                  decoration: InputDecoration(
                                    hintText: 'Répétez votre mot de passe',
                                    prefixIcon: const Icon(
                                      Icons.lock_reset_rounded,
                                      color: AppColors.primary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure2
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppColors.textMuted,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscure2 = !_obscure2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Note légale
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'L\'inscription est soumise à la vérification de votre agrément par l\'équipe eDoctor. Vous recevrez une confirmation par email sous 48h.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.warning,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bas fixe
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.8),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Inscrire l\'hôpital',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text(
                          'Retour à l\'étape précédente',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets locaux ─────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppColors.primary,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StepDot(
              stepNumber: 1,
              active: currentStep >= 1,
              done: currentStep > 1,
            ),
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: currentStep > 1 ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
            _StepDot(
              stepNumber: 2,
              active: currentStep >= 2,
              done: currentStep > 2,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Établissement',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: currentStep == 1
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: currentStep == 1
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Compte Admin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: currentStep == 2
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: currentStep == 2
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.stepNumber,
    required this.active,
    required this.done,
  });
  final int stepNumber;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.border,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
            : Text(
                '$stepNumber',
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
