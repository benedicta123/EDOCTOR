import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import '../doctor/doctor_dashboard.dart';
import '../hospital/hospital_dashboard.dart';

/// Splash PWA : relit token + rôle puis route vers le bon tableau de bord.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final token = await StorageService.getToken();
    final cachedUser = await StorageService.getUser();
    if (!mounted) return;
    if (token == null || cachedUser == null) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    UserModel userToRoute = cachedUser;
    try {
      final fresh = await ApiService.me();
      if (!mounted) return;
      userToRoute = fresh;
      await StorageService.saveSession(token: token, user: fresh);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      // Si la session est expirée ou invalide (401), vider la session et rediriger vers le login
      if (msg.contains('401') || msg.contains('expirée') || msg.contains('non authentifié')) {
        await StorageService.clearSession();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
        return;
      }
      // En cas de simple déconnexion réseau (hors ligne), on continue avec le cache
    }

    Widget next = const LoginScreen();
    if (userToRoute.isDoctor) {
      next = const DoctorDashboard();
    } else if (userToRoute.isHospitalAdmin) {
      next = const HospitalDashboard();
    }
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1E30), AppColors.secondary, Color(0xFF1A3558)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo_blanc.png',
                width: 220,
                height: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'Espace Praticien',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Médecins & Hôpitaux — Togo',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    color: AppColors.primaryLight, strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
