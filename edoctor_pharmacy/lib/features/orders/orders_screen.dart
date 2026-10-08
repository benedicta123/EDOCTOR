import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pharmacy_shell.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/order_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/pharmacy_model.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  UserModel? _user;
  PharmacyModel? _pharmacy;
  List<OrderModel> _orders = [];
  bool _loading = true;
  String _currentFilter = 'toutes';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final pharmacy = await StorageService.getPharmacy();
      final orders = await ApiService.getOrders();
      if (mounted) {
        setState(() {
          _user = user;
          _pharmacy = pharmacy;
          _orders = orders;
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

  List<OrderModel> get _filteredOrders {
    if (_currentFilter == 'toutes') return _orders;
    if (_currentFilter == 'attente') {
      return _orders.where((o) => o.isPending).toList();
    }
    if (_currentFilter == 'prete') {
      return _orders.where((o) => o.isReady).toList();
    }
    if (_currentFilter == 'recuperee') {
      return _orders.where((o) => o.isCompleted).toList();
    }
    return _orders;
  }

  Future<void> _showOrderDetails(OrderModel order) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Commande #${order.id}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            OrderStatusBadge(status: order.status, label: order.statusLabel),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Patient
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.patientName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          if (order.patientPhone != null)
                            Text(
                              order.patientPhone!,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Médicaments prescrits :',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),

                if (order.items.isEmpty)
                  const Text('Aucun détail d\'article fourni.', style: TextStyle(color: AppColors.textMuted))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 12),
                    itemBuilder: (_, idx) {
                      final item = order.items[idx];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.medicationName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                                Text(
                                  '${item.quantity} x ${Formatters.currency(item.unitPrice)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.currency(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      );
                    },
                  ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total :', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                      Formatters.currency(order.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          if (order.isPending)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _actionMarkReady(order);
              },
              child: const Text('Marquer Prête'),
            ),
          if (order.isReady)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.inStock),
              onPressed: () async {
                Navigator.pop(ctx);
                await _actionMarkCollected(order);
              },
              child: const Text('Remise au patient'),
            ),
        ],
      ),
    );
  }

  Future<void> _actionMarkReady(OrderModel order) async {
    try {
      await ApiService.markOrderReady(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande #${order.id} prête au retrait.'),
            backgroundColor: AppColors.inStock,
          ),
        );
        _load();
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

  Future<void> _actionMarkCollected(OrderModel order) async {
    try {
      await ApiService.markOrderCollected(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande #${order.id} remise au patient avec succès.'),
            backgroundColor: AppColors.inStock,
          ),
        );
        _load();
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
    return PharmacyShell(
      currentSection: PharmacySection.orders,
      title: 'Commandes & Ordonnances',
      user: _user,
      pharmacy: _pharmacy,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtres sous forme de chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip('toutes', 'Toutes (${_orders.length})'),
                      _filterChip('attente', 'À préparer (${_orders.where((o) => o.isPending).length})'),
                      _filterChip('prete', 'Prêtes (${_orders.where((o) => o.isReady).length})'),
                      _filterChip('recuperee', 'Remises (${_orders.where((o) => o.isCompleted).length})'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Liste des commandes
                  Expanded(
                    child: _filteredOrders.isEmpty
                        ? const EmptyStateView(
                            icon: Icons.receipt_long_outlined,
                            title: 'Aucune commande trouvée',
                            message: 'Aucune commande ne correspond au filtre sélectionné pour le moment.',
                          )
                        : ListView.separated(
                            itemCount: _filteredOrders.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final order = _filteredOrders[idx];
                              return Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _showOrderDetails(order),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryContainer,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.receipt_outlined,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Commande #${order.id} • ${order.patientName}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Reçue le ${Formatters.dateTime(order.createdAt)} • ${Formatters.currency(order.totalAmount)}',
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        OrderStatusBadge(
                                          status: order.status,
                                          label: order.statusLabel,
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _currentFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      onSelected: (_) => setState(() => _currentFilter = key),
    );
  }
}
