import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/format.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/prescription_model.dart';
import '../../core/services/prescription_pdf_service.dart';
import '../orders/orders_screen.dart';
import '../home_care/home_care_screen.dart';

/// Ordonnances du patient — 100 % données API (émises par les médecins).
class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  List<PatientPrescription> _items = [];
  Map<int, ConsultationModel> _consultationsById = {};
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
      final prescriptions = await ApiService.getPrescriptions();
      Map<int, ConsultationModel> byId = {};
      try {
        final consultations = await ApiService.getMyConsultations();
        byId = {for (final c in consultations) c.id: c};
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = prescriptions;
        _consultationsById = byId;
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
          'Mes Prescriptions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _load,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('Aucune ordonnance pour le moment.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          SizedBox(height: 4),
                          Text('Les ordonnances rédigées par vos médecins apparaîtront ici.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final ord = _items[index];
                          final consultation = _consultationsById[ord.consultationId];
                          return _buildPrescriptionCard(ord, consultation?.diagnosis);
                        },
                      ),
      ),
    );
  }

  Widget _buildPrescriptionCard(PatientPrescription ord, String? diagnosis) {
    final active = ord.isActive;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Référence & Statut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORD-${ord.id}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        formatDateTime(ord.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFFED7AA) : AppColors.surfaceDim,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      active ? 'Valide / À traiter' : 'Annulée',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active ? const Color(0xFFC2410C) : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => PrescriptionPdfService.printPrescription(ord),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.print_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Praticien prescripteur & Établissement
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer,
                ),
                child: const Icon(Icons.person_rounded, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ord.doctorName.isNotEmpty ? 'Dr. ${ord.doctorName}' : 'Médecin eDoctor',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (ord.hospitalName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.local_hospital_rounded, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              ord.hospitalName,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Consultation ${ord.consultationDisplayCode}',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if ((diagnosis != null && diagnosis.trim().isNotEmpty) || (ord.diagnosis.isNotEmpty && ord.diagnosis != 'Non spécifié')) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.medical_information_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diagnostic : ${(diagnosis != null && diagnosis.trim().isNotEmpty) ? diagnosis.trim() : ord.diagnosis}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (ord.homeCareRecommended) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.home_repair_service_rounded, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text('Soins à domicile recommandés',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Liste des médicaments prescrits
          Text(
            'Médicaments prescrits (${ord.items.length}) :',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),

          if (ord.items.isEmpty)
            const Text('Aucun médicament détaillé.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),

          ...ord.items.map((m) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          m.medicationName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Qté: ${m.quantity}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Posologie : ${m.dosageInstructions}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Boutons d'action
          if (active) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _choosePharmacyToOrder(ord),
                    icon: const Icon(Icons.local_pharmacy_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Commander en pharmacie',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HomeCareScreen()),
                    );
                  },
                  tooltip: 'Demander un soin infirmier',
                  icon: const Icon(Icons.home_repair_service_rounded, color: AppColors.primary, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  );
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success),
                label: const Text(
                  'Voir la commande associée',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _choosePharmacyToOrder(PatientPrescription ord) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: ApiService.getPharmacies(),
          builder: (context, snapshot) {
            final pharmacies = snapshot.data ?? [];
            final loading = snapshot.connectionState == ConnectionState.waiting;

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
                        'Choisir une pharmacie',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sélectionnez l\'officine partenaire eDoctor pour préparer ou livrer vos médicaments :',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  if (loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (pharmacies.isEmpty)
                    _buildPharmacyTile(
                      name: 'Grande Pharmacie du Golfe',
                      address: 'Boulevard du 13 Janvier, Quartier Déckon, Lomé',
                      distance: 'En stock immédiat • Partenaire certifié',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showOrderCheckoutSheet(ord, 6, 'Grande Pharmacie du Golfe');
                      },
                    )
                  else
                    ...pharmacies.map((p) {
                      final id = p['id'] as int? ?? 6;
                      final name = p['name'] as String? ?? 'Pharmacie';
                      final address = p['address'] as String? ?? 'Lomé, Togo';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildPharmacyTile(
                          name: name,
                          address: address,
                          distance: 'Officine agréée eDoctor • En stock',
                          onTap: () {
                            Navigator.of(context).pop();
                            _showOrderCheckoutSheet(ord, id, name);
                          },
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPharmacyTile({
    required String name,
    required String address,
    required String distance,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_pharmacy_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(distance, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showOrderCheckoutSheet(PatientPrescription ord, int pharmacyId, String pharmacyName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool withDelivery = false;
        double distanceKm = 3.0;
        final addressController = TextEditingController(text: 'Lomé, Quartier Déckon');
        bool isLoadingQuote = true;
        Map<String, dynamic>? quote;
        bool isSubmitting = false;
        String? errorMessage;

        final items = ord.items.map((i) => {
          'medication_id': i.medicationId,
          'quantity': i.quantity,
        }).toList();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void fetchQuote() async {
              setSheetState(() {
                isLoadingQuote = true;
                errorMessage = null;
              });
              try {
                final res = await ApiService.getOrderQuote(
                  pharmacyId: pharmacyId,
                  items: items,
                  withDelivery: withDelivery,
                  deliveryDistanceKm: withDelivery ? distanceKm : null,
                );
                setSheetState(() {
                  quote = res;
                  isLoadingQuote = false;
                });
              } catch (e) {
                setSheetState(() {
                  errorMessage = e.toString().replaceFirst('Exception: ', '');
                  isLoadingQuote = false;
                });
              }
            }

            if (quote == null && isLoadingQuote && errorMessage == null) {
              fetchQuote();
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Devis & Commande Officine',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  pharmacyName,
                                  style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Récapitulatif ordonnance
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ordonnance ORD-${ord.id}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            Text(
                              '${ord.items.length} médicament(s)',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'Mode de réception',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),

                      // Toggle Retrait / Livraison
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (withDelivery) {
                                  setSheetState(() {
                                    withDelivery = false;
                                  });
                                  fetchQuote();
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: !withDelivery ? AppColors.primaryContainer : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !withDelivery ? AppColors.primary : AppColors.border,
                                    width: !withDelivery ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.storefront_rounded,
                                      color: !withDelivery ? AppColors.primary : AppColors.textMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Retrait Click&Collect',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: !withDelivery ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Gratuit à l\'officine',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: !withDelivery ? AppColors.primary : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (!withDelivery) {
                                  setSheetState(() {
                                    withDelivery = true;
                                  });
                                  fetchQuote();
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: withDelivery ? AppColors.primaryContainer : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: withDelivery ? AppColors.primary : AppColors.border,
                                    width: withDelivery ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.two_wheeler_rounded,
                                      color: withDelivery ? AppColors.primary : AppColors.textMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Livraison Express',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: withDelivery ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Dès 500 FCFA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: withDelivery ? AppColors.primary : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Options de livraison si cochée
                      if (withDelivery) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Distance estimée :',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${distanceKm.toStringAsFixed(1)} km',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: distanceKm,
                                min: 1.0,
                                max: 20.0,
                                divisions: 38,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setSheetState(() => distanceKm = val);
                                },
                                onChangeEnd: (val) {
                                  fetchQuote();
                                },
                              ),
                              const Text(
                                'Grille DG : 500 F (2 premiers km) + 150 F / km suppl.',
                                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: addressController,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: 'Adresse précise de livraison',
                                  labelStyle: TextStyle(fontSize: 12),
                                  prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Tableau transparent du devis
                      if (isLoadingQuote)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        )
                      else if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (quote != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text(
                                    'Détail transparent du prix (Règle DG)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Produits prescrits', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  Text(
                                    '${quote!['items_amount']} FCFA',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              const Text(
                                'Reversé à 100% à la pharmacie partenaire',
                                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Recherche & Service eDoctor', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  Text(
                                    '${quote!['edoctor_fee']} FCFA',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              if (withDelivery) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Livraison Express (${quote!['distance_km']} km)', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    Text(
                                      '${quote!['delivery_fee']} FCFA',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Livreur : ${quote!['delivery_courier_share']} F • Service : ${quote!['delivery_edoctor_share']} F',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(height: 1, color: AppColors.border),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total à payer',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    '${quote!['total_amount']} FCFA',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.primary),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Paiement sécurisé T-Money / Moov Money Togo. Préparation immédiate de la commande.',
                                  style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Bouton d'action
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (isLoadingQuote || quote == null || isSubmitting)
                              ? null
                              : () async {
                                  setSheetState(() => isSubmitting = true);
                                  try {
                                    final res = await ApiService.createOrder(
                                      pharmacyId: pharmacyId,
                                      prescriptionId: ord.id,
                                      paymentMethod: 'mobile_money',
                                      items: items,
                                      withDelivery: withDelivery,
                                      deliveryAddress: withDelivery ? addressController.text.trim() : null,
                                      deliveryDistanceKm: withDelivery ? distanceKm : null,
                                    );

                                    if (!sheetContext.mounted) return;
                                    Navigator.of(sheetContext).pop();

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('🎉 Commande #${res['id']} validée et payée (${quote!['total_amount']} FCFA) !'),
                                        backgroundColor: AppColors.success,
                                        action: SnackBarAction(
                                          label: 'Voir mes commandes',
                                          textColor: Colors.white,
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(builder: (_) => const OrdersScreen()),
                                            );
                                          },
                                        ),
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                    _load();
                                  } catch (e) {
                                    setSheetState(() => isSubmitting = false);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString().replaceFirst('Exception: ', '')),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  quote != null
                                      ? 'Payer ${quote!['total_amount']} FCFA par Mobile Money'
                                      : 'Calcul du devis...',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
