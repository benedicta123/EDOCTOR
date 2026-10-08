import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import 'verification_pending_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      // 1. Connexion standard via l'API
      final user = await ApiService.login(
        email: email,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (!user.isPharmacist) {
        throw Exception(
          'Ce compte n\'a pas les droits d\'accès à l\'espace Pharmacie (rôle détecté : ${user.role}).',
        );
      }

      // 2. Vérifier le statut d'agrément de l'officine
      try {
        final pharmacy = await ApiService.getMyPharmacy();
        if (pharmacy.isPending) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => VerificationPendingScreen(
                pharmacyName: pharmacy.name,
                pharmacistName: user.name,
                orderNumber: pharmacy.orderNumber,
                referenceId: pharmacy.referenceId,
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // En cas d'erreur ou d'officine non trouvée, continuer le flux
      }

      // Officine agréée et active : nettoyer les données de dossier en attente local
      await StorageService.clearPendingApplication();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.outOfStock,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showTrackApplicationDialog() async {
    final pendingApp = await StorageService.getPendingApplication();
    if (!mounted) return;

    final controller = TextEditingController(
      text: pendingApp != null ? (pendingApp['referenceId'] ?? pendingApp['email'] ?? '') : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        String? errorMessage;
        bool isChecking = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleLookup() async {
              final query = controller.text.trim();
              if (query.isEmpty) {
                setDialogState(() {
                  errorMessage = 'Veuillez saisir une adresse email ou un numéro de référence.';
                });
                return;
              }

              setDialogState(() {
                isChecking = true;
                errorMessage = null;
              });

              try {
                final result = await ApiService.trackPharmacyStatus(query);

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();

                final status = result['status'] as String? ?? 'en_attente';

                if (status == 'verifie') {
                  _emailController.text = result['official_email'] ?? query;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Votre officine est déjà agréée et active ! Connectez-vous avec votre mot de passe.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.inStock,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 4),
                    ),
                  );
                  return;
                }

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VerificationPendingScreen(
                      pharmacyName: result['pharmacy_name'] as String?,
                      pharmacistName: result['pharmacist_name'] as String?,
                      orderNumber: result['order_number'] as String?,
                      referenceId: result['reference_id'] as String?,
                    ),
                  ),
                );
              } catch (e) {
                if (!ctx.mounted) return;
                setDialogState(() {
                  isChecking = false;
                  errorMessage = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.track_changes_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Suivre mon dossier d\'agrément',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.secondary),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saisissez l\'adresse email ou le numéro de référence (ex: KYP-2026-TG...) pour interroger la base de données eDoctor.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    onSubmitted: (_) => handleLookup(),
                    decoration: InputDecoration(
                      hintText: 'Email ou Réf: KYP-2026-...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      errorText: errorMessage,
                    ),
                  ),
                  if (pendingApp != null && errorMessage == null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dossier local : ${pendingApp['pharmacyName'] ?? 'Officine'} (${pendingApp['referenceId'] ?? ''})',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.primaryHover, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isChecking ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Fermer', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: isChecking ? null : handleLookup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Consulter mon statut'),
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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Cercle organique stylisé en haut à gauche (comme sur la maquette GovPortal)
          Positioned(
            top: -90,
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

          // 2. Halo lumineux diffus (blur glow intense) directement derrière la zone de la carte de connexion
          Positioned(
            top: isDesktop ? 80 : 260,
            right: isDesktop ? size.width * 0.05 : -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(
                width: 520,
                height: 520,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryLight.withValues(alpha: 0.38),
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.background.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Grand cercle doux en bas au centre / droite (comme sur la maquette GovPortal)
          Positioned(
            bottom: -110,
            left: isDesktop ? size.width * 0.32 : size.width * 0.15,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEFF8EC).withValues(alpha: 0.85),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 2,
                ),
              ),
            ),
          ),

          // Contenu principal scrollable
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : 20,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    children: [
                      // Header supérieur avec Logo et Badge d'état opérationnel
                      _buildTopHeader(),

                      SizedBox(height: isDesktop ? 60 : 32),

                      // Layout principal en 2 colonnes sur desktop, empilé sur mobile
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Colonne gauche : Hero & Badges médicaux
                            Expanded(
                              flex: 11,
                              child: _buildLeftHero(),
                            ),
                            const SizedBox(width: 48),
                            // Colonne droite : Carte de connexion flottante
                            Expanded(
                              flex: 9,
                              child: _buildLoginCard(),
                            ),
                          ],
                        )
                      else ...[
                        _buildLeftHero(isMobile: true),
                        const SizedBox(height: 36),
                        _buildLoginCard(),
                      ],

                      SizedBox(height: isDesktop ? 60 : 36),

                      // Footer en bas
                      _buildFooter(isDesktop),
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

  // ─── Header supérieur ───────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo officiel eDoctor & Badge Espace Pharmacie
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
            Container(
              height: 24,
              width: 1,
              color: const Color(0xFFCBD5E1),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: const Text(
                'PHARMACIE',
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

        // Badge « Système Opérationnel »
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Système Opérationnel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Colonne gauche Hero ────────────────────────────────────────────────────
  Widget _buildLeftHero({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Micro-badge d'accès avec blur
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Accès Réservé aux Professionnels de Santé',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryHover,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Grand titre principal avec mot clé en orange
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: isMobile ? 30 : 42,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.15,
              letterSpacing: -0.8,
              fontFamily: 'Plus Jakarta Sans',
            ),
            children: const [
              TextSpan(text: 'Une passerelle sécurisée pour '),
              TextSpan(
                text: 'la dispensation pharmaceutique.',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Texte d'accompagnement médical
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const Text(
            'Connectez-vous pour délivrer les ordonnances numériques, actualiser vos stocks en temps réel et sécuriser le parcours des patients à travers le Togo.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 36),

        // 3 Micro-cartes médicales horizontales (comme sur le mockup)
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _buildFeatureCard(
              icon: Icons.verified_outlined,
              title: 'Ordre National',
              subtitle: 'Officine Agréée',
            ),
            _buildFeatureCard(
              icon: Icons.receipt_long_outlined,
              title: 'Ordonnances',
              subtitle: 'Dispensation Sécurisée',
            ),
            _buildFeatureCard(
              icon: Icons.inventory_2_outlined,
              title: 'Stocks Directs',
              subtitle: 'Mise à jour en Temps Réel',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Carte de connexion flottante ───────────────────────────────────────────
  Widget _buildLoginCard() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Effet d'accentuation en arrière-plan (rectangle vert incliné)
            Positioned(
              top: -12,
              right: 28,
              child: Transform.rotate(
                angle: 0.08,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Carte blanche principale avec effet verre dépoli & blur
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 38),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo officiel eDoctor
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                        height: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.local_pharmacy_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Titres de la carte
                    const Text(
                      'Portail Pharmacie',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dispensation & Gestion des Stocks Sécurisée',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Champ Nom d'utilisateur / Email
                    const Text(
                      'Adresse e-mail professionnelle',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'pharmacien@officine.tg',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        fillColor: const Color(0xFFFAFBFC),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Veuillez saisir votre adresse e-mail';
                        }
                        if (!val.contains('@')) {
                          return 'Adresse e-mail invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Champ Mot de passe
                    const Text(
                      'Mot de passe',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '••••••••••••',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        fillColor: const Color(0xFFFAFBFC),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Veuillez saisir votre mot de passe';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Ligne "Se souvenir de moi" et "Mot de passe oublié ?"
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) => setState(() => _rememberMe = val ?? true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Se souvenir de moi',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Veuillez contacter le support eDoctor pour réinitialiser vos accès.'),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Bouton de connexion officiel (Orange avec flèche)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Se connecter à l\'officine',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Séparateur ou inscription
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'OU',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Bouton Inscription Officine
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/register'),
                      icon: const Icon(Icons.app_registration_rounded, size: 18, color: AppColors.secondary),
                      label: const Text(
                        'Inscrire une nouvelle officine',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.secondary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bouton Suivi de dossier d'agrément
                    Center(
                      child: TextButton.icon(
                        onPressed: _showTrackApplicationDialog,
                        icon: const Icon(Icons.track_changes_rounded, size: 16, color: AppColors.primary),
                        label: const Text(
                          'Déjà inscrit ? Suivre l\'état d\'un dossier d\'agrément',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryHover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Micro-badges de sécurité et réassurance
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Text(
                              'Connexion Sécurisée',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 13, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Text(
                              'Données Protégées',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Mention légale sous la carte
                    const Text(
                      'En vous connectant, vous acceptez la Charte de Déontologie & Sécurité eDoctor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        height: 1.3,
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);
}

  // ─── Footer en bas de page ──────────────────────────────────────────────────
  Widget _buildFooter(bool isDesktop) {
    if (isDesktop) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© 2026 eDoctor Pharmacie • République Togolaise. Tous droits réservés.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Text(
            'Plateforme Nationale de Santé Numérique',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    return const Column(
      children: [
        Text(
          '© 2026 eDoctor Pharmacie • République Togolaise',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        SizedBox(height: 4),
        Text(
          'Plateforme Nationale de Santé Numérique',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
