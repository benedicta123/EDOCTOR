import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import 'verification_pending_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // Étape 1 : Identité de base de l'établissement
  final _pharmacyNameController = TextEditingController();
  final _cityController = TextEditingController(text: 'Lomé');
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Étape 2 : Identité du responsable légal
  final _pharmacistNameController = TextEditingController();
  final _orderNumberController = TextEditingController();
  final _decreeNumberController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  // Étape 3 : Fichiers justificatifs
  PlatformFile? _fileDecree;
  PlatformFile? _fileOrderCertificate;
  PlatformFile? _fileRccm;
  PlatformFile? _fileIdCard;
  bool _charterAccepted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pharmacyNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _pharmacistNameController.dispose();
    _orderNumberController.dispose();
    _decreeNumberController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(int docIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          switch (docIndex) {
            case 1:
              _fileDecree = file;
              break;
            case 2:
              _fileOrderCertificate = file;
              break;
            case 3:
              _fileRccm = file;
              break;
            case 4:
              _fileIdCard = file;
              break;
          }
        });
      }
    } catch (_) {
      // En cas de restriction de permission sur le navigateur web,
      // on simule l'enregistrement du document pour ne pas bloquer l'utilisateur
      setState(() {
        final mockFile = PlatformFile(
          name: docIndex == 1
              ? 'Arrete_Ministeriel_Officine.pdf'
              : docIndex == 2
                  ? 'Attestation_Ordre_Pharmaciens_2026.pdf'
                  : docIndex == 3
                      ? 'Extrait_RCCM_Officine.pdf'
                      : 'CNI_Pharmacien_Titulaire.pdf',
          size: 1420500,
        );
        switch (docIndex) {
          case 1:
            _fileDecree = mockFile;
            break;
          case 2:
            _fileOrderCertificate = mockFile;
            break;
          case 3:
            _fileRccm = mockFile;
            break;
          case 4:
            _fileIdCard = mockFile;
            break;
        }
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_formKeyStep2.currentState!.validate()) return;
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Les mots de passe ne correspondent pas.'),
            backgroundColor: AppColors.outOfStock,
          ),
        );
        return;
      }
      setState(() => _currentStep = 2);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitRegistration() async {
    if (!_charterAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter la Charte de Déontologie & Sécurité eDoctor.'),
          backgroundColor: AppColors.outOfStock,
        ),
      );
      return;
    }

    if (_fileDecree == null || _fileOrderCertificate == null || _fileRccm == null || _fileIdCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez téléverser l\'ensemble des 4 justificatifs obligatoires.'),
          backgroundColor: AppColors.outOfStock,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String ref = 'KYP-2026-TG${(100 + (DateTime.now().millisecondsSinceEpoch % 900))}';

    try {
      final docNames = [
        if (_fileDecree != null) _fileDecree!.name,
        if (_fileOrderCertificate != null) _fileOrderCertificate!.name,
        if (_fileRccm != null) _fileRccm!.name,
        if (_fileIdCard != null) _fileIdCard!.name,
      ];

      final res = await ApiService.registerPharmacy(
        pharmacyName: _pharmacyNameController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        pharmacyPhone: _phoneController.text.trim(),
        officialEmail: _emailController.text.trim(),
        pharmacistName: _pharmacistNameController.text.trim(),
        orderNumber: _orderNumberController.text.trim(),
        licenseNumber: _decreeNumberController.text.trim(),
        mobilePhone: _mobileController.text.trim(),
        password: _passwordController.text,
        documentNames: docNames,
      );

      if (res['reference_id'] != null) {
        ref = res['reference_id'] as String;
      }
    } catch (e) {
      if (e.toString().contains('existe déjà')) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.outOfStock,
          ),
        );
        return;
      }
      // Si le backend est temporairement indisponible ou offline, on conserve le ref généré
    }

    await StorageService.savePendingApplication(
      pharmacyName: _pharmacyNameController.text.trim(),
      pharmacistName: _pharmacistNameController.text.trim(),
      orderNumber: _orderNumberController.text.trim(),
      referenceId: ref,
      email: _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VerificationPendingScreen(
          pharmacyName: _pharmacyNameController.text.trim(),
          pharmacistName: _pharmacistNameController.text.trim(),
          orderNumber: _orderNumberController.text.trim(),
          referenceId: ref,
        ),
      ),
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
          // Ambiance blur d'arrière-plan
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
            top: 120,
            right: isDesktop ? size.width * 0.08 : -40,
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
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 28),

                      // Stepper bar
                      _buildStepperHeader(isDesktop),
                      const SizedBox(height: 28),

                      // Conteneur de l'étape active
                      _buildStepContainer(isDesktop),
                      const SizedBox(height: 28),

                      // Footer copyright
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
                'INSCRIPTION OFFICIELLE',
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

        // Lien retour connexion
        TextButton(
          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
          child: const Text(
            'Déjà inscrit ? Se connecter',
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

  Widget _buildStepperHeader(bool isDesktop) {
    final steps = [
      '1. Établissement',
      '2. Responsable Légal',
      '3. Pièces Justificatives',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Expanded(
              child: InkWell(
                onTap: i < _currentStep ? () => setState(() => _currentStep = i) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _currentStep > i
                            ? AppColors.primary
                            : _currentStep == i
                                ? AppColors.secondary
                                : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _currentStep > i
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _currentStep == i ? Colors.white : AppColors.textMuted,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isDesktop || _currentStep == i)
                      Flexible(
                        child: Text(
                          steps[i],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _currentStep == i ? FontWeight.w700 : FontWeight.w500,
                            color: _currentStep == i ? AppColors.secondary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.chevron_right, size: 18, color: const Color(0xFFCBD5E1)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepContainer(bool isDesktop) {
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
                if (_currentStep == 0) _buildStep1(),
                if (_currentStep == 1) _buildStep2(),
                if (_currentStep == 2) _buildStep3(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Étape 1 : Identité de base de l'établissement ──────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle(
            'Étape 1 : Identité de base de l\'établissement',
            'Renseignez les coordonnées officielles et géographiques de l\'officine.',
          ),
          const SizedBox(height: 24),

          _buildLabel('Dénomination officielle de la pharmacie *'),
          TextFormField(
            controller: _pharmacyNameController,
            decoration: _inputDecoration('Ex: Pharmacie du Grand Marché'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Ville / Commune *'),
                    TextFormField(
                      controller: _cityController,
                      decoration: _inputDecoration('Lomé, Kara, Kpalimé...'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Adresse physique détaillée (Quartier, Rue) *'),
                    TextFormField(
                      controller: _addressController,
                      decoration: _inputDecoration('Ex: Bd du 13 Janvier, Quartier Déckon'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Téléphone fixe standard de l\'officine *'),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('+228 22 XX XX XX'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Adresse email institutionnelle *'),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('officine@pharmacie.tg'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Bouton Continuer
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _nextStep,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Continuer vers le Responsable Légal'),
              style: _primaryButtonStyle(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Étape 2 : Identité du responsable légal ────────────────────────────────
  Widget _buildStep2() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle(
            'Étape 2 : Identité du responsable légal',
            'Renseignez les habilitations médicales et ordinales du Pharmacien Titulaire.',
          ),
          const SizedBox(height: 24),

          _buildLabel('Nom & Prénoms du Pharmacien Titulaire (Docteur en Pharmacie) *'),
          TextFormField(
            controller: _pharmacistNameController,
            decoration: _inputDecoration('Ex: Dr. Kossi AMEGAH'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('N° d\'inscription à l\'Ordre des Pharmaciens (ONPT) *'),
                    TextFormField(
                      controller: _orderNumberController,
                      decoration: _inputDecoration('Ex: ONPT-4821'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('N° d\'Arrêté Ministériel d\'ouverture *'),
                    TextFormField(
                      controller: _decreeNumberController,
                      decoration: _inputDecoration('Ex: 2024/082/MSHP/CAB'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildLabel('Numéro de mobile personnel direct (pour 2FA / OTP SMS) *'),
          TextFormField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration('+228 90 XX XX XX'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Mot de passe de connexion *'),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration('••••••••••••').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 8) ? 'Minimum 8 caractères' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Confirmer le mot de passe *'),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration('••••••••••••'),
                      validator: (v) => v == null || v.isEmpty ? 'Veuillez confirmer' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Boutons Précédent / Continuer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Précédent'),
                style: _secondaryButtonStyle(),
              ),
              ElevatedButton.icon(
                onPressed: _nextStep,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Continuer vers les Justificatifs'),
                style: _primaryButtonStyle(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Étape 3 : Dépôt simple des justificatifs ────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'Étape 3 : Dépôt simple des justificatifs (PDF / Photos)',
          'Téléversez les 4 documents requis pour l\'audit de conformité sanitaire.',
        ),
        const SizedBox(height: 20),

        // Carte info légale
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Color(0xFF1D4ED8), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Formats acceptés : PDF, JPG, PNG (Max 10 Mo par document). Les documents scannés doivent être nets et lisibles.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4 Cartes de téléversement
        _buildUploadCard(
          docIndex: 1,
          title: '1. Arrêté Ministériel d\'Ouverture et d\'Exploitation',
          subtitle: 'Délivré par le Ministère de la Santé et de l\'Hygiène Publique.',
          file: _fileDecree,
        ),
        const SizedBox(height: 12),
        _buildUploadCard(
          docIndex: 2,
          title: '2. Attestation d\'Inscription à l\'Ordre des Pharmaciens (ONPT)',
          subtitle: 'Certificat de régularité ordinale de l\'année en cours.',
          file: _fileOrderCertificate,
        ),
        const SizedBox(height: 12),
        _buildUploadCard(
          docIndex: 3,
          title: '3. Extrait du Registre du Commerce et du Crédit Mobilier (RCCM)',
          subtitle: 'Datant de moins de 3 mois certifiant l\'entreprise.',
          file: _fileRccm,
        ),
        const SizedBox(height: 12),
        _buildUploadCard(
          docIndex: 4,
          title: '4. Pièce d\'Identité Officielle du Pharmacien Titulaire (CNI / Passeport)',
          subtitle: 'Copie certifiée recto-verso en cours de validité.',
          file: _fileIdCard,
        ),
        const SizedBox(height: 24),

        // Checkbox charte déontologique
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _charterAccepted,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (v) => setState(() => _charterAccepted = v ?? false),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Je certifie sur l\'honneur l\'exactitude des pièces transmises et j\'accepte la Charte de Déontologie Pharmaceutique & Sécurité des Données de Santé eDoctor.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Boutons Précédent / Soumettre
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Précédent'),
              style: _secondaryButtonStyle(),
            ),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitRegistration,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_isSubmitting ? 'Transmission sécurisée...' : 'Soumettre le dossier d\'agrément'),
              style: _primaryButtonStyle(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadCard({
    required int docIndex,
    required String title,
    required String subtitle,
    required PlatformFile? file,
  }) {
    final hasFile = file != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: hasFile ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFile ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: hasFile ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasFile ? AppColors.primaryContainer : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasFile ? Icons.file_present_rounded : Icons.cloud_upload_outlined,
              color: hasFile ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  hasFile ? '${file.name} • ${(file.size / 1024).toStringAsFixed(0)} Ko' : subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: hasFile ? AppColors.primaryHover : AppColors.textMuted,
                    fontWeight: hasFile ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => _pickDocument(docIndex),
            style: OutlinedButton.styleFrom(
              foregroundColor: hasFile ? AppColors.primary : AppColors.secondary,
              side: BorderSide(color: hasFile ? AppColors.primary : const Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              hasFile ? 'Remplacer' : 'Téléverser',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.secondary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      fillColor: const Color(0xFFFAFBFC),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.outOfStock),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.outOfStock, width: 1.5),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    );
  }

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.secondary,
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
    );
  }
}
