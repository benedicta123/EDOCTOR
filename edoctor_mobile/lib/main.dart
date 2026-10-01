import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

import 'core/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initBaseUrl();

  // Fixe la barre d'état et l'orientation
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const EDoctorApp());
}
