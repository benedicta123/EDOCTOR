import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../navigation/app_router.dart';
import '../services/api_service.dart';
import '../services/session_inactivity_service.dart';
import 'app_logo.dart';
import 'custom_button.dart';

/// Composant racine englobant l'application pour surveiller l'inactivité
/// et afficher l'écran de verrouillage avec authentification biométrique / PIN.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionInactivityService.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      SessionInactivityService.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      SessionInactivityService.onAppResumed();
    }
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await SessionInactivityService.reset();
      await ApiService.logout();
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
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo et badge de sécurité
                            const AppLogo(size: 76),
                            const SizedBox(height: 28),

                            // Icône cadenas sécurisé
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                size: 44,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 24),

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
                            const SizedBox(height: 12),

                            const Text(
                              'Par mesure de sécurité pour votre dossier médical, votre session a été verrouillée après 30 minutes d\'inactivité.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFFCBD5E1),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Bouton d'authentification native (Empreinte / Code PIN)
                            CustomButton(
                              text: 'Déverrouiller avec empreinte ou PIN',
                              leadingIcon: Icons.lock_open_rounded,
                              onPressed: () =>
                                  SessionInactivityService.authenticateAndUnlock(),
                            ),
                            const SizedBox(height: 16),

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
