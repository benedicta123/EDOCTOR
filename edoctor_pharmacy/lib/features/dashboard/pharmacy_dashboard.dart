import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pharmacy_shell.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/user_model.dart';
import '../../data/models/pharmacy_model.dart';
import '../../data/models/order_model.dart';
import '../../data/models/stock_item_model.dart';

class PharmacyDashboard extends StatefulWidget {
  const PharmacyDashboard({super.key});

  @override
  State<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends State<PharmacyDashboard> {
  UserModel? _user;
  PharmacyModel? _pharmacy;
  List<OrderModel> _orders = [];
  List<StockItemModel> _stocks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cachedUser = await StorageService.getUser();
    final cachedPharmacy = await StorageService.getPharmacy();
    if (mounted && (_user == null || _pharmacy == null)) {
      setState(() {
        _user = cachedUser;
        _pharmacy = cachedPharmacy;
      });
    }

    setState(() => _loading = true);
    try {
      final user = cachedUser ?? await StorageService.getUser();
      final pharmacy = await ApiService.getMyPharmacy();
      await StorageService.savePharmacy(pharmacy);
      final orders = await ApiService.getOrders();
      final stocks = await ApiService.getStocks(pharmacy.id);

      if (mounted) {
        setState(() {
          _user = user;
          _pharmacy = pharmacy;
          _orders = orders;
          _stocks = stocks;
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

  Future<void> _markOrderReady(OrderModel order) async {
    try {
      await ApiService.markOrderReady(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande #${order.id} marquée comme prête à emporter.'),
            backgroundColor: AppColors.inStock,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
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
    final pendingOrders = _orders.where((o) => o.isPending).toList();
    final readyOrders = _orders.where((o) => o.isReady).toList();
    final criticalStocks = _stocks.where((s) => s.status != StockStatus.inStock).toList();

    return PharmacyShell(
      currentSection: PharmacySection.dashboard,
      title: 'Tableau de bord',
      user: _user,
      pharmacy: _pharmacy,
      onRefresh: _loadData,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête Officine & Pharmacien Titulaire
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_pharmacy_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pharmacy?.name ?? 'Pharmacie & Stocks',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    _user?.name != null && _user!.name.isNotEmpty
                                        ? 'Pharmacien titulaire : ${_user!.name}'
                                        : 'Officine partenaire vérifiée',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (_pharmacy?.address != null && _pharmacy!.address.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    const Text('•', style: TextStyle(color: AppColors.textMuted)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _pharmacy!.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Grille des statistiques principales
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 1000 ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: cols == 4 ? 1.6 : (cols == 2 ? 1.8 : 2.5),
                        children: [
                          StatCard(
                            title: 'À préparer',
                            value: '${pendingOrders.length}',
                            icon: Icons.hourglass_top_rounded,
                            iconColor: AppColors.orderPending,
                            iconBg: AppColors.orderPendingLight,
                            subtitle: 'Ordonnances en attente',
                          ),
                          StatCard(
                            title: 'Prêtes au retrait',
                            value: '${readyOrders.length}',
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: AppColors.orderReady,
                            iconBg: AppColors.orderReadyLight,
                            subtitle: 'En attente du patient',
                          ),
                          StatCard(
                            title: 'Alertes stocks',
                            value: '${criticalStocks.length}',
                            icon: Icons.warning_amber_rounded,
                            iconColor: AppColors.outOfStock,
                            iconBg: AppColors.outOfStockLight,
                            subtitle: 'Faible ou rupture',
                          ),
                          StatCard(
                            title: 'Références actives',
                            value: '${_stocks.length}',
                            icon: Icons.medication_outlined,
                            iconColor: AppColors.primary,
                            iconBg: AppColors.primaryContainer,
                            subtitle: 'Médicaments en catalogue',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Deux colonnes : Commandes récentes & Alertes stocks
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildOrdersCard(pendingOrders)),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: _buildCriticalStocksCard(criticalStocks)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildOrdersCard(pendingOrders),
                          const SizedBox(height: 20),
                          _buildCriticalStocksCard(criticalStocks),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOrdersCard(List<OrderModel> pendingOrders) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text(
                    'Commandes en attente de préparation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/orders'),
                child: const Text('Voir tout →'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pendingOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Toutes les commandes ont été traitées !',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingOrders.take(5).length,
              separatorBuilder: (_, _) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final order = pendingOrders[idx];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        order.patientName.isNotEmpty ? order.patientName[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.patientName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Commande #${order.id} • ${Formatters.currency(order.totalAmount)} • ${Formatters.time(order.createdAt)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _markOrderReady(order),
                      child: const Text('Prête'),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCriticalStocksCard(List<StockItemModel> criticalStocks) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.outOfStock),
                  SizedBox(width: 10),
                  Text(
                    'Alertes réapprovisionnement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/inventory'),
                child: const Text('Inventaire →'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (criticalStocks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Tous vos stocks sont à un niveau optimal.',
                  style: TextStyle(color: AppColors.inStock, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: criticalStocks.take(5).length,
              separatorBuilder: (_, _) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final stock = criticalStocks[idx];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.medicationName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Restant : ${stock.quantity} boîte(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: stock.quantity == 0 ? AppColors.outOfStock : AppColors.lowStock,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StockBadge(status: stock.status),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
