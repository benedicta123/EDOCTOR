// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/video_meeting_config.dart';

/// Points d'entrée de la téléconsultation vidéo (JaaS, 8x8.vc).
///
/// La salle (domaine + nom + JWT éphémère) vient de
/// POST /api/consultations/{id}/join : le client ne génère ni ne devine
/// jamais de salle, et aucun lien vidéo ne transite par la messagerie.
/// Tout reste affiché dans la PWA, sans nouvel onglet.
class VideoConsultation {
  VideoConsultation._();

  /// Démarre la consultation si nécessaire, puis ouvre l'écran vidéo
  /// intégré. Complète quand l'écran se ferme.
  static Future<void> launch(
    BuildContext context,
    ConsultationModel consultation, {
    required bool startIfNeeded,
  }) async {
    if (startIfNeeded && consultation.status == 'en_attente') {
      try {
        await ApiService.consultationAction(consultation.id, 'start');
      } catch (e) {
        if (context.mounted) {
          showMsg(
            context,
            e.toString().replaceFirst('Exception: ', ''),
            error: true,
          );
        }
        return;
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoConsultationScreen(
          consultation: consultation,
        ),
      ),
    );
  }
}

/// Écran de téléconsultation vidéo : salle JaaS intégrée via l'IFrame API
/// officielle, affichée dans la page eDoctor (HtmlElementView + interop JS).
class VideoConsultationScreen extends StatefulWidget {
  final ConsultationModel consultation;
  const VideoConsultationScreen({
    super.key,
    required this.consultation,
  });

  @override
  State<VideoConsultationScreen> createState() =>
      _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends State<VideoConsultationScreen> {
  late final String _viewType;
  html.DivElement? _holder;
  js.JsObject? _api;
  VideoMeetingConfig? _config;

  bool _loadingConfig = true;
  bool _starting = false;
  bool _inCall = false;
  bool _leaving = false;
  String? _error;
  String _status = 'Préparation de la salle sécurisée…';
  int _participants = 1;

  @override
  void initState() {
    super.initState();
    _viewType =
        'edoctor-jaas-${widget.consultation.id}-${DateTime.now().millisecondsSinceEpoch}';
    _holder = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000000';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _holder!,
    );
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _disposeApi();
    super.dispose();
  }

  void _disposeApi() {
    final api = _api;
    _api = null;
    if (api is js.JsObject) {
      try {
        api.callMethod('dispose');
      } catch (_) {}
    }
  }

