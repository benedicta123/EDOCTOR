import 'dart:async';
import 'package:flutter/services.dart';
import 'ringtone_player_interface.dart';

RingtonePlayer getRingtonePlayer() => RingtonePlayerStub();

class RingtonePlayerStub implements RingtonePlayer {
  Timer? _timer;

  @override
  void startRinging() {
    _timer?.cancel();
    SystemSound.play(SystemSoundType.alert);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      SystemSound.play(SystemSoundType.alert);
    });
  }

  @override
  void stopRinging() {
    _timer?.cancel();
    _timer = null;
  }
}
