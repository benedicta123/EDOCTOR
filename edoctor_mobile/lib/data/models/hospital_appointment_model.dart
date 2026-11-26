import 'package:flutter/material.dart';

class HospitalModel {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final double consultationFee;

  const HospitalModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.consultationFee = 3000,
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) => HospitalModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Hôpital',
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        consultationFee: double.tryParse(json['consultation_fee']?.toString() ?? '') ?? 3000,
      );
}

class SlotModel {
  final String timeSlot;
  final int bookedCount;
  final bool available;
  final int remaining;

  const SlotModel({
    required this.timeSlot,
    required this.bookedCount,
    required this.available,
    required this.remaining,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) => SlotModel(
        timeSlot: json['time_slot'] as String? ?? '',
        bookedCount: (json['booked_count'] as num?)?.toInt() ?? 0,
        available: json['available'] as bool? ?? false,
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      );
}

class AppointmentDoctorModel {
  final int id;
  final String name;
  final String? specialty;
  final String? phone;

  const AppointmentDoctorModel({
    required this.id,
    required this.name,
    this.specialty,
    this.phone,
  });

  factory AppointmentDoctorModel.fromJson(Map<String, dynamic> json) =>
      AppointmentDoctorModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Médecin',
        specialty: json['specialty'] as String?,
        phone: json['phone'] as String?,
      );
}

class HospitalAppointmentModel {
  final int id;
  final String referenceCode;
  final int hospitalId;
  final int patientId;
  final int? doctorId;
  final String department;
  final DateTime appointmentDate;
  final String timeSlot;
  final int queueNumber;
  final String? reason;
  final String status;
  final double consultationFee;
  final String? doctorNotes;
  final DateTime? checkedInAt;
  final DateTime? calledAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final HospitalModel? hospital;
  final AppointmentDoctorModel? doctor;
  final DateTime createdAt;

  const HospitalAppointmentModel({
    required this.id,
    required this.referenceCode,
    required this.hospitalId,
    required this.patientId,
    this.doctorId,
    required this.department,
    required this.appointmentDate,
    required this.timeSlot,
    required this.queueNumber,
    this.reason,
    required this.status,
    required this.consultationFee,
    this.doctorNotes,
    this.checkedInAt,
    this.calledAt,
    this.completedAt,
    this.cancelledAt,
    this.hospital,
    this.doctor,
    required this.createdAt,
  });

  factory HospitalAppointmentModel.fromJson(Map<String, dynamic> json) {
    return HospitalAppointmentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      referenceCode: json['reference_code'] as String? ?? '',
      hospitalId: (json['hospital_id'] as num?)?.toInt() ?? 0,
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      doctorId: (json['doctor_id'] as num?)?.toInt(),
      department: json['department'] as String? ?? '',
      appointmentDate: DateTime.tryParse(json['appointment_date'] as String? ?? '') ?? DateTime.now(),
      timeSlot: json['time_slot'] as String? ?? '',
      queueNumber: (json['queue_number'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'reserve',
      consultationFee: double.tryParse(json['consultation_fee']?.toString() ?? '') ?? 3000,
      doctorNotes: json['doctor_notes'] as String?,
      checkedInAt: json['checked_in_at'] != null ? DateTime.tryParse(json['checked_in_at'] as String) : null,
      calledAt: json['called_at'] != null ? DateTime.tryParse(json['called_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'] as String) : null,
      hospital: json['hospital'] != null ? HospitalModel.fromJson(json['hospital'] as Map<String, dynamic>) : null,
      doctor: json['doctor'] != null ? AppointmentDoctorModel.fromJson(json['doctor'] as Map<String, dynamic>) : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'reserve':
        return 'Réservé';
      case 'en_attente':
        return 'En salle d\'attente';
      case 'en_consultation':
        return 'En consultation';
      case 'termine':
        return 'Terminé';
      case 'annule':
        return 'Annulé';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'reserve':
        return const Color(0xFF2196F3);
      case 'en_attente':
        return const Color(0xFFFF9800);
      case 'en_consultation':
        return const Color(0xFF4CAF50);
      case 'termine':
        return const Color(0xFF9E9E9E);
      case 'annule':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  bool get isCancellable => status == 'reserve';
  bool get isActive => status == 'reserve' || status == 'en_attente' || status == 'en_consultation';
  bool get isDone => status == 'termine' || status == 'annule';
}
