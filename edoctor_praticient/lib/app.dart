import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/hospital_register_screen.dart';
import 'features/doctor/doctor_dashboard.dart';
import 'features/hospital/hospital_dashboard.dart';

class PraticienApp extends StatelessWidget {
  const PraticienApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eDoctor Praticien',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/hospital-register': (_) => const HospitalRegisterScreen(),
        '/doctor': (_) => const DoctorDashboard(),
        '/hospital': (_) => const HospitalDashboard(),
      },
    );
  }
}
