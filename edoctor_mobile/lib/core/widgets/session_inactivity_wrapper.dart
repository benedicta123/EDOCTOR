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
  bool _hasDeviceLock = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionInactivityService.init();
    _checkDeviceCapabilities();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkDeviceCapabilities() async {
    try {
      final hasLock = await BiometricService.hasAnyDeviceLock();
      if (mounted) {
        setState(() {
          _hasDeviceLock = hasLock;
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
  Future<void> _showPasswordUnlockDialog() async {
    final user = await StorageService.getUser();
    final email = user?.email ?? '';
    final passwordController = TextEditingController();
    bool isObscured = true;
    bool isVerifying = false;
    String? localError;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.secondary, // #132A45
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(
                          Icons.lock_person_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Déverrouiller par Mot de Passe',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email.isNotEmpty
                          ? 'Confirmez le mot de passe de votre compte ($email) pour réactiver votre session.'
                          : 'Confirmez le mot de passe de votre compte pour réactiver votre session.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCBD5E1),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: passwordController,
                      obscureText: isObscured,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
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
                            isObscured
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () {
                            setModalState(() => isObscured = !isObscured);
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
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          localError!,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Valider le déverrouillage',
                      isLoading: isVerifying,
                      onPressed: isVerifying
                          ? null
                          : () async {
                              final pwd = passwordController.text;
                              if (pwd.isEmpty) {
                                setModalState(() {
                                  localError =
                                      'Veuillez saisir votre mot de passe.';
                                });
                                return;
                              }
                              setModalState(() {
                                isVerifying = true;
                                localError = null;
                              });

                              try {
                                await ApiService.login(
                                  email: email,
                                  password: pwd,
                                );
                                if (bottomSheetContext.mounted) {
                                  Navigator.of(bottomSheetContext).pop();
                                }
                                await SessionInactivityService.unlockManually();
                              } catch (e) {
                                setModalState(() {
                                  isVerifying = false;
                                  localError =
                                      'Mot de passe incorrect. Veuillez vérifier votre saisie.';
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isVerifying
                          ? null
                          : () => Navigator.of(bottomSheetContext).pop(),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                                              _isAuthenticatingPin)
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
                                                _isAuthenticatingPin)
                                            ? null
                                            : _handleUnlockWithPin,
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Color(0xFF38BDF8),
                                            width: 1.5,
                                          ),
                                          backgroundColor: const Color(0xFF38BDF8)
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
                                                      color: Color(0xFF38BDF8),
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
                                              _isAuthenticatingPin)
                                          ? null
                                          : _showPasswordUnlockDialog,
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
                                    CustomButton(
                                      text:
                                          'Déverrouiller avec mon mot de passe',
                                      icon: Icons.lock_open_rounded,
                                      onPressed: _showPasswordUnlockDialog,
                                    ),
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
