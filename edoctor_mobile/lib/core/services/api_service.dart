import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../../data/models/user_model.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/patient_dossier_model.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/prescription_model.dart';
import 'storage_service.dart';
import 'video/video_meeting_config.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return ApiConstants.desktopBaseUrl;
    }
    return ApiConstants.baseUrl;
  }

  /// Inscription d'un nouveau patient
  static Future<UserModel> registerPatient({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? dateOfBirth,
    String? address,
    String? medicalHistorySummary,
  }) async {
    final url = Uri.parse('$baseUrl${ApiConstants.register}');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (dateOfBirth != null && dateOfBirth.isNotEmpty)
            'date_of_birth': dateOfBirth,
          if (address != null && address.isNotEmpty) 'address': address,
          if (medicalHistorySummary != null && medicalHistorySummary.isNotEmpty)
            'medical_history_summary': medicalHistorySummary,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        final token = data['token'] as String;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        await StorageService.saveSession(token: token, user: user);
        return user;
      } else {
        final message = data['message'] ?? 'Erreur lors de l\'inscription';
        final errors = data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          final firstError = errors.values.first as List;
          throw Exception(firstError.first.toString());
        }
        throw Exception(message.toString());
      }
    } on Exception catch (e) {
      final msg = e.toString();
      // Données 100% réelles : aucun compte démo, on remonte l'erreur serveur.
      if (msg.contains('Failed host lookup') ||
          msg.contains('Connection refused') ||
          msg.contains('ClientException') ||
          msg.contains('SocketException')) {
        throw Exception(
            'Serveur eDoctor injoignable. Vérifiez que l\'API Laravel tourne sur $baseUrl.');
      }
      rethrow;
    }
  }

  /// Connexion utilisateur
  static Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl${ApiConstants.login}');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = data['token'] as String;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        await StorageService.saveSession(token: token, user: user);
        return user;
      } else {
        final message = data['message'] ?? 'Identifiants incorrects';
        throw Exception(message.toString());
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('Connection refused') ||
          msg.contains('ClientException') ||
          msg.contains('SocketException')) {
        throw Exception(
            'Serveur eDoctor injoignable. Vérifiez que l\'API Laravel tourne sur $baseUrl.');
      }
      rethrow;
    }
  }

  /// Récupération des médecins disponibles — 100% données réelles (PostgreSQL).
  /// Ne retourne plus de liste en dur : toute erreur remonte à l'UI.
  static Future<List<DoctorModel>> getAvailableDoctors() async {
    final url = Uri.parse('$baseUrl${ApiConstants.availableDoctors}');
    final token = await StorageService.getToken();

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .map((item) => DoctorModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final message = (() {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['message']?.toString() ?? 'Erreur ${response.statusCode}';
      } catch (_) {
        return 'Erreur ${response.statusCode} lors du chargement des médecins';
      }
    })();
    throw Exception(message);
  }

  /// Récupération du dossier médical patient — dérivé des consultations
  /// (en_cours/terminee) et ordonnances (validee) en base.
  /// GET /api/patients/{patientId}/dossier
  static Future<PatientDossier> getPatientDossier(int patientId) async {
    final url = Uri.parse('$baseUrl/patients/$patientId/dossier');
    final token = await StorageService.getToken();

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Enrichit le patient avec la session locale (nom/tél si l'API renvoie partiel).
      final sessionUser = await StorageService.getUser();
      if (sessionUser != null && sessionUser.id == patientId) {
        final p = (data['patient'] as Map<String, dynamic>?) ?? {};
        p['name'] = (p['name'] as String?)?.isNotEmpty == true
            ? p['name']
            : sessionUser.name;
        p['phone'] = p['phone'] ?? sessionUser.phone;
        p['date_of_birth'] = p['date_of_birth'] ?? sessionUser.dateOfBirth;
        p['address'] = p['address'] ?? sessionUser.address;
        p['medical_history_summary'] =
            p['medical_history_summary'] ?? sessionUser.medicalHistorySummary;
        data['patient'] = p;
      }
      return PatientDossier.fromJson(data);
    }

    final message = (() {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['message']?.toString() ?? 'Erreur ${response.statusCode}';
      } catch (_) {
        return 'Erreur ${response.statusCode} lors du chargement du dossier';
      }
    })();
    throw Exception(message);
  }

  // ─── Consultations ───────────────────────────────────────────────────────

  /// Envoyer une demande de consultation au médecin.
  /// POST /api/consultations
  static Future<ConsultationModel> requestConsultation(int doctorId) async {
    final response = await _consultationRequest(
      ApiConstants.consultations,
      post: true,
      body: {'doctor_id': doctorId},
    );
    return ConsultationModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Récupérer toutes les consultations du patient connecté.
  /// GET /api/consultations
  static Future<List<ConsultationModel>> getMyConsultations() async {
    final response = await _consultationRequest(ApiConstants.consultations);
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => ConsultationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Annuler une consultation (côté patient).
  /// POST /api/consultations/{id}/cancel
  static Future<void> cancelConsultation(int consultationId) async {
    await _consultationRequest(
      '${ApiConstants.consultations}/$consultationId/cancel',
      post: true,
    );
  }

  /// Obtenir l'accès à la salle vidéo JaaS (domaine + salle + JWT éphémère).
  /// POST /api/consultations/{id}/join
  static Future<VideoMeetingConfig> joinConsultation(
      int consultationId) async {
    final response = await _consultationRequest(
      '${ApiConstants.consultations}/$consultationId/join',
      post: true,
    );
    final config = VideoMeetingConfig.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (!config.isValid) {
      throw Exception('Configuration vidéo incomplète reçue du serveur.');
    }
    return config;
  }

  // ─── Messagerie ──────────────────────────────────────────────────────────

  /// Récupérer les messages d'une consultation.
  /// GET /api/consultations/{id}/messages
  static Future<List<ChatMessage>> getMessages(int consultationId) async {
    final response = await _consultationRequest(
      '${ApiConstants.consultations}/$consultationId/messages',
    );
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Envoyer un message dans une consultation.
  /// POST /api/consultations/{id}/messages
  static Future<ChatMessage> sendMessage(int consultationId, String content) async {
    final text = content.trim();
    if (text.isEmpty || text.runes.length > 2000) {
      throw Exception('Le message doit contenir entre 1 et 2000 caractères.');
    }
    final response = await _consultationRequest(
      '${ApiConstants.consultations}/$consultationId/messages',
      post: true,
      body: {'content': text},
    );
    return ChatMessage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ─── Ordonnances ───────────────────────────────────────────────────────────

  /// Récupérer les ordonnances du patient connecté (émises par les médecins).
  /// GET /api/prescriptions
  static Future<List<PatientPrescription>> getPrescriptions() async {
    final response = await _consultationRequest(ApiConstants.prescriptions);
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => PatientPrescription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Notifications ───────────────────────────────────────────────────────

  /// Récupérer les notifications du patient connecté.
  /// GET /api/notifications
  static Future<List<AppNotification>> getNotifications() async {
    final response = await _consultationRequest(ApiConstants.notifications);
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Marquer une notification comme lue.
  /// POST /api/notifications/{id}/read
  static Future<void> markNotificationRead(int notificationId) async {
    await _consultationRequest(
      '${ApiConstants.notifications}/$notificationId/read',
      post: true,
    );
  }

  static Future<http.Response> _consultationRequest(
    String path, {
    bool post = false,
    Map<String, dynamic>? body,
  }) async {
    final token = await StorageService.getToken();
    final client = http.Client();
    try {
      final baseHeaders = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final request = post
          ? client.post(
              Uri.parse('$baseUrl$path'),
              headers: {
                ...baseHeaders,
                'Content-Type': 'application/json',
              },
              body: body == null ? null : jsonEncode(body),
            )
          : client.get(
              Uri.parse('$baseUrl$path'),
              headers: baseHeaders,
            );
      final response = await request.timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final data = (() {
          try {
            return jsonDecode(response.body) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })();
        throw Exception(
          data['message']?.toString() ??
              'Erreur ${response.statusCode} ($path)',
        );
      }
      return response;
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') ||
          msg.contains('Connection refused') ||
          msg.contains('ClientException') ||
          msg.contains('SocketException')) {
        throw Exception(
            'Serveur eDoctor injoignable. Vérifiez que l\'API Laravel tourne sur $baseUrl.');
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}

