import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedFilter = 0; // 0: Toutes, 1: En cours, 2: Terminées

  final List<Map<String, dynamic>> _orders = [
    {
      'id': 'CMD-2026-0841',
      'pharmacyName': 'Grande Pharmacie Centrale de Démo',
      'pharmacyAddress': 'Avenue Chardy, Plateau, Abidjan',
      'pharmacyPhone': '+225 27 20 00 00 00',
      'date': 'Aujourd\'hui à 10:15',
      'status': 'en_preparation',
      'statusLabel': 'En préparation',
      'statusColor': AppColors.warning,
      'statusBg': AppColors.warningLight,
      'isDelivery': true,
      'deliveryAddress': 'Cocody Angré 8ème Tranche, Abidjan',
      'items': [
        {'name': 'Amoxicilline 500mg', 'qty': 2, 'price': 3200},
        {'name': 'Paracétamol 1000mg', 'qty': 1, 'price': 1500},
      ],
      'total': 7900, // avec 0 livraison
    },
    {
      'id': 'CMD-2026-0792',
      'pharmacyName': 'Pharmacie de la Paix & Espérance',
      'pharmacyAddress': 'Boulevard de Marseille, Zone 4, Abidjan',
      'pharmacyPhone': '+225 27 21 00 00 01',
      'date': 'Hier à 16:40',
      'status': 'prete',
      'statusLabel': 'Prête à retirer',
      'statusColor': AppColors.primary,
      'statusBg': AppColors.primaryContainer,
      'isDelivery': false,
      'deliveryAddress': 'Retrait en officine',
      'items': [
        {'name': 'Vitamine C 1000mg', 'qty': 2, 'price': 1850},
        {'name': 'Ibuprofène 400mg', 'qty': 1, 'price': 2050},
      ],
      'total': 5750,
    },
    {
      'id': 'CMD-2026-0650',
      'pharmacyName': 'Pharmacie Sainte-Marie',
      'pharmacyAddress': 'Boulevard Latrille, Cocody Angré',
      'pharmacyPhone': '+225 27 22 00 00 02',
      'date': '05 Sept. 2026',
      'status': 'livree',
      'statusLabel': 'Livrée avec succès',
      'statusColor': AppColors.success,
      'statusBg': AppColors.successLight,
      'isDelivery': true,
      'deliveryAddress': 'Marcory Zone 4, Abidjan',
      'items': [
        {'name': 'Azithromycine 250mg', 'qty': 1, 'price': 5600},
      ],
      'total': 5600,
    },
  ];

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 1) {
      return _orders.where((o) => o['status'] == 'en_preparation' || o['status'] == 'prete').toList();
    } else if (_selectedFilter == 2) {
      return _orders.where((o) => o['status'] == 'livree').toList();
    }
    return _orders;
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
          'Mes Commandes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pour toute question sur une commande, contactez directement l\'officine.'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip(0, 'Toutes (${_orders.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'En cours (2)'),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Livrées (1)'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Liste des commandes
          Expanded(
            child: _filteredOrders.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredOrders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final order = _filteredOrders[index];
                      return _buildOrderCard(order);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {
          _selectedFilter = index;
        });
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>;

    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : ID & Statut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_pharmacy_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    order['id'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: order['statusBg'] as Color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order['statusLabel'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: order['statusColor'] as Color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Pharmacie
          Text(
            order['pharmacyName'] as String,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order['pharmacyAddress'] as String,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Liste des articles
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: items.map<Widget>((it) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${it['qty']}x ${it['name']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${it['price']} FCFA',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Mode de réception & Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    order['isDelivery'] == true ? Icons.delivery_dining_rounded : Icons.storefront_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order['isDelivery'] == true ? 'Livraison express' : 'Retrait en pharmacie',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              RichText(
                text: TextSpan(
                  text: 'Total : ',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                      text: '${order['total']} FCFA',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bouton d'action
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () {
                _showOrderDetails(order);
              },
              icon: const Icon(Icons.receipt_outlined, size: 16, color: AppColors.primary),
              label: const Text(
                'Détails du suivi & Reçu',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
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
                  Text(
                    'Commande ${order['id']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Passée le : ${order['date']}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Pharmacie : ${order['pharmacyName']}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              Text(
                'Contact : ${order['pharmacyPhone']}',
                style: const TextStyle(fontSize: 13, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adresse de destination :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order['deliveryAddress'] as String,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Appel vers ${order['pharmacyPhone']} en cours...'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Appeler la pharmacie',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Aucune commande dans cette catégorie',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
