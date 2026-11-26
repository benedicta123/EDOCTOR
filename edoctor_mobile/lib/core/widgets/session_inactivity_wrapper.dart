import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../navigation/app_router.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../services/session_inactivity_service.dart';
import '../services/storage_service.dart';
import 'app_logo.dart';
import 'custom_button.dart';

/// Composant racine englobant l'application pour surveiller l'inactivité
/// et afficher l'écran de verrouillage avec gestion universelle :
/// - Choix entre Empreinte digitale et Code PIN du téléphone
/// - Repli automatique sur le mot de passe du compte eDoctor si l'appareil
///   n'a ni capteur biométrique ni code PIN/schéma configuré.
class SessionInactivityWrapper extends StatefulWidget {
  final Widget child;

  const SessionInactivityWrapper({
    super.key,
    required this.child,
  });

  @override
  State<SessionInactivityWrapper> createState() =>
      _SessionInactivityWrapperState();
}

class _SessionInactivityWrapperState extends State<SessionInactivityWrapper>
    with WidgetsBindingObserver {
  bool _isLoggingOut = false;
  bool _isAuthenticatingBiometrics = false;
  bool _isAuthenticatingPin = false;
  bool _isVerifyingPassword = false;
  bool _isPasswordObscured = true;
  bool _showPasswordInput = false;
  bool _hasDeviceLock = true;
  String? _userEmail;
  String? _errorMessage;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionInactivityService.init();
    _checkDeviceCapabilities();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkDeviceCapabilities() async {
    try {
      final user = await StorageService.getUser();
      final hasLock = await BiometricService.hasAnyDeviceLock();
      if (mounted) {
        setState(() {
          _hasDeviceLock = hasLock;
          _userEmail = user?.email;
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      SessionInactivityService.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _checkDeviceCapabilities();
      SessionInactivityService.onAppResumed();
    }
  }

  Future<void> _handleUnlockWithBiometrics() async {
    if (_isAuthenticatingBiometrics || _isAuthenticatingPin) return;
    setState(() {
      _isAuthenticatingBiometrics = true;
      _errorMessage = null;
    });

    try {
      final available = await BiometricService.isBiometricAvailable();
      if (!available) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Aucun capteur d\'empreinte disponible. Utilisez votre code PIN ou le mot de passe de votre compte.';
          });
        }
        return;
      }

      final success =
          await SessionInactivityService.authenticateWithBiometrics();
      if (!success && mounted) {
        setState(() {
          _errorMessage =
              'Empreinte non reconnue ou annulée. Réessayez, utilisez le code PIN ou votre mot de passe.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Erreur du capteur. Déverrouillez avec votre code PIN ou votre mot de passe de compte.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticatingBiometrics = false);
      }
    }
  }

  Future<void> _handleUnlockWithPin() async {
    if (_isAuthenticatingBiometrics || _isAuthenticatingPin) return;
    setState(() {
      _isAuthenticatingPin = true;
      _errorMessage = null;
    });

    try {
      final hasLock = await BiometricService.hasAnyDeviceLock();
      if (!hasLock) {
        if (mounted) {
          setState(() {
            _hasDeviceLock = false;
            _errorMessage =
                'Aucun code PIN ou schéma n\'est configuré sur ce téléphone. Déverrouillez avec votre mot de passe eDoctor.';
          });
        }
        return;
      }

      final success = await SessionInactivityService.authenticateWithPin();
      if (!success && mounted) {
        setState(() {
          _errorMessage =
              'Code PIN non validé ou annulé. Vous pouvez aussi utiliser votre mot de passe eDoctor.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Code PIN système indisponible. Déverrouillez avec le mot de passe de votre compte.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticatingPin = false);
      }
    }
  }

  /// Déverrouillage par mot de passe du compte eDoctor
  /// Solution universelle garantissant qu'aucun utilisateur n'est bloqué,
  /// même sans capteur biométrique et sans code PIN/schéma de téléphone.
  Future<void> _handleUnlockWithPassword() async {
    final pwd = _passwordController.text.trim();
    if (pwd.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez saisir votre mot de passe.';
      });
      return;
    }

    setState(() {
      _isVerifyingPassword = true;
      _errorMessage = null;
    });

    try {
      final user = await StorageService.getUser();
      final email = user?.email ?? _userEmail ?? '';
      if (email.isEmpty) {
        throw Exception('Session utilisateur introuvable. Veuillez vous reconnecter.');
      }

      await ApiService.login(
        email: email,
        password: pwd,
      );

      _passwordController.clear();
      if (mounted) {
        setState(() {
          _isVerifyingPassword = false;
          _showPasswordInput = false;
          _errorMessage = null;
        });
      }
      await SessionInactivityService.unlockManually();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingPassword = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Widget _buildPasswordInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(
              Icons.lock_person_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Déverrouillage par mot de passe',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _userEmail != null && _userEmail!.isNotEmpty
              ? 'Compte : $_userEmail'
              : 'Saisissez votre mot de passe pour réactiver votre session.',
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFFCBD5E1),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _isPasswordObscured,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleUnlockWithPassword(),
          decoration: InputDecoration(
            hintText: 'Votre mot de passe eDoctor',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            prefixIcon: const Icon(
              Icons.key_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordObscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () {
                setState(() => _isPasswordObscured = !_isPasswordObscured);
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Déverrouiller la session',
          icon: Icons.lock_open_rounded,
          isLoading: _isVerifyingPassword,
          onPressed: _isVerifyingPassword ? null : _handleUnlockWithPassword,
        ),
        if (_hasDeviceLock) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isVerifyingPassword
                ? null
                : () => setState(() {
                      _showPasswordInput = false;
                      _errorMessage = null;
                    }),
            child: const Text(
              'Retour aux options Empreinte / PIN',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await SessionInactivityService.reset();
      await StorageService.clearSession();
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
      redirectToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SessionInactivityService.recordActivity(),
      child: Stack(
        children: [
          // Arborescence applicative normale
          widget.child,

          // Écran de verrouillage de sécurité au-dessus de tout
          ValueListenableBuilder<bool>(
            valueListenable: SessionInactivityService.isLockedNotifier,
            builder: (context, isLocked, _) {
              if (!isLocked) return const SizedBox.shrink();

              return Positioned.fill(
                child: Material(
                  color: AppColors.secondary, // Bleu nuit officiel #132A45
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12),

                            // Logo officiel eDoctor
                            const AppLogo(size: 76),
                            const SizedBox(height: 24),

                            // Badge cadenas sécurisé
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.lock_clock_rounded,
                                size: 36,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              'Session verrouillée',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),

                            const Text(
                              'Par mesure de sécurité pour votre dossier médical, votre session a été verrouillée après 30 minutes d\'inactivité.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFFCBD5E1),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Boîte de choix de la méthode de déverrouillage
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_hasDeviceLock) ...[
                                    if (_showPasswordInput) ...[
                                      _buildPasswordInputSection(),
                                    ] else ...[
                                      const Text(
                                        'Choisissez votre mode de déverrouillage :',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      const SizedBox(height: 18),

                                      // Option 1 : Empreinte digitale
                                      CustomButton(
                                        text: 'Déverrouiller par Empreinte',
                                        icon: Icons.fingerprint_rounded,
                                        isLoading: _isAuthenticatingBiometrics,
                                        onPressed: (_isAuthenticatingBiometrics ||
                                                _isAuthenticatingPin ||
                                                _isVerifyingPassword)
                                            ? null
                                            : _handleUnlockWithBiometrics,
                                      ),
                                      const SizedBox(height: 12),

                                      // Séparateur discret "OU"
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                              color: Colors.white
                                                  .withValues(alpha: 0.15),
                                              thickness: 1,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            child: Text(
                                              'OU',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Divider(
                                              color: Colors.white
                                                  .withValues(alpha: 0.15),
                                              thickness: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Option 2 : Code PIN du téléphone
                                      SizedBox(
                                        height: 52,
                                        child: OutlinedButton(
                                          onPressed: (_isAuthenticatingBiometrics ||
                                                  _isAuthenticatingPin ||
                                                  _isVerifyingPassword)
                                              ? null
                                              : _handleUnlockWithPin,
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: Color(0xFF38BDF8),
                                              width: 1.5,
                                            ),
                                            backgroundColor:
                                                const Color(0xFF38BDF8)
                                                    .withValues(alpha: 0.08),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                          ),
                                          child: _isAuthenticatingPin
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            Color(0xFF38BDF8)),
                                                  ),
                                                )
                                              : const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.dialpad_rounded,
                                                      size: 20,
                                                      color: Color(0xFF38BDF8),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Déverrouiller avec Code PIN',
                                                      style: TextStyle(
                                                        color:
                                                            Color(0xFF38BDF8),
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      // Option 3 : Repli universel mot de passe eDoctor
                                      TextButton.icon(
                                        onPressed: (_isAuthenticatingBiometrics ||
                                                _isAuthenticatingPin ||
                                                _isVerifyingPassword)
                                            ? null
                                            : () => setState(() {
                                                  _showPasswordInput = true;
                                                  _errorMessage = null;
                                                }),
                                        icon: const Icon(
                                          Icons.key_rounded,
                                          size: 16,
                                          color: Color(0xFFCBD5E1),
                                        ),
                                        label: const Text(
                                          'Ou déverrouiller avec mot de passe du compte',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFFCBD5E1),
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ] else ...[
                                    // Cas où l'appareil n'a ni empreinte ni PIN système
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38BDF8)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            color: Color(0xFF38BDF8),
                                            size: 20,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Aucun verrouillage (code PIN ou empreinte) n\'est configuré sur ce téléphone.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFE2E8F0),
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildPasswordInputSection(),
                                  ],

                                  // Message d'erreur / aide contextuel
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.red
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.info_outline_rounded,
                                            size: 16,
                                            color: Color(0xFFFCA5A5),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFFCA5A5),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Option de déconnexion si ce n'est pas le titulaire
                            TextButton.icon(
                              onPressed: _isLoggingOut ? null : _handleLogout,
                              icon: _isLoggingOut
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white70,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.logout_rounded,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                              label: const Text(
                                'Se déconnecter du compte',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Note de conformité ONMT Togo
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Conforme sécurité données de santé ONMT Togo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
