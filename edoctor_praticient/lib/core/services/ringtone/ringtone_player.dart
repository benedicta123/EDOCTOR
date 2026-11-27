import 'ringtone_player_interface.dart';
import 'ringtone_player_stub.dart'
    if (dart.library.js_interop) 'ringtone_player_web.dart'
    if (dart.library.html) 'ringtone_player_web.dart';

export 'ringtone_player_interface.dart';

class IncomingCallAudio {
  static final RingtonePlayer _player = getRingtonePlayer();

  /// Pré-initialise les écouteurs de déverrouillage audio (utile sur navigateur web).
  static void warmUp() {
    // L'accès à _player déclenche l'instanciation paresseuse et l'enregistrement des écouteurs.
    // ignore: unnecessary_statements
    _player;
  }

  static void start() {
    _player.startRinging();
  }

  static void stop() {
    _player.stopRinging();
  }
}
