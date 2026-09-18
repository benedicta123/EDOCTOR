import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class HomeCareScreen extends StatefulWidget {
  const HomeCareScreen({super.key});

  @override
  State<HomeCareScreen> createState() => _HomeCareScreenState();
}

class _HomeCareScreenState extends State<HomeCareScreen> {
  final List<Map<String, dynamic>> _visits = [
    {
      'id': 'VIS-2026-0312',
      'careType': 'Pansement stérile & Soin post-opératoire',
      'nurseName': 'Infirmière Sarah Koné',
      'nurseRole': 'Infirmière DE • CHU de Démo',
      'phone': '+225 05 00 00 03 02',
      'date': 'Demain à 10:00',
      'address': 'Cocody Angré 8ème Tranche, Abidjan',
      'status': 'confirme',
      'statusLabel': 'Confirmée • En route',
      'statusColor': AppColors.primary,
      'statusBg': AppColors.primaryContainer,
      'price': 6000,
    },
    {
      'id': 'VIS-2026-0245',
      'careType': 'Prélèvement sanguin & Bilan hépatique',
      'nurseName': 'Infirmier Paul Yao',
      'nurseRole': 'Infirmier DE • CHU de Démo',
      'phone': '+225 05 00 00 03 01',
      'date': '10 Août 2026 à 11:00',
      'address': 'Cocody Angré 8ème Tranche, Abidjan',
      'status': 'termine',
      'statusLabel': 'Soin effectué avec succès',
      'statusColor': AppColors.success,
      'statusBg': AppColors.successLight,
      'price': 5000,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Soins à Domicile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière explicative CHU de Démo
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF0C594C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.home_repair_service_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Infirmiers Diplômés d\'État',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Personnel soignant rattaché au CHU de Démo disponible pour vos soins à domicile.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bouton de nouvelle demande
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _openNewCareBookingModal,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'Demander une visite infirmière',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 26),

            // Soins Disponibles
            const Text(
              'Soins dispensés à domicile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCareServiceChip(
                    icon: Icons.vaccines_rounded,
                    title: 'Injections & Perfusions',
                    price: 'Dès 3 500 FCFA',
                  ),
                  const SizedBox(width: 10),
                  _buildCareServiceChip(
                    icon: Icons.healing_rounded,
                    title: 'Pansements & Plaies',
                    price: 'Dès 4 000 FCFA',
                  ),
                  const SizedBox(width: 10),
                  _buildCareServiceChip(
                    icon: Icons.bloodtype_rounded,
                    title: 'Prélèvements sanguins',
                    price: 'Dès 5 000 FCFA',
                  ),
                  const SizedBox(width: 10),
                  _buildCareServiceChip(
                    icon: Icons.monitor_heart_rounded,
                    title: 'Surveillance constantes',
                    price: 'Dès 2 500 FCFA',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // Visites programmées & Historique
            const Text(
              'Mes demandes & interventions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            ..._visits.map((vis) => _buildVisitCard(vis)),
          ],
        ),
      ),
    );
  }

  Widget _buildCareServiceChip({
    required IconData icon,
    required String title,
    required String price,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> vis) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vis['id'] as String,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMuted),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: vis['statusBg'] as Color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  vis['statusLabel'] as String,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: vis['statusColor'] as Color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            vis['careType'] as String,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),

          // Praticien assigné
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer,
                ),
                child: const Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vis['nurseName'] as String,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      vis['nurseRole'] as String,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                vis['date'] as String,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vis['address'] as String,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Honoraires : ${vis['price']} FCFA',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              if (vis['status'] == 'confirme') ...[
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Appel vers ${vis['phone']}...')),
                    );
                  },
                  icon: const Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
                  label: const Text(
                    'Appeler l\'infirmier',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _openNewCareBookingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Demande de soin infirmier',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'L\'hôpital CHU de Démo assignera un infirmier disponible (Infirmier Paul Yao ou Infirmière Sarah Koné).',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              const Text(
                'Type d\'intervention :',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: 'Pansement stérile & Soin post-opératoire',
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Pansement stérile & Soin post-opératoire',
                    child: Text('Pansement stérile & Soin post-opératoire (4 000 FCFA)'),
                  ),
                  DropdownMenuItem(
                    value: 'Injections & Perfusions',
                    child: Text('Injections & Perfusions (3 500 FCFA)'),
                  ),
                  DropdownMenuItem(
                    value: 'Prélèvement sanguin & Bilan',
                    child: Text('Prélèvement sanguin & Bilan (5 000 FCFA)'),
                  ),
                  DropdownMenuItem(
                    value: 'Surveillance constantes vitales',
                    child: Text('Surveillance constantes vitales (2 500 FCFA)'),
                  ),
                ],
                onChanged: (_) {},
              ),

              const SizedBox(height: 16),
              const Text(
                'Adresse de prise en charge :',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),

              TextFormField(
                initialValue: 'Cocody Angré 8ème Tranche, Abidjan',
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.home_outlined),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Demande de visite transmise au CHU de Démo ! Confirmation sous 15 min.'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Confirmer la demande',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
