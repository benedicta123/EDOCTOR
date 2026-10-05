import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../navigation/app_router.dart';
import '../../data/models/user_model.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/patient_dossier_model.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/prescription_model.dart';
import '../../data/models/claim_model.dart';
import '../../data/models/lab_request_model.dart';
import 'storage_service.dart';
import 'video/video_meeting_config.dart';

class ApiService {
  static String? _cachedBaseUrl;

  static String get baseUrl {
    if (_cachedBaseUrl != null && _cachedBaseUrl!.trim().isNotEmpty) {
      return _cachedBaseUrl!.trim();
    }
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return ApiConstants.desktopBaseUrl;
    }
    return ApiConstants.baseUrl;
  }

  /// Initialise l'URL du serveur depuis la persistance locale
  static Future<void> initBaseUrl() async {
    final saved = await StorageService.getServerUrl();
    if (saved != null && saved.trim().isNotEmpty) {
      _cachedBaseUrl = saved.trim();
    }
  }

  /// Met à jour et sauvegarde la nouvelle URL du serveur
  static Future<void> setBaseUrl(String url) async {
    var cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.endsWith('/api')) {
      cleanUrl = '$cleanUrl/api';
    }
    _cachedBaseUrl = cleanUrl;
    await StorageService.setServerUrl(cleanUrl);
  }

  /// Teste la connectivité vers l'API Laravel
  static Future<Map<String, dynamic>> testConnection([String? targetUrl]) async {
    var endpoint = (targetUrl ?? baseUrl).trim();
    if (endpoint.endsWith('/')) {
      endpoint = endpoint.substring(0, endpoint.length - 1);
    }
    if (!endpoint.endsWith('/api')) {
      endpoint = '$endpoint/api';
    }
    final checkUri = Uri.parse('$endpoint${ApiConstants.availableDoctors}');
    final sw = Stopwatch()..start();
    try {
      final response = await http
          .get(checkUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      sw.stop();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': 'Connecté avec succès (${sw.elapsedMilliseconds} ms)',
          'latency': sw.elapsedMilliseconds,
        };
      }
      return {
        'success': false,
        'message': 'Code HTTP ${response.statusCode} reçu',
      };
    } catch (e) {
      sw.stop();
      return {
        'success': false,
        'message': 'Injoignable : ${e.toString().replaceAll('Exception: ', '')}',
      };
    }
  }

  static bool _redirecting401 = false;

  // ─── Intercepteur 401 ─────────────────────────────────────────────────────
  /// Appelé sur toute réponse 401 reçue en session active.
  /// Efface le token et redirige vers l'inscription/connexion.
  static Future<void> _handleUnauthorized() async {
    if (_redirecting401) return;
    _redirecting401 = true;
    try {
      await StorageService.clearSession();
      final nav = appNavigatorKey.currentState;
      final ctx = nav?.context;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Votre session a expiré. Veuillez vous reconnecter.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFFBA1A1A),
            duration: Duration(seconds: 4),
          ),
        );
      }
      nav?.pushNamedAndRemoveUntil('/register', (_) => false);
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _redirecting401 = false;
      });
    }
  }

  /// Vérifie si la réponse est un 401 et déclenche la déconnexion.
  /// Retourne true si la requête était non autorisée (le caller doit stopper).
  static Future<bool> _checkAuth(http.Response r) async {
    if (r.statusCode == 401) {
      await _handleUnauthorized();
      return true;
    }
    return false;
  }

  static Exception _handleNetworkException(Object e) {
    final msg = e.toString();
    if (msg.contains('Failed host lookup') ||
        msg.contains('Connection refused') ||
        msg.contains('ClientException') ||
        msg.contains('SocketException') ||
        msg.contains('TimeoutException') ||
        msg.contains('timed out') ||
        msg.contains('Software caused connection abort')) {
      return Exception(
        'Serveur eDoctor injoignable ($baseUrl).\n'
        'Vérifiez le Wi-Fi (même box), le pare-feu du PC (port 8000) ou réglez l\'adresse du serveur.',
      );
    }
    return Exception(msg.replaceAll('Exception: ', ''));
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
      ).timeout(const Duration(seconds: 12));

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
    } catch (e) {
      throw _handleNetworkException(e);
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
      ).timeout(const Duration(seconds: 12));

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
    } catch (e) {
      throw _handleNetworkException(e);
    }
  }

  /// Vérifie la validité du token en cours et retourne l'utilisateur courant.
  /// GET /api/me — utilisé par le splash pour détecter les tokens expirés.
  /// Retourne null si le token est invalide/expiré (401).
  static Future<UserModel?> me() async {
    final token = await StorageService.getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl${ApiConstants.me}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userJson = data['user'] as Map<String, dynamic>? ?? data;
        final user = UserModel.fromJson(userJson);
        await StorageService.saveSession(token: token, user: user);
        return user;
      }
      if (response.statusCode == 401) {
        await StorageService.clearSession();
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Récupération des médecins disponibles — 100% données réelles (PostgreSQL).
  static Future<List<DoctorModel>> getAvailableDoctors() async {
    final url = Uri.parse('$baseUrl${ApiConstants.availableDoctors}');
    final token = await StorageService.getToken();

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (await _checkAuth(response)) return [];

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
    } catch (e) {
      throw _handleNetworkException(e);
    }
  }

  /// Récupération du dossier médical patient — dérivé des consultations
  /// (en_cours/terminee) et ordonnances (validee) en base.
  /// GET /api/patients/{patientId}/dossier
  static Future<PatientDossier> getPatientDossier(int patientId) async {
    final url = Uri.parse('$baseUrl/patients/$patientId/dossier');
    final token = await StorageService.getToken();

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
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
    } catch (e) {
      throw _handleNetworkException(e);
    }
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

  /// Payer une téléconsultation médicale avec découpage financier
  /// POST /api/consultations/{id}/pay
  static Future<Map<String, dynamic>> payConsultation(
    int consultationId, {
    String paymentMethod = 'mobile_money',
    String? transactionRef,
  }) async {
    final response = await _consultationRequest(
      ApiConstants.consultationPay(consultationId),
      post: true,
      body: {
        'payment_method': paymentMethod,
        if (transactionRef != null) 'transaction_ref': transactionRef,
      },
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
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

  /// Récupérer les pharmacies agréées eDoctor
  /// GET /api/pharmacies
  static Future<List<Map<String, dynamic>>> getPharmacies() async {
    final response = await _consultationRequest(ApiConstants.pharmacies);
    final data = jsonDecode(response.body) as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Obtenir le devis d'une commande en pharmacie (médicaments + 150 F + livraison optionnelle)
  /// POST /api/orders/quote
  static Future<Map<String, dynamic>> getOrderQuote({
    required int pharmacyId,
    required List<Map<String, dynamic>> items,
    bool withDelivery = false,
    double? deliveryDistanceKm,
    double? patientLatitude,
    double? patientLongitude,
  }) async {
    final response = await _consultationRequest(
      ApiConstants.ordersQuote,
      post: true,
      body: {
        'pharmacy_id': pharmacyId,
        'items': items,
        'with_delivery': withDelivery,
        if (deliveryDistanceKm != null) 'delivery_distance_km': deliveryDistanceKm,
        if (patientLatitude != null) 'patient_latitude': patientLatitude,
        if (patientLongitude != null) 'patient_longitude': patientLongitude,
      },
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Obtenir le devis kilométrique de livraison seule
  /// POST /api/deliveries/quote
  static Future<Map<String, dynamic>> getDeliveryQuote({
    double? distanceKm,
    double? patientLatitude,
    double? patientLongitude,
  }) async {
    final response = await _consultationRequest(
      ApiConstants.deliveriesQuote,
      post: true,
      body: {
        if (distanceKm != null) 'distance_km': distanceKm,
        if (patientLatitude != null) 'patient_latitude': patientLatitude,
        if (patientLongitude != null) 'patient_longitude': patientLongitude,
      },
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Créer une commande en pharmacie liée à une ordonnance
  /// POST /api/orders
  static Future<Map<String, dynamic>> createOrder({
    required int pharmacyId,
    int? prescriptionId,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    bool withDelivery = false,
    String? deliveryAddress,
    double? deliveryDistanceKm,
    double? patientLatitude,
    double? patientLongitude,
  }) async {
    final response = await _consultationRequest(
      ApiConstants.orders,
      post: true,
      body: {
        'pharmacy_id': pharmacyId,
        if (prescriptionId != null) 'prescription_id': prescriptionId,
        'payment_method': paymentMethod,
        'items': items,
        'with_delivery': withDelivery,
        if (deliveryAddress != null) 'delivery_address': deliveryAddress,
        if (deliveryDistanceKm != null) 'delivery_distance_km': deliveryDistanceKm,
        if (patientLatitude != null) 'patient_latitude': patientLatitude,
        if (patientLongitude != null) 'patient_longitude': patientLongitude,
      },
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Récupérer les commandes du patient connecté
  /// GET /api/orders
  static Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _consultationRequest(ApiConstants.orders);
    final data = jsonDecode(response.body) as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Récupérer les réclamations et litiges du patient
  /// GET /api/claims/my
  static Future<List<ClaimModel>> getMyClaims() async {
    final response = await _consultationRequest(ApiConstants.myClaims);
    final list = jsonDecode(response.body) as List? ?? [];
    return list.map((e) => ClaimModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Soumettre une réclamation officielle
  /// POST /api/claims
  static Future<ClaimModel> submitClaim({
    required String subject,
    required String description,
    required String category,
    String priority = 'normale',
    String? targetType,
    int? targetId,
  }) async {
    final response = await _consultationRequest(
      ApiConstants.claims,
      post: true,
      body: {
        'subject': subject,
        'description': description,
        'category': category,
        'priority': priority,
        'target_type': ?targetType,
        'target_id': ?targetId,
      },
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final claimData = (data['claim'] as Map<String, dynamic>?) ?? data;
    return ClaimModel.fromJson(claimData);
  }

  /// Récupérer les bilans et examens complémentaires du patient
  /// GET /api/lab-requests/my
  static Future<List<LabRequestModel>> getMyLabRequests() async {
    final response = await _consultationRequest(ApiConstants.labRequestsMy);
    final list = jsonDecode(response.body) as List? ?? [];
    return list.map((e) => LabRequestModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Récupérer les détails d'un examen médical
  /// GET /api/lab-requests/{id}
  static Future<LabRequestModel> getLabRequestDetails(int id) async {
    final response = await _consultationRequest(ApiConstants.labRequestDetails(id));
    return LabRequestModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Téléverser un résultat d'examen (image base64 ou document)
  /// POST /api/lab-requests/{id}/results
  static Future<LabRequestModel> uploadLabResults(
    int id, {
    String? patientNotes,
    String? fileBase64,
    String? fileName,
  }) async {
    final response = await _consultationRequest(
      ApiConstants.labRequestResults(id),
      post: true,
      body: {
        if (patientNotes != null && patientNotes.trim().isNotEmpty)
          'patient_notes': patientNotes.trim(),
        'file_base64': ?fileBase64,
        'file_name': ?fileName,
      },
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final labData = (data['lab_request'] as Map<String, dynamic>?) ?? data;
    return LabRequestModel.fromJson(labData);
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
      final response = await request.timeout(const Duration(seconds: 12));

      // ─── Intercepteur 401 global ───────────────────────────────────────────
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        // Retourner une réponse vide pour que les callers ne crashent pas
        return http.Response('[]', 200);
      }

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
    } catch (e) {
      throw _handleNetworkException(e);
    } finally {
      client.close();
    }
  }
}

