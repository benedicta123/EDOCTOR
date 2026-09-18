// Ce fichier est conservé pour la compatibilité des routes existantes.
// L'inscription est maintenant divisée en deux écrans :
//   • HospitalRegisterStep1Screen (établissement)
//   • HospitalRegisterStep2Screen (compte admin)
//
// Redirection automatique vers Step 1.

import 'hospital_register_step1_screen.dart';

export 'hospital_register_step1_screen.dart';

// Alias pour la route '/hospital-register' déclarée dans app.dart
typedef HospitalRegisterScreen = HospitalRegisterStep1Screen;
