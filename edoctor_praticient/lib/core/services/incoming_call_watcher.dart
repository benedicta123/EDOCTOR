import 'dart:async';

import '../navigation/app_router.dart';
import '../../features/doctor/widgets/incoming_call_modal.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Surveille en arrière-plan (polling réactif toutes les 2,5 secondes)
/// l'arrivée de consultations immédiates en attente pour déclencher
/// l'alerte sonore et visuelle de l'appel entrant (IncomingCallModal).
class IncomingCallWatcher {
  IncomingCallWatcher._();
  static final IncomingCallWatcher instance = IncomingCallWatcher._();

  Timer? _timer;
  bool _isChecking = false;
  final Set<int> _handledOrIgnoredIds = {};

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    IncomingCallModal.dismiss();
  }

  void markHandled(int consultationId) {
    _handledOrIgnoredIds.add(consultationId);
  }

  Future<void> _tick() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final token = await StorageService.getToken();
      if (token == null || token.isEmpty) return;

      final user = await StorageService.getUser();
      if (user == null || !user.isDoctor) return;

      final consultations = await ApiService.getConsultations();

      // Si le modal est actuellement affiché
      if (IncomingCallModal.isShown && IncomingCallModal.activeConsultationId != null) {
        final activeId = IncomingCallModal.activeConsultationId!;
        final activeMatch = consultations.where((c) => c.id == activeId).toList();
        
        // Si la consultation n'existe plus ou si le statut est annulé par le patient
        if (activeMatch.isEmpty || activeMatch.first.status == 'annulee' || activeMatch.first.status == 'terminee') {
          IncomingCallModal.dismiss(cancelledByPatient: true);
        }
        return;
      }

      // Recherche des consultations entrantes en attente
      final pendingCalls = consultations
          .where((c) => c.status == 'en_attente' && !_handledOrIgnoredIds.contains(c.id))
          .toList();

      if (pendingCalls.isNotEmpty) {
        final incoming = pendingCalls.first;
        final ctx = praticienNavigatorKey.currentContext;

        if (ctx != null && ctx.mounted) {
          _handledOrIgnoredIds.add(incoming.id);
          // Ouvre le modal sonore et visuel
          unawaited(IncomingCallModal.show(ctx, incoming));
        }
      }
    } catch (_) {
      // Ignorer les erreurs réseau temporaires
    } finally {
      _isChecking = false;
    }
  }
}
