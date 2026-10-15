import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/constants/app_colors.dart';
import 'core/services/storage_service.dart';
import 'features/auth/login_screen.dart';
import 'features/claims/claims_screen.dart';
import 'features/hospitals/hospital_validation_screen.dart';
import 'features/overview/overview_screen.dart';
import 'features/pharmacies/pharmacy_validation_screen.dart';
import 'features/users/users_moderation_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isAuth = await StorageService.isAuthenticated();
  runApp(EDoctorAdminApp(initialRoute: isAuth ? '/overview' : '/login'));
}

class EDoctorAdminApp extends StatelessWidget {
  final String initialRoute;

  const EDoctorAdminApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'eDoctor Régulation — Console Super-Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/overview': (_) => const OverviewScreen(),
        '/hospitals': (_) => const HospitalValidationScreen(),
        '/pharmacies': (_) => const PharmacyValidationScreen(),
        '/users': (_) => const UsersModerationScreen(),
        '/claims': (_) => const ClaimsScreen(),
      },
    );
  }
}
