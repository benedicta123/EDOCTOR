import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import '../core/widgets/ui_kit.dart';
import '../core/widgets/praticien_nav.dart';
import '../data/models/nurse_visit_model.dart';

class NotificationsScreen extends StatefulWidget {
  final PraticienNav? nav;
  const NotificationsScreen({super.key, this.nav});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notifications = await ApiService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  IconData _iconFor(String type) {
    if (type.contains('consultation')) {
      return Icons.calendar_month_rounded;
    }
    if (type.contains('prescription') || type.contains('ordonnance')) {
      return Icons.receipt_long_rounded;
    }
    if (type.contains('visit') || type.contains('visite')) {
      return Icons.home_repair_service_rounded;
    }
    if (type.contains('hospital') || type.contains('hopital')) {
      return Icons.apartment_rounded;
    }
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;

    return ResponsiveShell(
      title: 'Notifications',
      subtitle: _notifications.isEmpty
          ? 'Actualités et alertes de votre espace'
          : '${_notifications.length} notification(s) · $unread non lue(s)',
      scrollable: true,
      onRefresh: _load,
      nav: widget.nav,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          : _notifications.isEmpty
              ? const EmptyStateCard(
                  icon: Icons.notifications_none_rounded,
                  title: 'Aucune notification',
                  message:
                      'Vous serez alerté ici dès qu’un patient ou un membre de votre établissement agit sur votre espace.',
                )
              : Column(
                  children: _notifications.map((notification) {
                    final unreadItem = !notification.isRead;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: unreadItem
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: unreadItem
                                ? AppColors.primaryContainer
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconFor(notification.type),
                            color: unreadItem
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          notification.type.replaceAll('_', ' '),
                          style: TextStyle(
                            fontWeight: unreadItem
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 14.5,
                            color: unreadItem
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            notification.message,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                height: 1.4),
                          ),
                        ),
                        trailing: unreadItem
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Nouveau',
                                  style: TextStyle(
                                    color: AppColors.primaryHover,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : const Icon(Icons.check_rounded,
                                size: 18, color: AppColors.textMuted),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
