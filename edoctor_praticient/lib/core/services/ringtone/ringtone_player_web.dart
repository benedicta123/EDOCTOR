import 'dart:async';
import 'package:web/web.dart' as web;
import 'ringtone_player_interface.dart';

RingtonePlayer getRingtonePlayer() => RingtonePlayerWeb();

class RingtonePlayerWeb implements RingtonePlayer {
  web.AudioContext? _ctx;
  Timer? _timer;
  bool _isPlaying = false;

  @override
  void startRinging() {
    if (_isPlaying) return;
    _isPlaying = true;
    _playChime();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isPlaying) {
        _playChime();
      }
    });
  }

  void _playChime() {
    try {
      _ctx ??= web.AudioContext();
      final ctx = _ctx!;
      if (ctx.state == 'suspended') {
        ctx.resume();
      }

      final now = ctx.currentTime;

      final osc1 = ctx.createOscillator();
      final osc2 = ctx.createOscillator();
      final gain = ctx.createGain();

      osc1.type = 'sine';
      osc1.frequency.value = 440; // Note LA

      osc2.type = 'sine';
      osc2.frequency.value = 480; // Fréquence 480 Hz

      gain.gain.setValueAtTime(0.25, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 1.4);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(ctx.destination);

      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + 1.4);
      osc2.stop(now + 1.4);
    } catch (_) {
      // Ignorer si les permissions audio du navigateur bloquent l'autoplay
    }
  }

  @override
  void stopRinging() {
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    try {
      _ctx?.close();
      _ctx = null;
    } catch (_) {}
  }
}
