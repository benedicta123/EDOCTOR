import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'ringtone_player_interface.dart';

RingtonePlayer getRingtonePlayer() => RingtonePlayerWeb();

class RingtonePlayerWeb implements RingtonePlayer {
  web.AudioContext? _ctx;
  Timer? _timer;
  bool _isPlaying = false;
  static bool _unlocked = false;

  RingtonePlayerWeb() {
    _bindUnlockListeners();
  }

  /// Déverrouille préventivement l'AudioContext dès la première interaction utilisateur sur la page
  static void _bindUnlockListeners() {
    if (_unlocked) return;
    try {
      void unlock(web.Event _) {
        _unlocked = true;
        try {
          final tempCtx = web.AudioContext();
          tempCtx.resume();
        } catch (_) {}
      }

      web.window.addEventListener('click', unlock.toJS);
      web.window.addEventListener('keydown', unlock.toJS);
      web.window.addEventListener('pointerdown', unlock.toJS);
    } catch (_) {}
  }

  @override
  void startRinging() {
    if (_isPlaying) return;
    _isPlaying = true;
    _playChime();
    _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (_isPlaying) {
        _playChime();
      }
    });
  }

  Future<void> _playChime() async {
    try {
      _ctx ??= web.AudioContext();
      final ctx = _ctx!;
      if (ctx.state == 'suspended') {
        try {
          await ctx.resume().toDart;
        } catch (_) {}
      }

      final now = ctx.currentTime;

      // Sonnerie téléphonique médicale : double impulsion harmonieuse (440Hz + 480Hz)
      _scheduleTone(ctx, now, 0.8);
      _scheduleTone(ctx, now + 1.0, 0.8);
    } catch (_) {
      // Ignorer si les permissions audio du navigateur bloquent l'autoplay
    }
  }

  void _scheduleTone(web.AudioContext ctx, double startTime, double duration) {
    try {
      final osc1 = ctx.createOscillator();
      final osc2 = ctx.createOscillator();
      final gain = ctx.createGain();

      osc1.type = 'sine';
      osc1.frequency.value = 440; // Note LA

      osc2.type = 'sine';
      osc2.frequency.value = 480; // Fréquence standard de sonnerie

      gain.gain.setValueAtTime(0.22, startTime);
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(ctx.destination);

      osc1.start(startTime);
      osc2.start(startTime);
      osc1.stop(startTime + duration);
      osc2.stop(startTime + duration);
    } catch (_) {}
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
