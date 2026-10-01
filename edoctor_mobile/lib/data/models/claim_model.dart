import 'package:flutter/material.dart';

class ClaimModel {
  final int id;
  final String referenceId;
  final int userId;
  final String category; // medical, pharmacie, livraison, facturation, technique, autre
  final String priority; // faible, normale, haute, urgente
  final String subject;
  final String description;
  final String status; // ouvert, en_cours, resolu, rejete
  final String? resolutionNotes;
  final String? resolverName;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  ClaimModel({
    required this.id,
    required this.referenceId,
    required this.userId,
    required this.category,
    required this.priority,
    required this.subject,
    required this.description,
    required this.status,
    this.resolutionNotes,
    this.resolverName,
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
        return 'Nouveau / En attente';
      case 'en_cours':
        return 'En cours d’examen';
      case 'resolu':
        return 'Résolu';
      case 'rejete':
        return 'Rejeté / Sans suite';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'ouvert':
        return const Color(0xFFEAB308); // Jaune / Ambre
      case 'en_cours':
        return const Color(0xFF3B82F6); // Bleu
      case 'resolu':
        return const Color(0xFF10B981); // Vert émeraude
      case 'rejete':
        return const Color(0xFFEF4444); // Rouge
      default:
        return Colors.grey;
    }
  }

  Color get statusBgColor {
    switch (status) {
      case 'ouvert':
        return const Color(0xFFFEF9C3);
      case 'en_cours':
        return const Color(0xFFDBEAFE);
      case 'resolu':
        return const Color(0xFFD1FAE5);
      case 'rejete':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'medical':
        return 'Téléconsultation / Praticien';
      case 'pharmacie':
        return 'Pharmacie & Médicaments';
      case 'livraison':
        return 'Livraison à domicile';
      case 'facturation':
        return 'Facturation / Paiement';
      case 'technique':
        return 'Application / Bug technique';
      case 'autre':
      default:
        return 'Autre demande';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case 'medical':
        return Icons.medical_services_rounded;
      case 'pharmacie':
        return Icons.local_pharmacy_rounded;
      case 'livraison':
        return Icons.delivery_dining_rounded;
      case 'facturation':
        return Icons.credit_card_rounded;
      case 'technique':
        return Icons.bug_report_rounded;
      case 'autre':
      default:
        return Icons.help_outline_rounded;
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

  String get formattedDate {
    if (createdAt == null) return 'Récemment';
    final dt = createdAt!;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    final resolver = json['resolver'] as Map<String, dynamic>?;
    return ClaimModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      referenceId: json['reference_id'] as String? ?? '',
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? 'autre',
      priority: json['priority'] as String? ?? 'normale',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'ouvert',
      resolutionNotes: json['resolution_notes'] as String?,
      resolverName: resolver?['name'] as String?,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
