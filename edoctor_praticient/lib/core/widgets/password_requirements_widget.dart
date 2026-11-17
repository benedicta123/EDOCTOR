import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Règles de sécurité des mots de passe harmonisées avec le backend eDoctor.
class PasswordSecurityHelper {
  PasswordSecurityHelper._();

  static bool hasMinLength(String pwd) => pwd.length >= 8;

  static bool hasMixedCase(String pwd) =>
      RegExp(r'[a-z]').hasMatch(pwd) && RegExp(r'[A-Z]').hasMatch(pwd);

  static bool hasDigit(String pwd) => RegExp(r'[0-9]').hasMatch(pwd);

  static bool hasSpecialChar(String pwd) =>
      RegExp(r'[^a-zA-Z0-9]').hasMatch(pwd);

  static bool isCompliant(String pwd) =>
      hasMinLength(pwd) &&
      hasMixedCase(pwd) &&
      hasDigit(pwd) &&
      hasSpecialChar(pwd);

  static int criteriaMetCount(String pwd) {
    int count = 0;
    if (hasMinLength(pwd)) count++;
    if (hasMixedCase(pwd)) count++;
    if (hasDigit(pwd)) count++;
    if (hasSpecialChar(pwd)) count++;
    return count;
  }

  /// Validateur pour formulaire TextFormField.
  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez saisir un mot de passe';
    }
    if (!hasMinLength(value)) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    if (!hasMixedCase(value)) {
      return 'Incluez au moins une lettre majuscule et une minuscule';
    }
    if (!hasDigit(value)) {
      return 'Incluez au moins un chiffre (0-9)';
    }
    if (!hasSpecialChar(value)) {
      return 'Incluez au moins un caractère spécial (@, #, \$, !, %, etc.)';
    }
    return null;
  }
}

/// Widget réactif affichant en temps réel la force du mot de passe
/// et la liste interactive des critères de sécurité attendus par le système.
class PasswordRequirementsWidget extends StatelessWidget {
  final TextEditingController controller;

  const PasswordRequirementsWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pwd = controller.text;
        final hasLength = PasswordSecurityHelper.hasMinLength(pwd);
        final hasMixed = PasswordSecurityHelper.hasMixedCase(pwd);
        final hasNum = PasswordSecurityHelper.hasDigit(pwd);
        final hasSym = PasswordSecurityHelper.hasSpecialChar(pwd);

        final metCount = PasswordSecurityHelper.criteriaMetCount(pwd);
        final isAllValid = metCount == 4;

        Color strengthColor;
        String strengthLabel;
        if (pwd.isEmpty) {
          strengthColor = AppColors.textMuted;
          strengthLabel = 'Requis pour sécuriser votre compte administrateur';
        } else if (metCount <= 1) {
          strengthColor = const Color(0xFFEF4444);
          strengthLabel = 'Mot de passe très faible';
        } else if (metCount == 2) {
          strengthColor = const Color(0xFFF97316);
          strengthLabel = 'Mot de passe faible';
        } else if (metCount == 3) {
          strengthColor = const Color(0xFFF59E0B);
          strengthLabel = 'Mot de passe moyen';
        } else {
          strengthColor = AppColors.primary;
          strengthLabel = 'Mot de passe fort & conforme';
        }

        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isAllValid
                ? AppColors.successLight
                : (pwd.isNotEmpty
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFFF1F5F9).withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAllValid
                  ? AppColors.success.withValues(alpha: 0.4)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isAllValid
                        ? Icons.verified_user_rounded
                        : Icons.security_rounded,
                    size: 16,
                    color: strengthColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strengthLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: pwd.isEmpty
                            ? AppColors.textSecondary
                            : strengthColor,
                      ),
                    ),
                  ),
                  if (pwd.isNotEmpty)
                    Text(
                      '$metCount / 4',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: strengthColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(4, (index) {
                  final active = pwd.isNotEmpty && index < metCount;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: active
                            ? strengthColor
                            : const Color(0xFFCBD5E1).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              _buildCriterion(
                label: 'Au moins 8 caractères',
                isValid: hasLength,
              ),
              const SizedBox(height: 4),
              _buildCriterion(
                label: 'Une majuscule (A-Z) et une minuscule (a-z)',
                isValid: hasMixed,
              ),
              const SizedBox(height: 4),
              _buildCriterion(
                label: 'Au moins un chiffre (0-9)',
                isValid: hasNum,
              ),
              const SizedBox(height: 4),
              _buildCriterion(
                label: 'Au moins un caractère spécial (@, #, \$, !, %, etc.)',
                isValid: hasSym,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCriterion({
    required String label,
    required bool isValid,
  }) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 13,
          color: isValid ? AppColors.success : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isValid ? FontWeight.w600 : FontWeight.w400,
              color: isValid ? AppColors.success : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
