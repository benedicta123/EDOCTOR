import 'package:flutter/material.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/verification_pending_screen.dart';
import 'features/dashboard/pharmacy_dashboard.dart';
import 'features/orders/orders_screen.dart';
import 'features/inventory/stock_screen.dart';
import 'features/profile/pharmacy_profile_screen.dart';

class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eDoctor Pharmacie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: pharmacyNavigatorKey,
      home: const SplashScreen(),
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/pending-verification': (_) => const VerificationPendingScreen(),
        '/dashboard': (_) => const PharmacyDashboard(),
        '/orders': (_) => const OrdersScreen(),
        '/inventory': (_) => const StockScreen(),
        '/profile': (_) => const PharmacyProfileScreen(),
      },
    );
  }
}
