class HospitalAppointmentModel {
  final int id;
  final String referenceCode;
  final int hospitalId;
  final int patientId;
  final int? doctorId;
  final String department;
  final String appointmentDate;
  final String timeSlot;
  final int? queueNumber;
  final String? reason;
  final String status;
  final double consultationFee;
  final String? doctorNotes;
  final String? checkedInAt;
  final String? calledAt;
  final String? completedAt;
  final String patientName;
  final String? patientPhone;
  final String? patientEmail;
  final String? patientBirthDate;
  final String? patientBloodGroup;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? assignedByName;
  final String? hospitalName;

  const HospitalAppointmentModel({
    required this.id,
    required this.referenceCode,
    required this.hospitalId,
    required this.patientId,
    this.doctorId,
    required this.department,
    required this.appointmentDate,
    required this.timeSlot,
    this.queueNumber,
    this.reason,
    required this.status,
    required this.consultationFee,
    this.doctorNotes,
    this.checkedInAt,
    this.calledAt,
    this.completedAt,
    required this.patientName,
    this.patientPhone,
    this.patientEmail,
    this.patientBirthDate,
    this.patientBloodGroup,
    this.doctorName,
    this.doctorSpecialty,
    this.assignedByName,
    this.hospitalName,
  });

  bool get isWaiting => status == 'en_attente';
  bool get isInConsultation => status == 'en_consultation';
  bool get isBooked => status == 'reserve';
  bool get isCompleted => status == 'termine';
  bool get isCancelled => status == 'annule';

  factory HospitalAppointmentModel.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>?;
    final doctor = json['doctor'] as Map<String, dynamic>?;
    final hospital = json['hospital'] as Map<String, dynamic>?;
    final assignedBy = json['assigned_by'] as Map<String, dynamic>?;

    return HospitalAppointmentModel(
      id: json['id'] as int? ?? 0,
      referenceCode: json['reference_code'] as String? ?? '',
      hospitalId: json['hospital_id'] as int? ?? 0,
      patientId: json['patient_id'] as int? ?? 0,
      doctorId: json['doctor_id'] as int?,
      department: json['department'] as String? ?? 'Médecine Générale',
      appointmentDate: json['appointment_date'] as String? ?? '',
      timeSlot: json['time_slot'] as String? ?? '',
      queueNumber: json['queue_number'] as int?,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'reserve',
      consultationFee: (json['consultation_fee'] != null)
          ? double.tryParse(json['consultation_fee'].toString()) ?? 0.0
          : 0.0,
      doctorNotes: json['doctor_notes'] as String?,
      checkedInAt: json['checked_in_at'] as String?,
      calledAt: json['called_at'] as String?,
      completedAt: json['completed_at'] as String?,
      patientName: patient?['name'] as String? ?? 'Patient #${json['patient_id']}',
      patientPhone: patient?['phone'] as String?,
      patientEmail: patient?['email'] as String?,
      patientBirthDate: (patient?['date_of_birth'] ?? patient?['birth_date']) as String?,
      patientBloodGroup: patient?['blood_group'] as String?,
      doctorName: doctor?['name'] as String?,
      doctorSpecialty: doctor?['specialty'] as String?,
      assignedByName: assignedBy?['name'] as String?,
      hospitalName: hospital?['name'] as String?,
    );
  }
}
