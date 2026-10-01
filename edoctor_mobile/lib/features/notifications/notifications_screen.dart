import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/format.dart';
import '../../data/models/consultation_model.dart';

/// Notifications du patient — 100 % données API.
class PatientNotificationsScreen extends StatefulWidget {
  const PatientNotificationsScreen({super.key});

  @override
  State<PatientNotificationsScreen> createState() =>
      _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState
    extends State<PatientNotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final unread = _items.where((n) => !n.isRead).toList();
    for (final n in unread) {
      try {
        await ApiService.markNotificationRead(n.id);
      } catch (_) {}
    }
    if (mounted) _load();
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      try {
        await ApiService.markNotificationRead(n.id);
      } catch (_) {}
      if (mounted) _load();
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'consultation_request':
      case 'consultation_started':
        return Icons.videocam_rounded;
      case 'consultation_ended':
        return Icons.check_circle_rounded;
      case 'consultation_declined':
      case 'consultation_cancelled':
        return Icons.cancel_rounded;
      case 'prescription_created':
        return Icons.receipt_long_rounded;
      case 'new_message':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_items.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Tout marquer lu',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary))
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('Réessayer')),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          Icon(
                              Icons.notifications_none_rounded,
                              size: 48,
                              color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('Aucune notification.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          SizedBox(height: 4),
                          Text(
                              'Les demandes acceptées, ordonnances et messages apparaîtront ici.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final n = _items[i];
                          return InkWell(
                            onTap: () => _open(n),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: n.isRead
                                    ? AppColors.surface
                                    : AppColors.primaryContainer,
                                borderRadius:
                                    BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.border),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: n.isRead
                                          ? AppColors.background
                                          : AppColors.surface,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                        _iconFor(n.type),
                                        color: AppColors.primary,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.message.isEmpty
                                              ? 'Notification eDoctor'
                                              : n.message,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: n.isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            color:
                                                AppColors.textPrimary,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          relativeLabel(n.createdAt),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!n.isRead)
                                    Container(
                                      width: 9,
                                      height: 9,
                                      margin:
                                          const EdgeInsets.only(top: 5),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
