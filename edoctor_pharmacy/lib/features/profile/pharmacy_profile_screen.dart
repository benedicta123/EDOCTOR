import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/pharmacy_shell.dart';
import '../../data/models/user_model.dart';
import '../../data/models/pharmacy_model.dart';

class PharmacyProfileScreen extends StatefulWidget {
  const PharmacyProfileScreen({super.key});

  @override
  State<PharmacyProfileScreen> createState() => _PharmacyProfileScreenState();
}

class _PharmacyProfileScreenState extends State<PharmacyProfileScreen> {
  UserModel? _user;
  PharmacyModel? _pharmacy;
  bool _loading = true;
  bool _isDuty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final pharmacy = await ApiService.getMyPharmacy();
      if (mounted) {
        setState(() {
          _user = user;
          _pharmacy = pharmacy;
          _isDuty = pharmacy.isDuty;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.outOfStock,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PharmacyShell(
      currentSection: PharmacySection.profile,
      title: 'Fiche Officine',
      user: _user,
      pharmacy: _pharmacy,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Carte Officine de garde (Mise en avant)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isDuty ? AppColors.primaryContainer : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isDuty ? AppColors.primary : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _isDuty ? AppColors.primary : AppColors.surfaceDim,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.nightlight_round,
                                color: _isDuty ? Colors.white : AppColors.textMuted,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Statut de garde (Pharmacie de garde)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isDuty
                                        ? 'Votre officine est signalée comme ouverte de garde aux patients sur eDoctor Togo.'
                                        : 'Activez ce bouton lorsque votre officine assure la garde de nuit ou du week-end.',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isDuty,
                              activeTrackColor: AppColors.primary,
                              onChanged: (val) {
                                setState(() => _isDuty = val);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(val
                                        ? 'Officine enregistrée de garde.'
                                        : 'Statut de garde désactivé.'),
                                    backgroundColor: AppColors.inStock,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Carte Coordonnées
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Coordonnées de l\'officine',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _infoRow(
                              Icons.storefront_rounded,
                              'Nom commercial',
                              _pharmacy?.name ?? 'Pharmacie',
                            ),
                            const Divider(height: 24),
                            _infoRow(
                              Icons.location_on_outlined,
                              'Adresse physique',
                              _pharmacy?.address ?? 'Lomé, Togo',
                            ),
                            const Divider(height: 24),
                            _infoRow(
                              Icons.phone_outlined,
                              'Téléphone de permanence',
                              _pharmacy?.phone.isNotEmpty == true ? _pharmacy!.phone : '+228 90 00 00 00',
                            ),
                            const Divider(height: 24),
                            _infoRow(
                              Icons.person_outline_rounded,
                              'Pharmacien titulaire',
                              _user?.name ?? 'Pharmacien responsable',
                            ),
                            const Divider(height: 24),
                            _infoRow(
                              Icons.verified_outlined,
                              'Certification',
                              'Ordre National des Pharmaciens du Togo • eDoctor Vérifié',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
