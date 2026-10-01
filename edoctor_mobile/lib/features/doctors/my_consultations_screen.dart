import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/format.dart';
import '../../data/models/consultation_model.dart';
import 'consultation_screen.dart';

/// Historique des consultations du patient : en cours / en attente d'abord,
/// puis terminées et annulées (discussion relisible, sans nouvel envoi).
class MyConsultationsScreen extends StatefulWidget {
  const MyConsultationsScreen({super.key});

  @override
  State<MyConsultationsScreen> createState() => _MyConsultationsScreenState();
}

class _MyConsultationsScreenState extends State<MyConsultationsScreen> {
  List<ConsultationModel> _items = [];
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
      final items = await ApiService.getMyConsultations();
      if (!mounted) return;
      items.sort((a, b) {
        int rank(ConsultationModel c) =>
            c.isActive ? 0 : (c.isPending ? 1 : 2);
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return b.id.compareTo(a.id);
      });
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

  void _open(ConsultationModel c) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PatientConsultationScreen(consultation: c),
          ),
        )
        .then((_) => _load());
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mes consultations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon:
                const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _load,
          ),
          const SizedBox(width: 6),
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
                          Icon(Icons.event_available_rounded,
                              size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('Aucune consultation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          SizedBox(height: 4),
                          Text(
                              'Vos consultations passées et en cours apparaîtront ici.',
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
                        itemBuilder: (context, i) =>
                            _tile(_items[i]),
                      ),
      ),
    );
  }

  Widget _tile(ConsultationModel c) {
    final date =
        c.startedAt ?? c.scheduledAt ?? c.createdAt;
    Color dot;
    String label;
    switch (c.status) {
      case 'en_cours':
        dot = AppColors.primary;
        label = 'En cours — Rejoindre';
        break;
      case 'en_attente':
        dot = AppColors.warning;
        label = 'En attente d’acceptation';
        break;
      case 'terminee':
        dot = AppColors.textMuted;
        label = 'Terminée — Relire la discussion';
        break;
      default:
        dot = AppColors.error;
        label = 'Annulée — Relire la discussion';
    }
    return InkWell(
      onTap: () => _open(c),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.isActive
              ? AppColors.primaryContainer
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.isActive
                    ? AppColors.primary
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                c.isDone
                    ? Icons.history_rounded
                    : (c.isActive
                        ? Icons.videocam_rounded
                        : Icons.hourglass_top_rounded),
                color: c.isActive ? Colors.white : dot,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.doctorName.isNotEmpty
                              ? 'Dr. ${c.doctorName}'
                              : 'Consultation ${c.displayCode}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          c.displayCode,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDateTime(date),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dot,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
