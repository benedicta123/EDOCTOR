import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/step_progress_bar.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/server_config_dialog.dart';
import 'register_step2_screen.dart';
import 'login_screen.dart';

class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedCountryCode = '+228';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  bool get _doPasswordsMatch {
    final p1 = _passwordController.text;
    final p2 = _confirmPasswordController.text;
    return p1.isNotEmpty && p2.isNotEmpty && p1 == p2;
  }

  void _goToStep2() {
    if (_formKey.currentState?.validate() ?? false) {
      final fullPhone = '$_selectedCountryCode ${_phoneController.text.trim()}';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RegisterStep2Screen(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _confirmPasswordController.text,
            phone: fullPhone,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête : Logo & Sécurité
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              AppLogo(width: 120, height: 40),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                      Icons.lock_outline_rounded,
                                      size: 13,
                                      color: AppColors.success,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Données sécurisées',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => ServerConfigDialog.show(context),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Icon(
                                    Icons.dns_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Progression Étape 1 sur 2
                      const StepProgressBar(
                        currentStep: 1,
                        title: 'Identité personnelle',
                      ),

                      const SizedBox(height: 20),

                      // Titre & Accroche
                      const Text(
                        'Créons votre compte',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Ça prend moins de 2 minutes',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Champ : Nom complet
                      CustomTextField(
                        label: 'Nom complet',
                        hintText: 'Ex. Koffi Mensah',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Veuillez saisir votre nom complet'
                            : null,
                      ),

                      const SizedBox(height: 14),

                      // Champ : Adresse email
                      CustomTextField(
                        label: 'Adresse email',
                        hintText: 'nom@exemple.tg',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_outline_rounded,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Veuillez saisir votre email';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Format d\'email invalide';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Champ : Mot de passe
                      CustomTextField(
                        label: 'Mot de passe',
                        hintText: 'Minimum 8 caractères',
                        controller: _passwordController,
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Le mot de passe doit faire au moins 8 caractères'
                            : null,
                      ),

                      const SizedBox(height: 14),

                      // Champ : Confirmer le mot de passe
                      CustomTextField(
                        label: 'Confirmer le mot de passe',
                        hintText: 'Répétez votre mot de passe',
                        controller: _confirmPasswordController,
                        isPassword: true,
                        prefixIcon: Icons.lock_reset_rounded,
                        headerRightWidget: _doPasswordsMatch
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.successBorder),
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
                              )
                            : null,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Veuillez confirmer votre mot de passe';
                          }
                          if (v != _passwordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Champ : Téléphone avec indicatif pays
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              'Numéro de téléphone',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                // Sélecteur indicatif pays (Togo / Côte d'Ivoire)
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedCountryCode =
                                          _selectedCountryCode == '+228'
                                              ? '+225'
                                              : '+228';
                                    });
                                  },
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(16),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.horizontal(
                                        left: Radius.circular(16),
                                      ),
                                      border: Border(
                                        right: BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildFlagIcon(_selectedCountryCode),
                                        const SizedBox(width: 6),
                                        Text(
                                          _selectedCountryCode,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          size: 18,
                                          color: AppColors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '90 12 34 56',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text(
                              'Requis pour vos ordonnances et rendez-vous médicaux.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Bas fixe : Bouton Suivant et Lien de connexion
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomButton(
                    text: 'Suivant',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: _goToStep2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Déjà un compte ? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Se connecter',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
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
    );
  }

  Widget _buildFlagIcon(String code) {
    return Container(
      width: 20,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black12),
      ),
      child: code == '+228'
          // Drapeau Togo miniature
          ? Column(
              children: [
                Expanded(child: Container(color: AppColors.togoGreen)),
                Expanded(child: Container(color: AppColors.togoYellow)),
                Expanded(child: Container(color: AppColors.togoGreen)),
              ],
            )
          // Drapeau Côte d'Ivoire
          : Row(
              children: [
                Expanded(child: Container(color: const Color(0xFFFF8200))),
                Expanded(child: Container(color: Colors.white)),
                Expanded(child: Container(color: const Color(0xFF009E60))),
              ],
            ),
    );
  }
}
