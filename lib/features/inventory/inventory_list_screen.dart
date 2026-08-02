import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'inventory_provider.dart';
import 'product_catalog_screen.dart';
import 'quick_restock_sheet.dart';
import '../../core/models/product.dart';
import '../../core/utils/formatters.dart';
import '../../app/theme.dart';
import '../settings/settings_provider.dart';

/// Inventory list screen with search, filter, and 1-tap quick restock.
class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final settings = ref.watch(settingsProvider);
    final symbol = settings.currencySymbol;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _searchQuery = ''),
                    )
                  : null,
            ),
            onChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),

        // Filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                  label: 'All',
                  selected: _selectedFilter == 'All',
                  onTap: () =>
                      setState(() => _selectedFilter = 'All')),
              _FilterChip(
                  label: 'Out of Stock',
                  selected: _selectedFilter == 'Out of Stock',
                  onTap: () =>
                      setState(() => _selectedFilter = 'Out of Stock')),
              _FilterChip(
                  label: 'Low Stock',
                  selected: _selectedFilter == 'Low Stock',
                  onTap: () =>
                      setState(() => _selectedFilter = 'Low Stock')),
              _FilterChip(
                  label: 'Favorites',
                  selected: _selectedFilter == 'Favorites',
                  onTap: () =>
                      setState(() => _selectedFilter = 'Favorites')),
            ],
          ),
        ),

        // Product list
        Expanded(
          child: inventoryAsync.when(
            data: (products) {
              var filtered = products.where((p) {
                if (_searchQuery.isNotEmpty) {
                  return p.productName
                      .toLowerCase()
                      .contains(_searchQuery);
                }
                return true;
              }).where((p) {
                switch (_selectedFilter) {
                  case 'Out of Stock':
                    return p.isOutOfStock;
                  case 'Low Stock':
                    return p.isLowStock || p.isOutOfStock;
                  case 'Favorites':
                    return p.isFavorite;
                  default:
                    return true;
                }
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        products.isEmpty
                            ? 'Your inventory is empty.\nBrowse the catalog or add your first product!'
                            : 'No products match your filter.',
                        style: TextStyle(
                            color: Colors.grey[500], height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      if (products.isEmpty) ...[
                        const SizedBox(height: 20),
                        // Primary: Browse Catalog
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProductCatalogScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Browse Product Catalog'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(220, 44),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Secondary: Add Manually
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context)
                              .pushNamed('/inventory/add'),
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Add Manually'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  return Dismissible(
                    key: Key('product_${product.id}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 44),
                          title: const Text('Delete Product?'),
                          content: Text('Are you sure you want to delete "${product.productName}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) async {
                      await ref.read(inventoryProvider.notifier).archiveProduct(product.id!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${product.productName}" deleted.'),
                            backgroundColor: Colors.red.shade800,
                          ),
                        );
                      }
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    child: _ProductListTile(
                      product: product,
                      symbol: symbol,
                      onTap: () => Navigator.of(context).pushNamed(
                        '/inventory/edit',
                        arguments: product,
                      ),
                      onRestock: () => showQuickRestockSheet(
                          context, ref, product, symbol: symbol),
                    ),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;
  final String symbol;
  final VoidCallback onTap;
  final VoidCallback onRestock;

  const _ProductListTile({
    required this.product,
    required this.symbol,
    required this.onTap,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = product.isOutOfStock;
    final stockColor = isOut
        ? AppTheme.lossRed
        : product.isLowStock
            ? AppTheme.lowStockOrange
            : AppTheme.profitGreen;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOut ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      color: isOut ? Colors.red.shade50 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon Avatar
              CircleAvatar(
                backgroundColor: stockColor.withValues(alpha: 0.15),
                radius: 18,
                child: Icon(
                  isOut ? Icons.remove_shopping_cart_rounded : Icons.inventory_2,
                  color: stockColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              // Product Info (Name, Category, Out of stock badge)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.categoryName ?? 'Uncategorized',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOut) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right side info (Stock + Price)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${product.currentStock.toInt()} pcs',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: stockColor,
                    ),
                  ),
                  Text(
                    Formatters.currency(product.sellingPrice, symbol: symbol),
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Restock Button
              InkWell(
                onTap: onRestock,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOut ? Colors.red : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'Restock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
