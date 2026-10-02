import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../navigation/app_router.dart';
import '../../data/models/user_model.dart';
import '../../data/models/hospital_model.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/prescription_model.dart';
import '../../data/models/lab_request_model.dart';
import '../../data/models/nurse_visit_model.dart';
import '../../data/models/video_meeting_config.dart';
import 'storage_service.dart';

/// Client API espace Praticien — 100% donnees reelles Laravel.
/// Auth Sanctum : POST /login universel, routage par role ensuite.
class ApiService {
  ApiService._();

  static bool _redirecting401 = false;

  /// Gère l'expiration du token (HTTP 401) de façon globale :
  /// vide le cache de session, informe l'utilisateur et redirige vers /login.
  static Future<void> _handleUnauthorized() async {
    if (_redirecting401) return;
    _redirecting401 = true;
    try {
      await StorageService.clearSession();
      final nav = praticienNavigatorKey.currentState;
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
      nav?.pushNamedAndRemoveUntil('/login', (_) => false);
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _redirecting401 = false;
      });
    }
  }

  static String get baseUrl {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return ApiConstants.desktopBaseUrl;
    }
    return ApiConstants.baseUrl;
  }

  static Map<String, String> _headers(String? token, {bool json = false}) => {
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static String _msg(http.Response r, String fallback) {
    if (r.statusCode == 401) {
      _handleUnauthorized();
      return 'Session expirée. Veuillez vous reconnecter.';
    }
    try {
      final data = jsonDecode(r.body);
      if (data is Map<String, dynamic>) {
        final errors = data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            return first.first.toString();
          }
        }
        return data['message']?.toString() ?? fallback;
      }
      return fallback;
    } catch (_) {
      return '$fallback (${r.statusCode})';
    }
  }

  static Exception _net(Exception e) {
    final m = e.toString();
    if (m.contains('Failed host lookup') ||
        m.contains('Connection refused') ||
        m.contains('ClientException') ||
        m.contains('SocketException')) {
      return Exception(
        "Serveur eDoctor injoignable. Vérifiez que l'API tourne sur $baseUrl.",
      );
    }
    return e;
  }

  // ---------- Auth ----------
  static Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl${ApiConstants.login}'),
        headers: _headers(null, json: true),
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 200) {
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        if (user.role != 'doctor' && !user.isHospitalAdmin) {
          throw Exception(
            "Ce portail est réservé aux médecins et administrateurs d'hôpital (rôle détecté : ${user.role}).",
          );
        }
        await StorageService.saveSession(
          token: data['token'] as String,
          user: user,
        );
        return user;
      }
      throw Exception(_msg(r, 'Identifiants incorrects'));
    } on Exception catch (e) {
      throw _net(e);
    }
  }

  static Future<Map<String, dynamic>> registerHospital({
    required String hospitalName,
    required String address,
    required double latitude,
    required double longitude,
    required String licenseNumber,
    required String officialEmail,
    required String hospitalPhone,
    String? taxNumber,
    required String adminName,
    required String adminEmail,
    required String password,
    required String passwordConfirmation,
    String? adminPhone,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl${ApiConstants.hospitalRegister}'),
        headers: _headers(null, json: true),
        body: jsonEncode({
          'hospital_name': hospitalName,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'license_number': licenseNumber,
          'official_email': officialEmail,
          'hospital_phone': hospitalPhone,
          if (taxNumber != null && taxNumber.isNotEmpty)
            'tax_number': taxNumber,
          'admin_name': adminName,
          'admin_email': adminEmail,
          'password': password,
          'password_confirmation': passwordConfirmation,
          if (adminPhone != null && adminPhone.isNotEmpty)
            'admin_phone': adminPhone,
        }),
      );
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 201) {
        if (data['token'] != null && data['admin'] != null) {
          final user = UserModel.fromJson(
            data['admin'] as Map<String, dynamic>,
          );
          await StorageService.saveSession(
            token: data['token'] as String,
            user: user,
          );
        }
        return data;
      }
      throw Exception(_msg(r, "Erreur lors de l'inscription de l'hôpital"));
    } on Exception catch (e) {
      throw _net(e);
    }
  }

  static Future<Map<String, dynamic>> geocodeHospitalAddress({
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.hospitalGeocode}'),
      headers: _headers(token, json: true),
      body: jsonEncode({
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        'latitude': ?latitude,
        'longitude': ?longitude,
      }),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Localisation impossible'));
  }

  static Future<void> logout() async {
    final token = await StorageService.getToken();
    try {
      await http.post(
        Uri.parse('$baseUrl${ApiConstants.logout}'),
        headers: _headers(token),
      );
    } catch (_) {}
    await StorageService.clearSession();
  }

  static Future<UserModel> me() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.me}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    }
    throw Exception(_msg(r, 'Session expirée'));
  }

  static Future<UserModel> updateProfile(Map<String, dynamic> fields) async {
    final token = await StorageService.getToken();
    final r = await http.put(
      Uri.parse('$baseUrl${ApiConstants.profile}'),
      headers: _headers(token, json: true),
      body: jsonEncode(fields),
    );
    if (r.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    }
    throw Exception(_msg(r, 'Modification du profil impossible'));
  }

  static Future<void> heartbeat() async {
    final token = await StorageService.getToken();
    await http.post(
      Uri.parse('$baseUrl${ApiConstants.heartbeat}'),
      headers: _headers(token),
    );
  }

  // ---------- Medecin : consultations ----------
  static Future<Map<String, dynamic>> getDoctorDashboard() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.doctorDashboard}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Tableau de bord médecin inaccessible'));
  }

  static Future<Map<String, dynamic>> getDoctorPatients({
    String? search,
  }) async {
    final token = await StorageService.getToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.doctorPatients}').replace(
      queryParameters: search == null || search.trim().isEmpty
          ? null
          : {'search': search.trim()},
    );
    final r = await http.get(uri, headers: _headers(token));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Patients inaccessibles'));
  }

  static Future<UserModel> getDoctorProfile() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.doctorProfile}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200)
      return UserModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw Exception(_msg(r, 'Profil médecin inaccessible'));
  }

  static Future<UserModel> updateDoctorProfile(
    Map<String, dynamic> fields,
  ) async {
    final token = await StorageService.getToken();
    final r = await http.put(
      Uri.parse('$baseUrl${ApiConstants.doctorProfile}'),
      headers: _headers(token, json: true),
      body: jsonEncode(fields),
    );
    if (r.statusCode == 200)
      return UserModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw Exception(_msg(r, 'Modification du profil impossible'));
  }

  static Future<void> updateDoctorAvailability(String status) async {
    final token = await StorageService.getToken();
    final r = await http.patch(
      Uri.parse('$baseUrl${ApiConstants.doctorAvailability}'),
      headers: _headers(token, json: true),
      body: jsonEncode({'availability_status': status}),
    );
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception(_msg(r, 'Disponibilité impossible à modifier'));
  }

  static Future<List<ConsultationModel>> getConsultations() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.consultations}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      final list = jsonDecode(r.body) as List;
      return list
          .map((e) => ConsultationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Chargement des consultations impossible'));
  }

  /// Accès à la salle vidéo JaaS (domaine + salle + JWT éphémère).
  /// POST /api/consultations/{id}/join
  static Future<VideoMeetingConfig> joinConsultation(int id) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.consultationJoin(id)}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      final config = VideoMeetingConfig.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>,
      );
      if (!config.isValid) {
        throw Exception('Configuration vidéo incomplète reçue du serveur.');
      }
      return config;
    }
    throw Exception(_msg(r, 'Salle vidéo inaccessible'));
  }

  static Future<void> consultationAction(int id, String action, {String? reason}) async {
    final token = await StorageService.getToken();
    String path;
    switch (action) {
      case 'start':
        path = ApiConstants.consultationStart(id);
        break;
      case 'decline':
        path = ApiConstants.consultationDecline(id);
        break;
      case 'end':
        path = ApiConstants.consultationEnd(id);
        break;
      default:
        path = ApiConstants.consultationCancel(id);
    }
    final r = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token, json: reason != null),
      body: reason != null ? jsonEncode({'reason': reason}) : null,
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_msg(r, 'Action impossible'));
    }
  }

  static Future<void> endConsultation(int id, {String? diagnosis}) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.consultationEnd(id)}'),
      headers: _headers(token, json: true),
      body: jsonEncode({
        if (diagnosis != null && diagnosis.trim().isNotEmpty)
          'diagnosis': diagnosis.trim(),
      }),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_msg(r, 'Clôture impossible'));
    }
  }

  static Future<List<ChatMessage>> getMessages(int consultationId) async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.consultationMessages(consultationId)}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      final list = jsonDecode(r.body) as List;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Messages inaccessibles'));
  }

  static Future<void> sendMessage(int consultationId, String content) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.consultationMessages(consultationId)}'),
      headers: _headers(token, json: true),
      body: jsonEncode({'content': content}),
    );
    if (r.statusCode != 201 && r.statusCode != 200) {
      throw Exception(_msg(r, 'Envoi impossible'));
    }
  }

  // ---------- Medecin : prescriptions ----------
  static Future<List<PrescriptionModel>> getPrescriptions() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.prescriptions}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      final list = jsonDecode(r.body) as List;
      return list
          .map((e) => PrescriptionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Ordonnances inaccessibles'));
  }

  static Future<PrescriptionModel> createPrescription({
    required int consultationId,
    required bool homeCareRecommended,
    required List<Map<String, dynamic>> items,
  }) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.prescriptions}'),
      headers: _headers(token, json: true),
      body: jsonEncode({
        'consultation_id': consultationId,
        'home_care_recommended': homeCareRecommended,
        'items': items,
      }),
    );
    if (r.statusCode == 201 || r.statusCode == 200) {
      return PrescriptionModel.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>,
      );
    }
    throw Exception(_msg(r, 'Création de l\u2019ordonnance impossible'));
  }

  static Future<void> cancelPrescription(int id) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.prescriptionCancel(id)}'),
      headers: _headers(token),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_msg(r, 'Annulation impossible'));
    }
  }

  // ---------- Médecin : Bilans & Examens complémentaires ----------
  static Future<List<LabRequestModel>> getConsultationLabRequests(int consultationId) async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.consultationLabRequests(consultationId)}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      final list = jsonDecode(r.body) as List;
      return list
          .map((e) => LabRequestModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Bilans d’examens inaccessibles'));
  }

  static Future<List<LabRequestModel>> getMyLabRequests() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.labRequestsMy}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      final list = jsonDecode(r.body) as List;
      return list
          .map((e) => LabRequestModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Historique des examens inaccessible'));
  }

  static Future<LabRequestModel> getLabRequestDetails(int id) async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.labRequestDetails(id)}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      return LabRequestModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    }
    throw Exception(_msg(r, 'Détail du bilan introuvable'));
  }

  static Future<LabRequestModel> createLabRequest({
    required int consultationId,
    required List<Map<String, dynamic>> items,
    String? clinicalNotes,
    String urgencyLevel = 'normal',
    bool fastingRequired = false,
  }) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.consultationLabRequests(consultationId)}'),
      headers: _headers(token, json: true),
      body: jsonEncode({
        'consultation_id': consultationId,
        'items': items,
        if (clinicalNotes != null && clinicalNotes.trim().isNotEmpty)
          'clinical_notes': clinicalNotes.trim(),
        'urgency_level': urgencyLevel,
        'fasting_required': fastingRequired,
      }),
    );
    if (r.statusCode == 201 || r.statusCode == 200) {
      return LabRequestModel.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>,
      );
    }
    throw Exception(_msg(r, 'Impossible de créer la prescription d’examens'));
  }

  static Future<LabRequestModel> reviewLabRequest(
    int id, {
    String? doctorReviewNotes,
    String status = 'analyse_terminee',
  }) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.labRequestReview(id)}'),
      headers: _headers(token, json: true),
      body: jsonEncode({
        if (doctorReviewNotes != null && doctorReviewNotes.trim().isNotEmpty)
          'doctor_review_notes': doctorReviewNotes.trim(),
        'status': status,
      }),
    );
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return LabRequestModel.fromJson(data['lab_request'] as Map<String, dynamic>);
    }
    throw Exception(_msg(r, 'Validation du bilan impossible'));
  }

  static Future<List<MedicationModel>> getMedications() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.medications}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      final list = body is List
          ? body
          : (body as Map<String, dynamic>)['data'] as List? ?? [];
      return list
          .map((e) => MedicationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Catalogue de médicaments inaccessible'));
  }

  /// Récupère la liste des médicaments pour une consultation avec filtrage géolocalisé des stocks (Règle DG)
  static Future<List<MedicationModel>> getConsultationMedications(
    int consultationId, {
    bool inStockOnly = true,
    double radiusKm = 15.0,
    String? q,
  }) async {
    final token = await StorageService.getToken();
    final baseUri = Uri.parse('$baseUrl${ApiConstants.consultationMedications(consultationId)}');
    final queryParams = <String, String>{
      'in_stock_only': inStockOnly ? '1' : '0',
      'radius_km': radiusKm.toString(),
    };
    if (q != null && q.isNotEmpty) queryParams['q'] = q;

    final uri = baseUri.replace(queryParameters: queryParams);
    final r = await http.get(uri, headers: _headers(token));
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final list = body['medications'] as List? ?? [];
      return list
          .map((e) => MedicationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Disponibilité des médicaments inaccessible'));
  }

  static Future<Map<String, dynamic>> getPatientDossier(int patientId) async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.patientDossier(patientId)}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception(_msg(r, 'Dossier patient inaccessible'));
  }

  // ---------- Admin hopital ----------
  static Future<Map<String, dynamic>> getHospitalDashboard() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.hospitalDashboard}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Tableau de bord hôpital inaccessible'));
  }

  static Future<Map<String, dynamic>> getHospitalStatistics() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.hospitalStatistics}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Statistiques hôpital inaccessibles'));
  }

  static Future<Map<String, dynamic>> getHospitalConsultations({
    String? status,
  }) async {
    final token = await StorageService.getToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.hospitalConsultations}')
        .replace(queryParameters: status == null ? null : {'status': status});
    final r = await http.get(uri, headers: _headers(token));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Consultations hôpital inaccessibles'));
  }

  static Future<HospitalModel> getMyHospital() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.myHospital}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      return HospitalModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    }
    throw Exception(_msg(r, 'Hôpital inaccessible'));
  }

  static Future<Map<String, dynamic>> getHospitalStaff() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.myHospitalStaff}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception(_msg(r, 'Personnel inaccessible'));
  }

  static Future<Map<String, dynamic>> createDoctor({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String specialty,
    required String licenseNumber,
  }) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.myHospitalDoctors}'),
      headers: _headers(token, json: true),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'specialty': specialty,
        'license_number': licenseNumber,
      }),
    );
    if (r.statusCode == 201 || r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception(_msg(r, 'Création du médecin impossible'));
  }

  static Future<Map<String, dynamic>> createNurse({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String licenseNumber,
  }) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.myHospitalNurses}'),
      headers: _headers(token, json: true),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'license_number': licenseNumber,
      }),
    );
    if (r.statusCode == 201 || r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception(_msg(r, 'Création de l\u2019infirmier impossible'));
  }

  static Future<List<NurseVisitModel>> getNurseVisits(int hospitalId) async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.hospitalNurseVisits(hospitalId)}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      final list = body is List ? body : (body['data'] as List? ?? []);
      return list
          .map((e) => NurseVisitModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Visites infirmières inaccessibles'));
  }

  static Future<void> assignNurseVisit(int visitId, int nurseId) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.nurseVisitAssign(visitId)}'),
      headers: _headers(token, json: true),
      body: jsonEncode({'nurse_id': nurseId}),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_msg(r, 'Affectation impossible'));
    }
  }

  static Future<List<AppNotification>> getNotifications() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.notifications}'),
      headers: _headers(token),
    );
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      final list = body is List ? body : (body['data'] as List? ?? []);
      return list
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static Future<void> markNotificationRead(int id) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.notifications}/$id/read'),
      headers: _headers(token),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_msg(r, 'Notification inaccessible'));
    }
  }
}
