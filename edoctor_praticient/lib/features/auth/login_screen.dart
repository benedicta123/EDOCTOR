import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../doctor/doctor_dashboard.dart';
import '../hospital/hospital_dashboard.dart';
import 'hospital_register_step1_screen.dart';

/// Connexion unique — l'API renvoie le rôle, on redirige médecin vs admin hôpital.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await ApiService.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      showMsg(context, 'Bienvenue ${doctorDisplay(user.name)}');
      final Widget next = user.isDoctor
          ? const DoctorDashboard()
          : const HospitalDashboard();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return isWide
              ? _WideLayout(
                  formKey: _formKey,
                  email: _email,
                  password: _password,
                  loading: _loading,
                  obscure: _obscure,
                  rememberMe: _rememberMe,
                  fadeAnim: _fadeAnim,
                  slideAnim: _slideAnim,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  onToggleRemember: (v) =>
                      setState(() => _rememberMe = v ?? false),
                  onSubmit: _submit,
                )
              : _NarrowLayout(
                  formKey: _formKey,
                  email: _email,
                  password: _password,
                  loading: _loading,
                  obscure: _obscure,
                  rememberMe: _rememberMe,
                  fadeAnim: _fadeAnim,
                  slideAnim: _slideAnim,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  onToggleRemember: (v) =>
                      setState(() => _rememberMe = v ?? false),
                  onSubmit: _submit,
                );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WIDE LAYOUT (≥ 900px) — split hero + card
