import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/register_step1_screen.dart';
import 'features/home/home_screen.dart';
import 'features/doctors/find_doctor_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/prescriptions/prescriptions_screen.dart';
import 'features/medical_history/medical_history_screen.dart';
import 'features/home_care/home_care_screen.dart';
import 'features/dossier/patient_dossier_screen.dart';
import 'features/profile/patient_profile_screen.dart';

class EDoctorApp extends StatelessWidget {
  const EDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eDoctor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/register': (_) => const RegisterStep1Screen(),
        '/home': (_) => const HomeScreen(),
        '/doctors': (_) => const FindDoctorScreen(),
        '/orders': (_) => const OrdersScreen(),
        '/prescriptions': (_) => const PrescriptionsScreen(),
        '/medical-history': (_) => const MedicalHistoryScreen(),
        '/home-care': (_) => const HomeCareScreen(),
        '/dossier': (_) => const PatientDossierScreen(),
        '/profile': (_) => const PatientProfileScreen(),
      },
    );
  }
}
