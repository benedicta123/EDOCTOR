import 'ringtone_player_interface.dart';
import 'ringtone_player_stub.dart'
    if (dart.library.js_interop) 'ringtone_player_web.dart'
    if (dart.library.html) 'ringtone_player_web.dart';

export 'ringtone_player_interface.dart';

class IncomingCallAudio {
  static final RingtonePlayer _player = getRingtonePlayer();

  static void start() {
    _player.startRinging();
  }

  static void stop() {
    _player.stopRinging();
  }
}
