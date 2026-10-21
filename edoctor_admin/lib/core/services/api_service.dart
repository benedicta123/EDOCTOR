import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../main.dart';
import '../constants/api_constants.dart';
import '../constants/app_colors.dart';
import '../../data/models/claim_model.dart';
import '../../data/models/hospital_model.dart';
import '../../data/models/overview_metrics_model.dart';
import '../../data/models/pharmacy_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/admin_wallet_model.dart';
import 'storage_service.dart';

/// Exception déclenchée quand le compte Super-Admin requiert la double authentification (2FA).
class TwoFactorRequiredException implements Exception {
  final String twoFactorToken;
  final String emailMasked;
  final String role;
  final String? debugCode;
  final String message;

  const TwoFactorRequiredException({
    required this.twoFactorToken,
    required this.emailMasked,
    required this.role,
    this.debugCode,
    required this.message,
  });

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static bool _isRedirectingToLogin = false;

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

  /// Récupère le jeton stocké ou déclenche immédiatement la redirection si absent
  static Future<String> _getRequiredToken() async {
    final token = await StorageService.getToken();
    if (token == null || token.isEmpty) {
      _handleUnauthenticated();
      throw Exception('Session expirée.');
    }
    return token;
  }

  /// Traite la réponse HTTP et intercepte globalement les erreurs 401 Unauthenticated
  static dynamic _processResponse(
    http.Response response, {
    required String defaultErrorMessage,
  }) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = null;
    }

    final bool is401 = response.statusCode == 401 ||
        (data is Map &&
            (data['message'] == 'Unauthenticated.' ||
                data['message'] == 'unauthenticated'));

    if (is401) {
      _handleUnauthenticated();
      throw Exception('Session expirée.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final msg = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : defaultErrorMessage;
    throw Exception(msg);
  }

  /// Réinitialise la session et redirige vers la page de connexion avec notification
  static void _handleUnauthenticated() {
    if (_isRedirectingToLogin) return;
    _isRedirectingToLogin = true;

    // Supprimer le token et la session locale
    StorageService.clearSession();

    // Rediriger immédiatement vers la page de connexion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = rootNavigatorKey.currentState;
      if (nav != null) {
        nav.pushNamedAndRemoveUntil('/login', (route) => false);
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.lock_clock_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Votre session a expiré. Veuillez vous reconnecter.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.suspended,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // Réinitialiser le verrou après 2 secondes pour éviter les doublons
      Future.delayed(const Duration(seconds: 2), () {
        _isRedirectingToLogin = false;
      });
    });
  }

  // ----------------------------------------------------
  // AUTHENTIFICATION
  // ----------------------------------------------------

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl${ApiConstants.login}');
    final response = await http.post(
      uri,
      headers: _headers(null, json: true),
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data['requires_2fa'] == true) {
        throw TwoFactorRequiredException(
          twoFactorToken: data['two_factor_token'] as String,
          emailMasked: (data['email_masked'] as String?) ?? 'votre adresse email',
          role: (data['role'] as String?) ?? 'admin',
          debugCode: data['debug_2fa_code']?.toString(),
          message: (data['message'] as String?) ?? 'Double authentification requise.',
        );
      }

      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      if (!user.isSuperAdmin) {
        throw Exception(
          'Accès refusé : Ce portail est strictement réservé aux Super-Administrateurs et Inspecteurs de la plateforme eDoctor.',
        );
      }

      await StorageService.saveSession(token: token, user: user);
      return {'token': token, 'user': user};
    } else {
      final msg = data['message'] ?? 'Erreur de connexion.';
      throw Exception(msg);
    }
  }

  static Future<Map<String, dynamic>> verifyTwoFactor({
    required String twoFactorToken,
    required String code,
  }) async {
    final uri = Uri.parse('$baseUrl${ApiConstants.loginVerify2Fa}');
    final response = await http.post(
      uri,
      headers: _headers(null, json: true),
      body: jsonEncode({
        'two_factor_token': twoFactorToken,
        'code': code.trim(),
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      if (!user.isSuperAdmin) {
        throw Exception(
          'Accès refusé : Ce portail est strictement réservé aux Super-Administrateurs et Inspecteurs de la plateforme eDoctor.',
        );
      }

      await StorageService.saveSession(token: token, user: user);
      return {'token': token, 'user': user};
    } else {
      final msg = data['message'] ?? 'Code 2FA incorrect ou expiré.';
      throw Exception(msg);
    }
  }

  static Future<void> logout() async {
    final token = await StorageService.getToken();
    if (token != null) {
      try {
        final uri = Uri.parse('$baseUrl${ApiConstants.logout}');
        await http.post(uri, headers: _headers(token));
      } catch (_) {}
    }
    await StorageService.clearSession();
  }

  // ----------------------------------------------------
  // STATISTIQUES NATIONALES (VUE D'ENSEMBLE)
  // ----------------------------------------------------

  static Future<OverviewMetricsModel> getOverview() async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminOverview}');
    final response = await http.get(uri, headers: _headers(token));
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur de chargement des statistiques.',
    ) as Map<String, dynamic>;
    return OverviewMetricsModel.fromJson(data);
  }

  // ----------------------------------------------------
  // MODULE HÔPITAUX PARTENAIRES & ACCRÉDITATION EDOCTOR
  // ----------------------------------------------------

  static Future<List<HospitalModel>> getHospitals({String? status, String? search}) async {
    final token = await _getRequiredToken();
    final queryParams = <String, String>{};
    if (status != null && status != 'tous') queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl${ApiConstants.adminHospitals}').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final response = await http.get(uri, headers: _headers(token));
    final list = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la récupération des hôpitaux.',
    ) as List<dynamic>;
    return list.map((e) => HospitalModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<HospitalModel> verifyHospital(int id) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminHospitalVerify(id)}');
    final response = await http.post(uri, headers: _headers(token, json: true));
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la validation.',
    );
    return HospitalModel.fromJson(data['hospital'] as Map<String, dynamic>);
  }

  static Future<HospitalModel> rejectHospital(int id, {required String reason}) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminHospitalReject(id)}');
    final response = await http.post(
      uri,
      headers: _headers(token, json: true),
      body: jsonEncode({'reason': reason}),
    );
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors du rejet.',
    );
    return HospitalModel.fromJson(data['hospital'] as Map<String, dynamic>);
  }

  static Future<HospitalModel> suspendHospital(int id, {required String reason}) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminHospitalSuspend(id)}');
    final response = await http.post(
      uri,
      headers: _headers(token, json: true),
      body: jsonEncode({'reason': reason}),
    );
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la suspension.',
    );
    return HospitalModel.fromJson(data['hospital'] as Map<String, dynamic>);
  }

  static Future<HospitalModel> reactivateHospital(int id) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminHospitalReactivate(id)}');
    final response = await http.post(uri, headers: _headers(token, json: true));
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la réactivation.',
    );
    return HospitalModel.fromJson(data['hospital'] as Map<String, dynamic>);
  }

  // ----------------------------------------------------
  // MODULE PHARMACIES & LICENCE D'OFFICINE (KYP)
  // ----------------------------------------------------

  static Future<List<PharmacyModel>> getPharmacies({String? status, String? search}) async {
    final token = await _getRequiredToken();
    final queryParams = <String, String>{};
    if (status != null && status != 'tous') queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl${ApiConstants.adminPharmacies}').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final response = await http.get(uri, headers: _headers(token));
    final list = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la récupération des pharmacies.',
    ) as List<dynamic>;
    return list.map((e) => PharmacyModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<PharmacyModel> verifyPharmacy(int id) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminPharmacyVerify(id)}');
    final response = await http.post(uri, headers: _headers(token, json: true));
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la validation de la pharmacie.',
    );
    return PharmacyModel.fromJson(data['pharmacy'] as Map<String, dynamic>);
  }

  static Future<PharmacyModel> rejectPharmacy(int id, {required String reason}) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminPharmacyReject(id)}');
    final response = await http.post(
      uri,
      headers: _headers(token, json: true),
      body: jsonEncode({'reason': reason}),
    );
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors du rejet de la pharmacie.',
    );
    return PharmacyModel.fromJson(data['pharmacy'] as Map<String, dynamic>);
  }

  static Future<PharmacyModel> suspendPharmacy(int id, {required String reason}) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminPharmacySuspend(id)}');
    final response = await http.post(
      uri,
      headers: _headers(token, json: true),
      body: jsonEncode({'reason': reason}),
    );
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la suspension.',
    );
    return PharmacyModel.fromJson(data['pharmacy'] as Map<String, dynamic>);
  }

  static Future<PharmacyModel> reactivatePharmacy(int id) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminPharmacyReactivate(id)}');
    final response = await http.post(uri, headers: _headers(token, json: true));
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la réactivation.',
    );
    return PharmacyModel.fromJson(data['pharmacy'] as Map<String, dynamic>);
  }

  // ----------------------------------------------------
  // GESTION DES UTILISATEURS & MODÉRATION
  // ----------------------------------------------------

  static Future<List<UserModel>> getUsers({
    String? role,
    String? status,
    String? search,
    int page = 1,
  }) async {
    final token = await _getRequiredToken();
    final queryParams = <String, String>{'page': page.toString()};
    if (role != null && role != 'tous') queryParams['role'] = role;
    if (status != null && status != 'tous') queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl${ApiConstants.adminUsers}').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers(token));
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la récupération des utilisateurs.',
    );
    final list = (data['data'] as List<dynamic>?) ?? [];
    return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<UserModel> suspendUser(int id, {required String reason}) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminUserSuspend(id)}');
    final response = await http.post(
      uri,
      headers: _headers(token, json: true),
      body: jsonEncode({'reason': reason}),
    );
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la suspension.',
    );
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  static Future<UserModel> reactivateUser(int id) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminUserReactivate(id)}');
    final response = await http.post(uri, headers: _headers(token, json: true));
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la réactivation.',
    );
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  // ----------------------------------------------------
  // JOURNAL DES RÉCLAMATIONS & LITIGES
  // ----------------------------------------------------

  static Future<List<ClaimModel>> getClaims({
    String? status,
    String? priority,
    String? category,
    String? search,
  }) async {
    final token = await _getRequiredToken();
    final queryParams = <String, String>{};
    if (status != null && status != 'tous') queryParams['status'] = status;
    if (priority != null && priority != 'tous') queryParams['priority'] = priority;
    if (category != null && category != 'tous') queryParams['category'] = category;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl${ApiConstants.adminClaims}').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final response = await http.get(uri, headers: _headers(token));
    final list = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors du chargement des réclamations.',
    ) as List<dynamic>;
    return list.map((e) => ClaimModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<ClaimModel> resolveClaim(int id, {required String notes}) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminClaimResolve(id)}');
    final response = await http.post(
      uri,
      headers: _headers(token, json: true),
      body: jsonEncode({'notes': notes}),
    );
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la résolution de la réclamation.',
    );
    return ClaimModel.fromJson(data['claim'] as Map<String, dynamic>);
  }

  static Future<ClaimModel> updateClaimStatus(int id, {required String status, String? notes}) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminClaimStatus(id)}');
    final bodyMap = <String, dynamic>{'status': status};
    if (notes != null) bodyMap['notes'] = notes;
    final response = await http.post(
      uri,
      headers: _headers(token, json: true),
      body: jsonEncode(bodyMap),
    );
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la mise à jour.',
    );
    return ClaimModel.fromJson(data['claim'] as Map<String, dynamic>);
  }

  // ----------------------------------------------------
  // MODULE TRÉSORERIE & PORTEFEUILLES (FINANCES)
  // ----------------------------------------------------

  static Future<Map<String, dynamic>> getWalletsData() async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminWallets}');
    final response = await http.get(uri, headers: _headers(token));
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors du chargement des portefeuilles.',
    );

    final summary = AdminWalletSummaryModel.fromJson(data['summary'] as Map<String, dynamic>? ?? {});
    final walletsList = (data['wallets'] as List? ?? [])
        .map((w) => AdminWalletItemModel.fromJson(w as Map<String, dynamic>))
        .toList();

    return {
      'summary': summary,
      'wallets': walletsList,
    };
  }

  static Future<List<AdminPayoutRequestModel>> getPayoutRequests({String? status}) async {
    final token = await _getRequiredToken();
    final queryParams = <String, String>{};
    if (status != null && status != 'tous') queryParams['status'] = status;

    final uri = Uri.parse('$baseUrl${ApiConstants.adminPayoutRequests}').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final response = await http.get(uri, headers: _headers(token));
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors du chargement des demandes de reversement.',
    );

    final list = (data is Map && data['data'] != null) ? data['data'] as List : (data as List? ?? []);
    return list.map((e) => AdminPayoutRequestModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<AdminPayoutRequestModel> approvePayout(
    int payoutRequestId, {
    String? transactionRef,
    String? notes,
  }) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminPayoutApprove(payoutRequestId)}');
    final bodyMap = <String, dynamic>{};
    if (transactionRef != null && transactionRef.isNotEmpty) bodyMap['transaction_ref'] = transactionRef.trim();
    if (notes != null && notes.isNotEmpty) bodyMap['notes'] = notes.trim();

    final response = await http.post(
      uri,
      headers: _headers(token, json: true),
      body: jsonEncode(bodyMap),
    );
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors de la validation du reversement.',
    );
    return AdminPayoutRequestModel.fromJson(data['payout_request'] as Map<String, dynamic>);
  }

  static Future<AdminPayoutRequestModel> rejectPayout(
    int payoutRequestId, {
    required String reason,
  }) async {
    final token = await _getRequiredToken();
    final uri = Uri.parse('$baseUrl${ApiConstants.adminPayoutReject(payoutRequestId)}');
    final response = await http.post(
      uri,
      headers: _headers(token, json: true),
      body: jsonEncode({'reason': reason.trim()}),
    );
    final data = _processResponse(
      response,
      defaultErrorMessage: 'Erreur lors du rejet du reversement.',
    );
    return AdminPayoutRequestModel.fromJson(data['payout_request'] as Map<String, dynamic>);
  }
}
