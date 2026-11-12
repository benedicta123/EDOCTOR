import 'user_model.dart';

class PharmacyDocumentEntry {
  final String key;
  final String label;
  final String? path;
  final String? name;
  final String? mimeType;
  final int? size;

  const PharmacyDocumentEntry({
    required this.key,
    required this.label,
    this.path,
    this.name,
    this.mimeType,
    this.size,
  });

  bool get hasFile => path != null && path!.trim().isNotEmpty;

  bool get isImage {
    final lowerName = (name ?? path ?? '').toLowerCase();
    final lowerMime = (mimeType ?? '').toLowerCase();
    return lowerMime.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp');
  }

  bool get isPdf {
    final lowerName = (name ?? path ?? '').toLowerCase();
    final lowerMime = (mimeType ?? '').toLowerCase();
    return lowerMime.contains('pdf') || lowerName.endsWith('.pdf');
  }
}

class PharmacyModel {
  final int id;
  final String? referenceId;
  final String name;
  final String status; // en_attente, verifie, rejete, suspendu
  final String? address;
  final String? phone;
  final String? officialEmail;
  final String? licenseNumber;
  final String? orderNumber;
  final String? taxNumber;
  final Map<String, dynamic>? documents;
  final List<dynamic>? documentsList;
  final DateTime? verifiedAt;
  final String? rejectedReason;
  final UserModel? owner;
  final int stocksCount;
  final DateTime? createdAt;

  PharmacyModel({
    required this.id,
    this.referenceId,
    required this.name,
    required this.status,
    this.address,
    this.phone,
    this.officialEmail,
    this.licenseNumber,
    this.orderNumber,
    this.taxNumber,
    this.documents,
    this.documentsList,
    this.verifiedAt,
    this.rejectedReason,
    this.owner,
    this.stocksCount = 0,
    this.createdAt,
  });

  bool get isPending => status == 'en_attente';
  bool get isVerified => status == 'verifie';
  bool get isRejected => status == 'rejete';
  bool get isSuspended => status == 'suspendu';

  String get statusLabel {
    switch (status) {
      case 'verifie':
        return 'Officine Agréée eDoctor';
      case 'en_attente':
        return 'En attente de validation';
      case 'rejete':
        return 'Dossier rejeté';
      case 'suspendu':
        return 'Accès suspendu';
      default:
        return status;
    }
  }

  /// Retourne la liste normalisée des 4 pièces réglementaires KYP + toute autre pièce soumise.
  List<PharmacyDocumentEntry> get documentEntries {
    const standardSlots = <String, String>{
      'decree': 'Arrêté Ministériel d\'Ouverture et d\'Exploitation',
      'order_certificate': 'Attestation d\'Inscription à l\'Ordre des Pharmaciens (ONP)',
      'rccm': 'Extrait du Registre du Commerce (RCCM)',
      'id_card': 'Pièce d\'Identité du Pharmacien Titulaire (CNI / Passeport)',
    };

    final result = <PharmacyDocumentEntry>[];
    final seenKeys = <String>{};

    if (documents != null && documents!.isNotEmpty) {
      for (final slotKey in standardSlots.keys) {
        final raw = documents![slotKey];
        seenKeys.add(slotKey);
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          result.add(
            PharmacyDocumentEntry(
              key: slotKey,
              label: map['label']?.toString() ?? standardSlots[slotKey]!,
              path: map['path']?.toString(),
              name: map['name']?.toString(),
              mimeType: map['mime_type']?.toString(),
              size: (map['size'] as num?)?.toInt(),
            ),
          );
        } else if (raw is String && raw.isNotEmpty) {
          result.add(
            PharmacyDocumentEntry(
              key: slotKey,
              label: standardSlots[slotKey]!,
              path: raw,
              name: raw.split('/').last,
            ),
          );
        } else {
          result.add(
            PharmacyDocumentEntry(
              key: slotKey,
              label: standardSlots[slotKey]!,
            ),
          );
        }
      }

      // Ajouter d'éventuelles pièces supplémentaires non standard
      for (final entry in documents!.entries) {
        if (seenKeys.contains(entry.key)) continue;
        final raw = entry.value;
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          result.add(
            PharmacyDocumentEntry(
              key: entry.key,
              label: map['label']?.toString() ?? entry.key,
              path: map['path']?.toString(),
              name: map['name']?.toString(),
              mimeType: map['mime_type']?.toString(),
              size: (map['size'] as num?)?.toInt(),
            ),
          );
        } else if (raw is String && raw.isNotEmpty) {
          result.add(
            PharmacyDocumentEntry(
              key: entry.key,
              label: entry.key,
              path: raw,
              name: raw.split('/').last,
            ),
          );
        }
      }
      return result;
    }

    // Fallback si l'ancienne inscription avait soumis une List de noms de fichiers
    if (documentsList != null && documentsList!.isNotEmpty) {
      final slotKeys = standardSlots.keys.toList();
      for (var i = 0; i < standardSlots.length; i++) {
        final slotKey = slotKeys[i];
        final rawItem = i < documentsList!.length ? documentsList![i] : null;
        if (rawItem is Map) {
          final map = Map<String, dynamic>.from(rawItem);
          result.add(
            PharmacyDocumentEntry(
              key: '$i',
              label: map['label']?.toString() ?? standardSlots[slotKey]!,
              path: map['path']?.toString(),
              name: map['name']?.toString(),
              mimeType: map['mime_type']?.toString(),
            ),
          );
        } else if (rawItem is String && rawItem.isNotEmpty) {
          // Une chaîne contenant un chemin complet (ex: pharmacy_documents/...) a un fichier ; un simple nom n'en a pas
          final hasSlash = rawItem.contains('/');
          result.add(
            PharmacyDocumentEntry(
              key: '$i',
              label: standardSlots[slotKey]!,
              path: hasSlash ? rawItem : null,
              name: rawItem.split('/').last,
            ),
          );
        } else {
          result.add(
            PharmacyDocumentEntry(
              key: slotKey,
              label: standardSlots[slotKey]!,
            ),
          );
        }
      }
      return result;
    }

    // Aucun document soumis
    for (final entry in standardSlots.entries) {
      result.add(
        PharmacyDocumentEntry(
          key: entry.key,
          label: entry.value,
        ),
      );
    }
    return result;
  }

  factory PharmacyModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? docsMap;
    List<dynamic>? docsList;

    if (json['documents'] != null) {
      if (json['documents'] is Map) {
        docsMap = Map<String, dynamic>.from(json['documents'] as Map);
      } else if (json['documents'] is List) {
        docsList = List<dynamic>.from(json['documents'] as List);
      }
    }

    return PharmacyModel(
      id: json['id'] as int? ?? 0,
      referenceId: json['reference_id'] as String?,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'en_attente',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      officialEmail: json['official_email'] as String?,
      licenseNumber: json['license_number'] as String?,
      orderNumber: json['order_number'] as String?,
      taxNumber: json['tax_number'] as String?,
      documents: docsMap,
      documentsList: docsList,
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'] as String) : null,
      rejectedReason: json['rejected_reason'] as String?,
      owner: json['owner'] != null ? UserModel.fromJson(json['owner'] as Map<String, dynamic>) : null,
      stocksCount: json['stocks'] != null && json['stocks'] is List ? (json['stocks'] as List).length : 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