  /// 1. Récupère domaine + salle + JWT auprès de Laravel.
  Future<void> _prepare() async {
    try {
      final config =
          await ApiService.joinConsultation(widget.consultation.id);
      if (!mounted) return;
      setState(() {
        _config = config;
        _loadingConfig = false;
      });
      await _start(config);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// 2. Crée la salle JaaS intégrée dans la page.
  Future<void> _start(VideoMeetingConfig config) async {
    if (!mounted) return;
    setState(() {
      _starting = true;
      _error = null;
      _status = 'Connexion à la salle sécurisée…';
    });
    try {
      await _ensureJitsiScript(config);
      var waited = 0;
      while (mounted &&
          (_holder == null ||
              !html.document.contains(_holder as html.Node))) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waited += 50;
        if (waited > 8000) throw Exception('holder-not-attached');
      }
      if (!mounted) return;

      final user = await StorageService.getUser();
      if (!mounted) return;

      final options = js.JsObject.jsify({
        'roomName': '${config.appId}/${config.roomName}',
        'jwt': config.jwt,
        'width': '100%',
        'height': '100%',
        'parentNode': _holder,
        'userInfo': {
          'displayName':
              user != null ? doctorDisplay(user.name) : 'Médecin',
          'email': user?.email ?? '',
        },
        'configOverwrite': {
          'prejoinPageEnabled': false,
          'startWithAudioMuted': false,
          'startWithVideoMuted': false,
        },
      });
      final ctor = js.context['JitsiMeetExternalAPI'];
      final api = js.JsObject(ctor as js.JsFunction, [
        config.domain,
        options,
      ]);
      _api = api;

      // Autorisations explicites de l'iframe intégrée.
      try {
        final iframe =
            (_holder as html.DivElement).querySelector('iframe');
        iframe?.setAttribute('allow',
            'camera; microphone; fullscreen; display-capture');
      } catch (_) {}

      _listen(api);
      if (mounted) {
        setState(() {
          _starting = false;
          _inCall = true;
          _status = 'Connecté — consultation en vidéo.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _starting = false;
          _inCall = false;
          _error =
              'Salle vidéo inaccessible. Vérifiez la connexion puis réessayez.';
        });
      }
    }
  }

  void _listen(js.JsObject api) {
    void on(String event, js.JsFunction handler) {
      try {
        api.callMethod('addEventListener', [event, handler]);
      } catch (_) {}
    }

    on(
      'videoConferenceJoined',
      js.JsFunction.withThis((dynamic thisArg, [dynamic _]) {
        if (mounted) {
          setState(() {
            _inCall = true;
            _status = 'Connecté — consultation en vidéo.';
          });
        }
      }),
    );
    on(
      'videoConferenceLeft',
      js.JsFunction.withThis((dynamic thisArg, [dynamic _]) {
        // Fin côté salle : on reste sur l'écran (la consultation
        // n'est JAMAIS clôturée automatiquement).
        if (mounted) {
          setState(() {
            _inCall = false;
            _status = 'Vous avez quitté la salle.';
          });
        }
      }),
    );
    on(
      'participantJoined',
      js.JsFunction.withThis((dynamic thisArg, [dynamic _]) {
        if (mounted) {
          setState(() {
            _participants += 1;
            _status = 'Le patient a rejoint la salle.';
          });
        }
      }),
    );
    on(
      'participantLeft',
      js.JsFunction.withThis((dynamic thisArg, [dynamic _]) {
        if (mounted) {
          setState(() {
            _participants = _participants > 1 ? _participants - 1 : 1;
            _status = 'En attente de l’autre participant…';
          });
        }
      }),
    );
    on(
      'readyToClose',
      js.JsFunction.withThis((dynamic thisArg) {
        if (mounted) Navigator.of(context).maybePop();
      }),
    );
  }

  Future<void> _ensureJitsiScript(VideoMeetingConfig config) async {
    if (js.context.hasProperty('JitsiMeetExternalAPI')) {
      return;
    }
    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..src = 'https://${config.domain}/${config.appId}/external_api.js'
      ..async = true;
    script.onLoad.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    script.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('jaas-script-unavailable'));
      }
    });
    html.document.head!.children.add(script);
    await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw Exception('jaas-script-timeout'),
    );
  }

  Future<void> _leave() async {
    if (_leaving) return;
    if (_inCall) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Quitter la réunion ?'),
          content: const Text(
            'Vous quitterez la vidéo, mais la consultation restera en cours. Vous pourrez la rejoindre à nouveau.',
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Rester'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitter'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    setState(() => _leaving = true);
    _disposeApi();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consultation;
    final patient =
        c.patientName.isEmpty ? 'Patient #${c.patientId}' : c.patientName;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1E30),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 60,
              color: AppColors.secondary,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Quitter l\u2019appel',
                    icon: const Icon(
                        Icons.call_end_rounded, color: Colors.white),
                    onPressed: _leave,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Consultation vidéo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$patient · Consultation #${c.id}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.66),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _inCall
                          ? AppColors.success.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_rounded,
                            size: 13, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '$_participants',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
            Material(
              color: AppColors.primary.withValues(alpha: 0.16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 15, color: AppColors.primaryLight),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.black,
                child: _error != null
                    ? _errorPanel(context)
                    : Stack(
                        children: [
                          // La vue reste TOUJOURS montée : le conteneur DOM
                          // doit exister avant la création de la salle.
                          HtmlElementView(viewType: _viewType),
                          if (_loadingConfig || _starting)
                            const ColoredBox(
                              color: Colors.black,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                        color:
                                            AppColors.primaryLight),
                                    SizedBox(height: 14),
                                    Text(
                                      'Ouverture de la salle sécurisée…',
                                      style: TextStyle(
                                          color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPanel(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 44, color: Colors.white38),
            const SizedBox(height: 14),
            const Text(
              'Salle vidéo inaccessible',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _error ??
                  'Le service vidéo n\u2019a pas pu être chargé. Vérifiez votre connexion internet, puis réessayez.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final config = _config;
                    if (config == null) {
                      setState(() {
                        _loadingConfig = true;
                        _error = null;
                      });
                      unawaited(_prepare());
                    } else {
                      unawaited(_start(config));
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Retour'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
