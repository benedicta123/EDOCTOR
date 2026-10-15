import 'user_model.dart';

class ClaimModel {
  final int id;
  final String referenceId;
  final int userId;
  final UserModel? user;
  final String? targetType;
  final int? targetId;
  final String category;
  final String priority; // faible, normale, haute, urgente
  final String subject;
  final String description;
  final String status; // ouvert, en_cours, resolu, rejete
  final String? resolutionNotes;
  final UserModel? resolver;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  ClaimModel({
    required this.id,
    required this.referenceId,
    required this.userId,
    this.user,
    this.targetType,
    this.targetId,
    required this.category,
    required this.priority,
    required this.subject,
    required this.description,
    required this.status,
    this.resolutionNotes,
    this.resolver,
    this.resolvedAt,
    this.createdAt,
  });

  bool get isOpen => status == 'ouvert';
  bool get isInProgress => status == 'en_cours';
  bool get isResolved => status == 'resolu';
  bool get isRejected => status == 'rejete';

  String get statusLabel {
    switch (status) {
      case 'ouvert':
        return 'Nouveau / Ouvert';
      case 'en_cours':
        return 'En cours d\'instruction';
      case 'resolu':
        return 'Litige résolu';
      case 'rejete':
        return 'Réclamation rejetée';
      default:
        return status;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'urgente':
        return 'Urgente';
      case 'haute':
        return 'Haute';
      case 'normale':
        return 'Normale';
      case 'faible':
        return 'Faible';
      default:
        return priority;
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'medical':
        return 'Déontologie / Médical';
      case 'facturation':
        return 'Facturation / Paiement';
      case 'dispensation':
        return 'Pharmacie & Médicaments';
      case 'livraison':
        return 'Livraison à domicile';
      case 'technique':
        return 'Bug / Technique';
      default:
        return 'Général';
    }
  }

  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    return ClaimModel(
      id: json['id'] as int? ?? 0,
      referenceId: json['reference_id'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      user: json['user'] != null ? UserModel.fromJson(json['user'] as Map<String, dynamic>) : null,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as int?,
      category: json['category'] as String? ?? 'general',
      priority: json['priority'] as String? ?? 'normale',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'ouvert',
      resolutionNotes: json['resolution_notes'] as String?,
      resolver: json['resolver'] != null ? UserModel.fromJson(json['resolver'] as Map<String, dynamic>) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
