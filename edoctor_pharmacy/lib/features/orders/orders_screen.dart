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
      return _orders.where((o) => o.isReady && !o.isDelivery).toList();
    }
    if (_currentFilter == 'livraison') {
      return _orders.where((o) => o.isDelivery && !o.isCompleted && !o.isCancelled).toList();
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                order.isDelivery ? Icons.delivery_dining_rounded : Icons.receipt_long_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Commande #${order.id}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    order.isDelivery ? 'Livraison à domicile' : 'Retrait en pharmacie',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: order.isDelivery ? Colors.blue.shade700 : AppColors.inStock,
                    ),
                  ),
                ],
              ),
            ),
            OrderStatusBadge(status: order.status, label: order.statusLabel),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Patient & Coordonnées
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryContainer,
                        child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.patientName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                            ),
                            if (order.patientPhone != null)
                              Text(
                                '📞 ${order.patientPhone!}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            if (order.isDelivery && order.deliveryAddress != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '📍 Adresse : ${order.deliveryAddress!}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ],
                            if (order.courierName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '🛵 Coursier : ${order.courierName!}',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

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

                // Décomposition Financière
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Part Médicaments (Votre gain) :', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text(
                      Formatters.currency(order.itemsAmount),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.inStock),
                    ),
                  ],
                ),
                if (order.deliveryFee > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Frais de coursier (transport) :', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(
                        Formatters.currency(order.deliveryFee),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total payé par le patient :', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 18),
              onPressed: () async {
                Navigator.pop(ctx);
                await _actionMarkReady(order);
              },
              label: const Text('Marquer Prête'),
            ),
          if (order.isReady && !order.isDelivery)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.inStock),
              icon: const Icon(Icons.pin_rounded, size: 18),
              onPressed: () {
                Navigator.pop(ctx);
                _promptPickupCode(order);
              },
              label: const Text('Valider la remise au comptoir'),
            ),
          if (order.isDelivery && order.isReady && !order.isEnRoute && order.deliveryId != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
              icon: const Icon(Icons.two_wheeler_rounded, size: 18),
              onPressed: () {
                Navigator.pop(ctx);
                _promptAssignCourier(order);
              },
              label: const Text('Confier au coursier'),
            ),
          if (order.isDelivery && order.isEnRoute && order.deliveryId != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.inStock),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              onPressed: () {
                Navigator.pop(ctx);
                _promptDeliveryValidation(order);
              },
              label: const Text('Confirmer la livraison'),
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
            content: Text(
              order.isDelivery
                  ? 'Commande #${order.id} prête pour expédition par coursier.'
                  : 'Commande #${order.id} prête au comptoir. Le patient a reçu son code secret.',
            ),
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

  /// Boîte de dialogue sécurisée : saisie du code secret à 4 chiffres lors de la remise au comptoir
  Future<void> _promptPickupCode(OrderModel order) async {
    final codeController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    bool submitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (subCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.inStockLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: AppColors.inStock, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Code secret de remise',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demandez au patient ${order.patientName} son code secret à 4 chiffres (reçu dans son application eDoctor) :',
                      style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),

                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10,
                        color: AppColors.primary,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surfaceDim,
                        errorText: errorMessage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.inStockLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.inStock.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on_outlined, color: AppColors.inStock, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Dès validation, votre portefeuille sera crédité de ${Formatters.currency(order.itemsAmount)}.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inStock),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.inStock),
                  onPressed: submitting
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            setDialogState(() => errorMessage = 'Veuillez saisir le code');
                            return;
                          }
                          setDialogState(() {
                            submitting = true;
                            errorMessage = null;
                          });

                          try {
                            await ApiService.markOrderCollected(order.id, pickupCode: code);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Succès ! Commande #${order.id} remise et solde de ${Formatters.currency(order.itemsAmount)} versé sur votre portefeuille.',
                                  ),
                                  backgroundColor: AppColors.inStock,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              _load();
                            }
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              errorMessage = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Valider & Encaisser'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Boîte de dialogue : Assigner le coursier pour la livraison à domicile
  Future<void> _promptAssignCourier(OrderModel order) async {
    final courierController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    bool submitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (subCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.two_wheeler_rounded, color: Colors.blue.shade700, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Confier au coursier', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adresse de livraison : ${order.deliveryAddress ?? "À domicile"}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: courierController,
                      decoration: InputDecoration(
                        labelText: 'Nom et téléphone du coursier',
                        hintText: 'Ex: Kossi Mensah (90 12 34 56)',
                        errorText: errorMessage,
                        filled: true,
                        fillColor: AppColors.surfaceDim,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                  onPressed: submitting
                      ? null
                      : () async {
                          final name = courierController.text.trim();
                          if (name.isEmpty) {
                            setDialogState(() => errorMessage = 'Le nom du coursier est requis');
                            return;
                          }
                          setDialogState(() => submitting = true);
                          try {
                            await ApiService.assignDeliveryCourier(order.deliveryId!, courierName: name);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Commande #${order.id} mise en route avec $name.'),
                                  backgroundColor: Colors.blue.shade700,
                                ),
                              );
                              _load();
                            }
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              errorMessage = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirmer l\'envoi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Boîte de dialogue : Valider la livraison avec le code secret rapporté par le coursier
  Future<void> _promptDeliveryValidation(OrderModel order) async {
    final codeController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    bool submitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (subCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.inStockLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.inStock, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Valider la livraison', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saisissez le code secret à 4 chiffres remis par le patient au coursier :',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8, color: AppColors.primary),
                      decoration: InputDecoration(
                        hintText: '••••',
                        counterText: '',
                        errorText: errorMessage,
                        filled: true,
                        fillColor: AppColors.surfaceDim,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Montant crédité à la confirmation : ${Formatters.currency(order.itemsAmount)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inStock),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.inStock),
                  onPressed: submitting
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            setDialogState(() => errorMessage = 'Veuillez saisir le code');
                            return;
                          }
                          setDialogState(() => submitting = true);
                          try {
                            await ApiService.markDeliveryDelivered(order.deliveryId!, pickupCode: code);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Livraison confirmée ! ${Formatters.currency(order.itemsAmount)} versés sur votre portefeuille.',
                                  ),
                                  backgroundColor: AppColors.inStock,
                                ),
                              );
                              _load();
                            }
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              errorMessage = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Valider & Encaisser'),
                ),
              ],
            );
          },
        );
      },
    );
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
                      _filterChip('prete', 'Prêtes au comptoir (${_orders.where((o) => o.isReady && !o.isDelivery).length})'),
                      _filterChip('livraison', 'Livraisons (${_orders.where((o) => o.isDelivery && !o.isCompleted && !o.isCancelled).length})'),
                      _filterChip('recuperee', 'Terminées (${_orders.where((o) => o.isCompleted).length})'),
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
                                            color: order.isDelivery ? Colors.blue.shade50 : AppColors.primaryContainer,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            order.isDelivery ? Icons.delivery_dining_rounded : Icons.receipt_outlined,
                                            color: order.isDelivery ? Colors.blue.shade700 : AppColors.primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'Commande #${order.id} • ${order.patientName}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 15,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: order.isDelivery ? Colors.blue.shade50 : AppColors.surfaceDim,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: order.isDelivery ? Colors.blue.shade200 : AppColors.border,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      order.isDelivery ? 'Livraison' : 'Comptoir',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: order.isDelivery ? Colors.blue.shade800 : AppColors.textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${Formatters.dateTime(order.createdAt)} • Votre part : ${Formatters.currency(order.itemsAmount)}',
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