// ─────────────────────────────────────────────
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.formKey,
    required this.email,
    required this.password,
    required this.loading,
    required this.obscure,
    required this.rememberMe,
    required this.fadeAnim,
    required this.slideAnim,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool loading;
  final bool obscure;
  final bool rememberMe;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Côté gauche : hero médical ──
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D1E30),
                  Color(0xFF132A45),
                  Color(0xFF1A3558),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Motifs décoratifs médicaux en arrière-plan
                Positioned(
                  top: -60,
                  right: -60,
                  child: _MedicalCrossDecor(size: 300, opacity: 0.04),
                ),
                Positioned(
                  bottom: -80,
                  left: -40,
                  child: _MedicalCrossDecor(size: 400, opacity: 0.03),
                ),
                Positioned(
                  top: 200,
                  left: -30,
                  child: _MedicalCrossDecor(size: 180, opacity: 0.05),
                ),
                // Contenu hero
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 64,
                    vertical: 56,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/images/logo_blanc.png',
                          width: 270,
                          height: 92,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                      ),

                      const Spacer(),

                      // Badge "Accès Personnel Autorisé"
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 13,
                              color: AppColors.primaryLight,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Accès Personnels Autorisés',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Titre principal
                      const Text(
                        'Un accès sécurisé à vos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        'services médicaux.',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Description
                      const Text(
                        'Gérez les dossiers patients, suivez les consultations et rédigez les ordonnances numériques depuis une plateforme clinique unifiée.',
                        style: TextStyle(
                          color: Color(0xFF8BACC8),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // 3 badges médicaux
                      const Row(
                        children: [
                          _HeroBadge(
                            icon: Icons.folder_shared_rounded,
                            label: 'Dossiers Patients',
                          ),
                          SizedBox(width: 12),
                          _HeroBadge(
                            icon: Icons.medication_rounded,
                            label: 'Ordonnances Numériques',
                          ),
                          SizedBox(width: 12),
                          _HeroBadge(
                            icon: Icons.video_call_rounded,
                            label: 'Téléconsultation',
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Footer copyright
                      const Text(
                        '© 2026 eDoctor Santé. Tous droits réservés.',
                        style: TextStyle(
                          color: Color(0xFF4A6A8A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Côté droit : carte de connexion ──
        Expanded(
          flex: 1,
          child: Container(
            color: AppColors.background,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: FadeTransition(
                  opacity: fadeAnim,
                  child: SlideTransition(
                    position: slideAnim,
                    child: _LoginCard(
                      formKey: formKey,
                      email: email,
                      password: password,
                      loading: loading,
                      obscure: obscure,
                      rememberMe: rememberMe,
                      onToggleObscure: onToggleObscure,
                      onToggleRemember: onToggleRemember,
                      onSubmit: onSubmit,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// NARROW LAYOUT (< 900px) — carte centrée
// ─────────────────────────────────────────────
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.formKey,
    required this.email,
    required this.password,
    required this.loading,
    required this.obscure,
    required this.rememberMe,
    required this.fadeAnim,
    required this.slideAnim,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool loading;
  final bool obscure;
  final bool rememberMe;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1E30), Color(0xFF132A45), AppColors.background],
          stops: [0.0, 0.3, 0.6],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: slideAnim,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _LoginCard(
                  formKey: formKey,
                  email: email,
                  password: password,
                  loading: loading,
                  obscure: obscure,
                  rememberMe: rememberMe,
                  onToggleObscure: onToggleObscure,
                  onToggleRemember: onToggleRemember,
                  onSubmit: onSubmit,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CARTE DE CONNEXION (partagée wide + narrow)
// ─────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.loading,
    required this.obscure,
    required this.rememberMe,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool loading;
  final bool obscure;
  final bool rememberMe;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge "Système opérationnel"
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Système opérationnel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Logo officiel eDoctor
              Center(
                child: Image.asset(
                  'assets/images/edoctor_logo.png',
                  width: 250,
                  height: 78,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 10),
              const Text(
                'Accès Médical Sécurisé · Espace Clinique',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 28),

              // Champ Email
              _FieldLabel(label: 'Email professionnel'),
              const SizedBox(height: 6),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Email invalide' : null,
                decoration: const InputDecoration(
                  hintText: 'docteur@hopital.tg',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Champ Mot de passe
              _FieldLabel(label: 'Mot de passe'),
              const SizedBox(height: 6),
              TextFormField(
                controller: password,
                obscureText: obscure,
                validator: (v) =>
                    (v == null || v.length < 8) ? '8 caractères minimum' : null,
                decoration: InputDecoration(
                  hintText: '••••••••',
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
                    onPressed: onToggleObscure,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // "Se souvenir" + "Mot de passe oublié ?"
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: rememberMe,
                      onChanged: onToggleRemember,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Se souvenir',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bouton CTA
              ElevatedButton(
                onPressed: loading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: loading
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
                          Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              // 3 micro-badges médicaux
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MicroBadge(
                    icon: Icons.local_hospital_outlined,
                    label: 'CHU Partenaire',
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 14, color: AppColors.border),
                  const SizedBox(width: 12),
                  _MicroBadge(
                    icon: Icons.medical_services_outlined,
                    label: 'Médecins Certifiés',
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 14, color: AppColors.border),
                  const SizedBox(width: 12),
                  _MicroBadge(
                    icon: Icons.folder_shared_outlined,
                    label: 'Dossiers Sécurisés',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Divider
              const Divider(height: 1),

              const SizedBox(height: 16),

              // Lien inscription hôpital
              Center(
                child: Builder(
                  builder: (ctx) {
                    return TextButton(
                      onPressed: () => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) => const HospitalRegisterStep1Screen(),
                        ),
                      ),
                      child: const Text(
                        'Inscrire mon hôpital (créer un compte admin)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Footer légal
              const Text(
                'En vous connectant, vous acceptez les Conditions d\'utilisation médicale & la Politique de confidentialité des données patients.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroBadge extends StatelessWidget {
  const _MicroBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MedicalCrossDecor extends StatelessWidget {
  const _MedicalCrossDecor({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _CrossPainter()),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.1, h * 0.35, w * 0.8, h * 0.3),
        const Radius.circular(8),
      ),
      paint,
    );
    // Vertical bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.35, h * 0.1, w * 0.3, h * 0.8),
        const Radius.circular(8),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
