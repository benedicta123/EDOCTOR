import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BadgeChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color? borderColor;
  final IconData? icon;

  const BadgeChip({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.borderColor,
    this.icon,
  });

  factory BadgeChip.status(String status) {
    switch (status.toLowerCase()) {
      case 'verifie':
        return const BadgeChip(
          label: 'Partenaire Certifié',
          textColor: AppColors.verified,
          backgroundColor: AppColors.verifiedBg,
          borderColor: AppColors.verifiedBorder,
          icon: Icons.verified_rounded,
        );
      case 'en_attente':
        return const BadgeChip(
          label: 'En attente d\'audit',
          textColor: AppColors.pending,
          backgroundColor: AppColors.pendingBg,
          borderColor: AppColors.pendingBorder,
          icon: Icons.hourglass_top_rounded,
        );
      case 'rejete':
        return const BadgeChip(
          label: 'Rejeté',
          textColor: AppColors.rejected,
          backgroundColor: AppColors.rejectedBg,
          borderColor: AppColors.rejectedBorder,
          icon: Icons.cancel_outlined,
        );
      case 'suspendu':
        return const BadgeChip(
          label: 'Suspendu',
          textColor: AppColors.suspended,
          backgroundColor: AppColors.suspendedBg,
          borderColor: AppColors.suspendedBorder,
          icon: Icons.block_rounded,
        );
      case 'actif':
        return const BadgeChip(
          label: 'Actif',
          textColor: AppColors.verified,
          backgroundColor: AppColors.verifiedBg,
          borderColor: AppColors.verifiedBorder,
          icon: Icons.check_circle_outline_rounded,
        );
      default:
        return BadgeChip(
          label: status,
          textColor: AppColors.textSecondary,
          backgroundColor: AppColors.surfaceDim,
          borderColor: AppColors.border,
        );
    }
  }

  factory BadgeChip.priority(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgente':
        return const BadgeChip(
          label: 'URGENTE',
          textColor: AppColors.priorityUrgent,
          backgroundColor: Color(0xFFFFE4E6),
          borderColor: Color(0xFFFECDD3),
          icon: Icons.error_rounded,
        );
      case 'haute':
        return const BadgeChip(
          label: 'Haute',
          textColor: AppColors.priorityHigh,
          backgroundColor: Color(0xFFFFEDD5),
          borderColor: Color(0xFFFED7AA),
          icon: Icons.warning_amber_rounded,
        );
      case 'normale':
        return const BadgeChip(
          label: 'Normale',
          textColor: AppColors.priorityNormal,
          backgroundColor: Color(0xFFEFF6FF),
          borderColor: Color(0xFFBFDBFE),
          icon: Icons.info_outline_rounded,
        );
      default:
        return const BadgeChip(
          label: 'Faible',
          textColor: AppColors.priorityLow,
          backgroundColor: Color(0xFFF1F5F9),
          borderColor: Color(0xFFE2E8F0),
          icon: Icons.remove_circle_outline_rounded,
        );
    }
  }

  factory BadgeChip.role(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return const BadgeChip(
          label: 'Médecin',
          textColor: Color(0xFF0369A1),
          backgroundColor: Color(0xFFE0F2FE),
          borderColor: Color(0xFFBAE6FD),
          icon: Icons.medical_services_outlined,
        );
      case 'pharmacist':
        return const BadgeChip(
          label: 'Pharmacien',
          textColor: Color(0xFF0D9488),
          backgroundColor: Color(0xFFCCFBF1),
          borderColor: Color(0xFF99F6E4),
          icon: Icons.local_pharmacy_outlined,
        );
      case 'nurse':
        return const BadgeChip(
          label: 'Infirmier(ère)',
          textColor: Color(0xFF7C3AED),
          backgroundColor: Color(0xFFF3E8FF),
          borderColor: Color(0xFFE9D5FF),
          icon: Icons.healing_outlined,
        );
      case 'admin':
        return const BadgeChip(
          label: 'Administrateur',
          textColor: Color(0xFFB45309),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFFDE68A),
          icon: Icons.shield_outlined,
        );
      default:
        return const BadgeChip(
          label: 'Patient',
          textColor: Color(0xFF475569),
          backgroundColor: Color(0xFFF8FAFC),
          borderColor: Color(0xFFE2E8F0),
          icon: Icons.person_outline_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? backgroundColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
