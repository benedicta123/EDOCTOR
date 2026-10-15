import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Contrôleurs
  late final TextEditingController _emailController;
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();

  // État du flux (1: Demande, 2: Code OTP, 3: Nouveau mot de passe, 4: Succès)
  int _currentStep = 1;
  bool _isLoading = false;
  String? _resetToken;
  String? _debugOtp;
  String? _otpWarningMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Étape 1 : Demande OTP
  Future<void> _handleRequestOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Veuillez renseigner une adresse email valide.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.forgotPassword(email);
      if (!mounted) return;

      setState(() {
        _currentStep = 2;
        _otpWarningMessage = null;
        _debugOtp = res['debug_otp'] as String?;
        if (_debugOtp != null) {
          _otpController.text = _debugOtp!;
        }
      });
      _showSuccess('Code de vérification envoyé à $email');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Étape 2 : Validation OTP
  Future<void> _handleVerifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError('Veuillez saisir le code complet à 6 chiffres.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await ApiService.verifyPasswordOtp(email: email, otp: otp);
      if (!mounted) return;

      setState(() {
        _resetToken = token;
        _otpWarningMessage = null;
        _currentStep = 3;
      });
      _showSuccess('Code vérifié avec succès. Définissez votre nouveau mot de passe.');
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() => _otpWarningMessage = msg);
      _showError(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Étape 3 : Réinitialisation
  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;
    final pwdConfirm = _passwordConfirmController.text;

    if (pwd.length < 8) {
      _showError('Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (pwd != pwdConfirm) {
      _showError('La confirmation ne correspond pas au mot de passe.');
      return;
    }
    if (_resetToken == null) {
      _showError('Session expirée. Veuillez recommencer.');
      setState(() => _currentStep = 1);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final msg = await ApiService.resetPassword(
        email: email,
        resetToken: _resetToken!,
        password: pwd,
        passwordConfirmation: pwdConfirm,
      );
      if (!mounted) return;

      setState(() => _currentStep = 4);
      _showSuccess(msg);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Récupération de compte',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryLight, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Étape 1 : Demande OTP
              if (_currentStep == 1) _buildStep1Email(),

              // Étape 2 : Vérification OTP
              if (_currentStep == 2) _buildStep2Otp(),

              // Étape 3 : Nouveau mot de passe
              if (_currentStep == 3) _buildStep3NewPassword(),

              // Étape 4 : Succès
              if (_currentStep == 4) _buildStep4Success(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Email() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mot de passe oublié ?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Indiquez votre adresse email associée à votre compte eDoctor. Nous vous enverrons un code de sécurité à 6 chiffres.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        CustomTextField(
          label: 'Adresse email',
          hintText: 'patient@exemple.tg',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline_rounded,
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: 'Recevoir le code de vérification',
          isLoading: _isLoading,
          onPressed: _handleRequestOtp,
        ),
      ],
    );
  }

  Widget _buildStep2Otp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vérification du code',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Saisissez le code à 6 chiffres envoyé à\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        CustomTextField(
          label: 'Code de sécurité (6 chiffres)',
          hintText: '123456',
          controller: _otpController,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.pin_rounded,
        ),
        if (_debugOtp != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Code de test généré : $_debugOtp',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_otpWarningMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFB4AB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFBA1A1A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _otpWarningMessage!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFBA1A1A),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        CustomButton(
          text: 'Valider le code',
          isLoading: _isLoading,
          onPressed: _handleVerifyOtp,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : _handleRequestOtp,
          child: const Text(
            'Renvoyer un nouveau code',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3NewPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nouveau mot de passe',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choisissez un nouveau mot de passe robuste d\'au moins 8 caractères. Toutes vos sessions précédentes seront révoquées pour votre sécurité.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        CustomTextField(
          label: 'Nouveau mot de passe',
          hintText: 'Minimum 8 caractères',
          controller: _passwordController,
          isPassword: true,
          prefixIcon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Confirmer le mot de passe',
          hintText: 'Répétez le mot de passe',
          controller: _passwordConfirmController,
          isPassword: true,
          prefixIcon: Icons.lock_clock_outlined,
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: 'Mettre à jour mon mot de passe',
          isLoading: _isLoading,
          onPressed: _handleResetPassword,
        ),
      ],
    );
  }

  Widget _buildStep4Success() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.verified_user_rounded,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        const Text(
          'Mot de passe réinitialisé !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Votre compte a été sécurisé et votre nouveau mot de passe est actif. Vous pouvez dès à présent vous connecter.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        CustomButton(
          text: 'Retourner à la connexion',
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
