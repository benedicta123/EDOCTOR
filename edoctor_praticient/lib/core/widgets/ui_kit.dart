import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'praticien_nav.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: AppColors.primary),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      );
    }
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint ?? label,
            prefixIcon: icon == null
                ? null
                : Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 20),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Statut sémantique : vert = en cours / validé, ambre = attente,
/// bleu nuit = terminé (clos), rouge = annulé / rejeté.
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color get bg {
    switch (status) {
      case 'en_cours':
      case 'assignee':
        return AppColors.primaryContainer;
      case 'en_attente':
        return AppColors.warningLight;
      case 'terminee':
        return AppColors.secondaryContainer;
      case 'validee':
      case 'verifie':
        return AppColors.successLight;
      case 'annulee':
      case 'rejete':
      case 'suspendu':
        return AppColors.errorLight;
      default:
        return AppColors.surfaceDim;
    }
  }

  Color get fg {
    switch (status) {
      case 'en_cours':
      case 'assignee':
        return AppColors.primaryHover;
      case 'en_attente':
        return AppColors.warning;
      case 'terminee':
        return AppColors.secondary;
      case 'validee':
      case 'verifie':
        return AppColors.success;
      case 'annulee':
      case 'rejete':
      case 'suspendu':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String get label {
    switch (status) {
      case 'en_attente':
        return 'En attente';
      case 'en_cours':
        return 'En cours';
      case 'terminee':
        return 'Terminée';
      case 'annulee':
        return 'Annulée';
      case 'validee':
        return 'Validée';
      case 'verifie':
        return 'Vérifié';
      case 'assignee':
        return 'Assignée';
      case 'rejete':
        return 'Rejeté';
      case 'suspendu':
        return 'Suspendu';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Carte statistique homogène : icône teintée, valeur, libellé.
/// width null → la carte remplit la cellule de grille parente.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Color tint;
  final double? width;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    Color? tint,
    this.width = 170,
  }) : tint = tint ?? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Titre de section avec action facultative (ex. « Tout voir »).
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded, size: 15),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

/// État vide explicite : icône, titre, explication.
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Couple libellé / valeur réutilisé par les pages profil et fiche hôpital.
class InfoTile extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;

  const InfoTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return SizedBox(
      width: 235,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasValue ? value! : 'Non renseigné',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: hasValue
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Conserve la valeur entière d'une donnée API dynamique sans planter.
int intOrNull(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// « Dr Paul Koffi » reste tel quel ; « Paul Koffi » devient « Dr Paul Koffi ».
String doctorDisplay(String name) =>
    name.toLowerCase().startsWith('dr') ? name : 'Dr $name';

/// Formate une date ISO API en « 16/09/2026 à 14:30 » ; null → '—'.
String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
}

/// Coquille responsive PWA praticien :
///  - ≥ 1000 px : menu latéral fixe pleine hauteur + en-tête au-dessus du contenu ;
///  - < 1000 px : en-tête avec bouton menu + drawer superposable.
class ResponsiveShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;
  final PraticienNav? nav;
  final bool scrollable;
  final Future<void> Function()? onRefresh;

  static const double sidebarBreakpoint = 1000;
  static const double sidebarWidth = 264;

  const ResponsiveShell({
    super.key,
    required this.title,
    this.subtitle = '',
    this.actions = const [],
    required this.child,
    this.nav,
    this.scrollable = false,
    this.onRefresh,
  });

  void _goSection(BuildContext context, PraticienNav nav, NavSection section) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
    final screen = navSectionScreen(nav, section);
    if (screen == null) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: const Duration(milliseconds: 160),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _header(BuildContext context, {required bool showMenu, required bool showBack}) {
    return Container(
      height: 68,
      color: AppColors.secondary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (showBack && Navigator.of(context).canPop())
                IconButton(
                  tooltip: 'Retour',
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              else if (showMenu)
                IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.66),
                              fontSize: 12,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ...actions,
              if (showMenu && showBack && Navigator.of(context).canPop())
                IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    Widget content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: child,
        ),
      ),
    );
    if (scrollable) {
      content = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: content,
      );
    }
    if (onRefresh != null) {
      content = RefreshIndicator(onRefresh: onRefresh!, child: content);
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final nav = this.nav;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= sidebarBreakpoint;
          final canPop = Navigator.of(context).canPop();

          if (wide && nav != null) {
            // Sidebar fixe pleine hauteur + en-tête au-dessus du contenu.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: sidebarWidth,
                  child: Material(
                    color: AppColors.secondary,
                    child: SafeArea(
                      bottom: false,
                      child: NavPanel(
                        nav: nav,
                        onNavigate: (s) => _goSection(context, nav, s),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _header(context, showMenu: false, showBack: canPop),
                      Expanded(child: _content()),
                    ],
                  ),
                ),
              ],
            );
          }

          if (wide) {
            return Column(
              children: [
                _header(context, showMenu: false, showBack: canPop),
                Expanded(child: _content()),
              ],
            );
          }

          // Petit écran : drawer superposable.
          final showBack = canPop;
          final showMenu = nav != null;
          return Column(
            children: [
              _header(context, showMenu: showMenu, showBack: showBack),
              Expanded(child: _content()),
            ],
          );
        },
      ),
      // Drawer monté en overlay, contenu identique au sidebar fixe.
      drawer: nav == null
          ? null
          : Drawer(
              backgroundColor: AppColors.secondary,
              child: SafeArea(
                bottom: false,
                child: Builder(
                  builder: (drawerContext) {
                    // Fermeture puis navigation, comme depuis le sidebar.
                    void navigate(NavSection s) {
                      Navigator.of(drawerContext).pop();
                      final screen = navSectionScreen(nav, s);
                      if (screen == null) return;
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => screen,
                          transitionDuration:
                              const Duration(milliseconds: 160),
                          transitionsBuilder: (_, animation, __, child) =>
                              FadeTransition(
                                  opacity: animation, child: child),
                        ),
                      );
                    }

                    return NavPanel(nav: nav, onNavigate: navigate);
                  },
                ),
              ),
            ),
    );
  }
}

void showMsg(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
