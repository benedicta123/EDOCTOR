import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
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
    final user = await StorageService.getUser();
    if (!mounted) return;
    if (token == null || user == null) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    Widget next = const LoginScreen();
    if (user.isDoctor) {
      next = const DoctorDashboard();
    } else if (user.isHospitalAdmin) {
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
              // Carte blanche : le logo est sombre, illisible directement sur le fond marine.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 26, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/edoctor_logo.png',
                  width: 190,
                  height: 62,
                  fit: BoxFit.contain,
                ),
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
