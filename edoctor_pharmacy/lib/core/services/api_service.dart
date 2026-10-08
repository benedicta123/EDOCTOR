import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../navigation/app_router.dart';
import '../../data/models/user_model.dart';
import '../../data/models/pharmacy_model.dart';
import '../../data/models/stock_item_model.dart';
import '../../data/models/order_model.dart';
import 'storage_service.dart';

class ApiService {
  ApiService._();

  static bool _redirecting401 = false;

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

  /// Gère l'expiration du token (HTTP 401) de façon globale :
  /// vide le cache local et redirige vers /login avec une notification.
  static Future<void> _handleUnauthorized() async {
    if (_redirecting401) return;
    _redirecting401 = true;
    try {
      await StorageService.clearSession();
      final nav = pharmacyNavigatorKey.currentState;
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
                    'Session expirée. Veuillez vous reconnecter.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFFDC2626),
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
        "Serveur eDoctor injoignable. Vérifiez que l'API Laravel tourne sur $baseUrl.",
      );
    }
    return e;
  }

  // ─── AUTHENTIFICATION ─────────────────────────────────────────────────────

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

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        final token = data['token'] as String;

        await StorageService.saveSession(token: token, user: user);
        return user;
      }
      throw Exception(_msg(r, 'Identifiants incorrects'));
    } on Exception catch (e) {
      throw _net(e);
    }
  }

  static Future<void> logout() async {
    final token = await StorageService.getToken();
    try {
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl${ApiConstants.logout}'),
          headers: _headers(token),
        );
      }
    } catch (_) {}
    await StorageService.clearSession();
  }

  static Future<UserModel?> me() async {
    final token = await StorageService.getToken();
    if (token == null) return null;
    try {
      final r = await http.get(
        Uri.parse('$baseUrl${ApiConstants.me}'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 8));

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final userJson = data['user'] as Map<String, dynamic>? ?? data;
        final user = UserModel.fromJson(userJson);
        await StorageService.saveSession(token: token, user: user);
        return user;
      }
      if (r.statusCode == 401) {
        await StorageService.clearSession();
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── PHARMACIE / OFFICINE ─────────────────────────────────────────────────

  static Future<PharmacyModel> getMyPharmacy() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.myPharmacy}'),
      headers: _headers(token),
    );

    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final pharmacy = PharmacyModel.fromJson(data);
      await StorageService.savePharmacy(pharmacy);
      return pharmacy;
    }
    throw Exception(_msg(r, 'Impossible de récupérer votre officine'));
  }

  // ─── STOCKS & MÉDICAMENTS ─────────────────────────────────────────────────

  static Future<List<StockItemModel>> getStocks(int pharmacyId) async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.pharmacyStocks(pharmacyId)}'),
      headers: _headers(token),
    );

    if (r.statusCode == 200) {
      final list = jsonDecode(r.body) as List;
      return list
          .map((item) => StockItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Erreur lors du chargement des stocks'));
  }

  static Future<StockItemModel> storeOrUpdateStock({
    required int pharmacyId,
    required int medicationId,
    required int quantity,
    required double price,
  }) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.pharmacyStocks(pharmacyId)}'),
      headers: _headers(token, json: true),
      body: jsonEncode({
        'medication_id': medicationId,
        'quantity': quantity,
        'price': price,
      }),
    );

    if (r.statusCode == 200 || r.statusCode == 201) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return StockItemModel.fromJson(data);
    }
    throw Exception(_msg(r, 'Mise à jour du stock impossible'));
  }

  static Future<Map<String, dynamic>> importStocksCsv({
    required int pharmacyId,
    required String csvContent,
  }) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.pharmacyStocksImport(pharmacyId)}'),
      headers: _headers(token, json: true),
      body: jsonEncode({'csv_content': csvContent}),
    );

    if (r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception(_msg(r, "Échec de l'importation du fichier CSV"));
  }

  static Future<String> getStockTemplate() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.pharmacyStocksTemplate}'),
      headers: _headers(token),
    );

    if (r.statusCode == 200) {
      return r.body;
    }
    throw Exception(_msg(r, 'Impossible de récupérer le modèle CSV'));
  }

  static Future<Uint8List> exportStocksCsv(int pharmacyId) async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.pharmacyStocksExport(pharmacyId)}'),
      headers: _headers(token),
    );

    if (r.statusCode == 200) {
      return r.bodyBytes;
    }
    throw Exception(_msg(r, "Impossible d'exporter l'inventaire des stocks"));
  }

  // ─── COMMANDES & ORDONNANCES ─────────────────────────────────────────────

  static Future<List<OrderModel>> getOrders() async {
    final token = await StorageService.getToken();
    final r = await http.get(
      Uri.parse('$baseUrl${ApiConstants.orders}'),
      headers: _headers(token),
    );

    if (r.statusCode == 200) {
      final list = jsonDecode(r.body) as List;
      return list
          .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_msg(r, 'Erreur lors du chargement des commandes'));
  }

  static Future<OrderModel> markOrderReady(int orderId) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.orderMarkReady(orderId)}'),
      headers: _headers(token),
    );

    if (r.statusCode == 200) {
      return OrderModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    }
    throw Exception(_msg(r, 'Impossible de marquer la commande comme prête'));
  }

  static Future<OrderModel> markOrderCollected(int orderId) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.orderMarkCollected(orderId)}'),
      headers: _headers(token),
    );

    if (r.statusCode == 200) {
      return OrderModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    }
    throw Exception(_msg(r, 'Impossible de valider la remise de commande'));
  }

  static Future<OrderModel> cancelOrder(int orderId) async {
    final token = await StorageService.getToken();
    final r = await http.post(
      Uri.parse('$baseUrl${ApiConstants.orderCancel(orderId)}'),
      headers: _headers(token),
    );

    if (r.statusCode == 200) {
      return OrderModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    }
    throw Exception(_msg(r, "Impossible d'annuler la commande"));
  }

  /// Vérifie si un dossier d'agrément existe dans la base de données (par référence ou email).
  static Future<Map<String, dynamic>> trackPharmacyStatus(String query) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/pharmacies/track-status'),
        headers: _headers(null, json: true),
        body: jsonEncode({'query': query.trim()}),
      );

      final data = jsonDecode(r.body) as Map<String, dynamic>;

      if (r.statusCode == 200 && (data['found'] == true)) {
        return data;
      }

      if (r.statusCode == 404 || data['found'] == false) {
        throw Exception(
          data['message'] ??
              'Aucun dossier d\'agrément ne correspond à cet identifiant ou cette adresse email ("$query").',
        );
      }

      throw Exception(_msg(r, 'Impossible de vérifier le statut du dossier.'));
    } catch (e) {
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Erreur de connexion avec le serveur eDoctor. Veuillez réessayer.');
    }
  }

  /// Transmet le formulaire d'inscription complet à la base de données eDoctor.
  static Future<Map<String, dynamic>> registerPharmacy({
    required String pharmacyName,
    required String city,
    required String address,
    required String pharmacyPhone,
    required String officialEmail,
    required String pharmacistName,
    required String orderNumber,
    required String licenseNumber,
    required String mobilePhone,
    required String password,
    String? pharmacistEmail,
    List<String>? documentNames,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/pharmacies/register'),
      headers: _headers(null, json: true),
      body: jsonEncode({
        'pharmacy_name': pharmacyName,
        'city': city,
        'address': address,
        'pharmacy_phone': pharmacyPhone,
        'official_email': officialEmail,
        'pharmacist_name': pharmacistName,
        'order_number': orderNumber,
        'license_number': licenseNumber,
        'mobile_phone': mobilePhone,
        'pharmacist_email': pharmacistEmail ?? officialEmail,
        'password': password,
        'documents': documentNames,
      }),
    );

    final data = jsonDecode(r.body) as Map<String, dynamic>;

    if (r.statusCode == 201) {
      return data;
    }

    throw Exception(_msg(r, 'Échec de l\'enregistrement du dossier'));
  }
}
