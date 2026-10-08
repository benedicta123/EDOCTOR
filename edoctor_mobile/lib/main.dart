import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

import 'core/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ApiService.initBaseUrl();
  } catch (e) {
    debugPrint('InitBaseUrl error: $e');
  }

  // Fixe la barre d'état et l'orientation
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const EDoctorApp());
}
