import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pos_provider.dart';
import '../inventory/inventory_provider.dart';
import '../inventory/quick_restock_sheet.dart';
import '../scanner/barcode_scanner_dialog.dart';
import '../settings/settings_provider.dart';
import '../../core/models/product.dart';
import '../../core/utils/formatters.dart';

/// The Point of Sale screen: product grid + cart + payment.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _searchQuery = '';
  String? _selectedCategory;

  Future<void> _scanBarcode(List<Product> products, String symbol) async {
    final scannedCode = await showBarcodeScannerDialog(context);
    if (scannedCode == null || scannedCode.isEmpty) return;

    // Look up product by SKU / barcode
    final matched = products.where((p) => p.sku == scannedCode).firstOrNull;

    if (!mounted) return;

    if (matched != null) {
      if (matched.isOutOfStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${matched.productName} is OUT OF STOCK!'),
            backgroundColor: Colors.red.shade800,
            action: SnackBarAction(
              label: 'RESTOCK',
              textColor: Colors.white,
              onPressed: () => showQuickRestockSheet(context, ref, matched, symbol: symbol),
            ),
          ),
        );
      } else {
        final added = ref.read(cartProvider.notifier).addProduct(matched);
        if (added) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added 1x ${matched.productName}!'),
              backgroundColor: Colors.green.shade800,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // Product not found in inventory
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product found with barcode "$scannedCode"'),
          backgroundColor: Colors.orange.shade800,
          action: SnackBarAction(
            label: 'ADD TO CATALOG',
            textColor: Colors.white,
            onPressed: () => Navigator.of(context).pushNamed(
              '/inventory/add',
              arguments: scannedCode,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final cart = ref.watch(cartProvider);
    final settings = ref.watch(settingsProvider);
    final symbol = settings.currencySymbol;
    final products = inventoryAsync.value ?? [];

    return Column(
      children: [
        // Search bar + Barcode Scanner Camera button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
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
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              // Barcode Camera Button
              IconButton.filled(
                onPressed: () => _scanBarcode(products, symbol),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'Scan Barcode',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),

        // Category pills
        SizedBox(
          height: 44,
          child: inventoryAsync.when(
            data: (products) {
              final categories = <String>{'All'};
              for (final p in products) {
                if (p.categoryName != null) {
                  categories.add(p.categoryName!);
                }
              }
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: categories.map((cat) {
                  final isSelected =
                      cat == (_selectedCategory ?? 'All');
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => setState(
                        () => _selectedCategory =
                            cat == 'All' ? null : cat,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        // Product grid
        Expanded(
          child: inventoryAsync.when(
            data: (products) {
              var filtered = products.where((p) {
                if (_searchQuery.isNotEmpty &&
                    !p.productName
                        .toLowerCase()
                        .contains(_searchQuery)) {
                  return false;
                }
                if (_selectedCategory != null &&
                    p.categoryName != _selectedCategory) {
                  return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_basket_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No products found.\nAdd items from Inventory first.',
                        style: TextStyle(
                            color: Colors.grey[500], height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  final inCart = cart.items
                      .where((i) => i.product.id == product.id)
                      .firstOrNull;

                  return _ProductTile(
                    product: product,
                    symbol: symbol,
                    cartQuantity: inCart?.quantity.toInt() ?? 0,
                    onTap: () {
                      final success =
                          ref.read(cartProvider.notifier).addProduct(product);
                      if (!success) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(product.isOutOfStock
                                ? '${product.productName} is OUT OF STOCK!'
                                : 'Stock limit reached! Only ${product.currentStock.toInt()} available.'),
                            duration: const Duration(seconds: 4),
                            backgroundColor: product.isOutOfStock
                                ? Colors.red.shade800
                                : Colors.orange.shade800,
                            action: product.isOutOfStock
                                ? SnackBarAction(
                                    label: 'RESTOCK NOW',
                                    textColor: Colors.white,
                                    onPressed: () => showQuickRestockSheet(
                                        context, ref, product,
                                        symbol: symbol),
                                  )
                                : null,
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),

        // Cart summary bar
        if (!cart.isEmpty)
          _CartSummaryBar(
            cart: cart,
            symbol: symbol,
            onTap: () => _showCartSheet(context, ref, cart, symbol),
          ),
      ],
    );
  }

  void _showCartSheet(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    String symbol,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CartSheet(symbol: symbol),
    );
  }
}

/// Tappable product tile for the POS grid.
class _ProductTile extends StatelessWidget {
  final Product product;
  final String symbol;
  final int cartQuantity;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.symbol,
    required this.cartQuantity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.isOutOfStock;
    final stockInt = product.currentStock.toInt();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isOutOfStock
                ? Colors.grey.shade100
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: cartQuantity > 0
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2)
                : Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 28,
                      color: isOutOfStock
                          ? Colors.grey[400]
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.productName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock ? Colors.grey[500] : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.currency(product.effectiveSellingPrice,
                          symbol: symbol),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? Colors.grey[400]
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Stock badge
                    Text(
                      isOutOfStock ? 'OUT OF STOCK' : 'Stock: $stockInt',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock
                            ? Colors.red.shade700
                            : (product.isLowStock
                                ? Colors.orange.shade800
                                : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),

              // Bundle promo badge (top-left)
              if (product.hasBundle && !isOutOfStock)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.bundleLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Cart quantity badge (top-right)
              if (cartQuantity > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'x$cartQuantity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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

/// Sticky bottom bar showing cart total.
class _CartSummaryBar extends StatelessWidget {
  final CartState cart;
  final String symbol;
  final VoidCallback onTap;

  const _CartSummaryBar({
    required this.cart,
    required this.symbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cart.totalItemCount} items',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                Text(
                  Formatters.currency(cart.total, symbol: symbol),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Charge',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet showing cart line items + payment.
class _CartSheet extends ConsumerStatefulWidget {
  final String symbol;
  const _CartSheet({required this.symbol});

  @override
  ConsumerState<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<_CartSheet> {
  final _cashController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _processPayment(double cashTendered) async {
    setState(() => _isProcessing = true);
    try {
      final change = await ref
          .read(cartProvider.notifier)
          .commitTransaction(cashTendered);

      // Refresh inventory and dashboard data
      ref.read(inventoryProvider.notifier).loadProducts();
      ref.invalidate(todaySalesProvider);
      ref.invalidate(todayProfitProvider);
      ref.invalidate(lowStockProvider);
      ref.invalidate(recentTransactionsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        _showChangeDialog(change);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showChangeDialog(double change) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Transaction Complete!',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Change: ${Formatters.currency(change, symbol: widget.symbol)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('New Sale'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final total = cart.total;

    // Smart quick cash values
    final quickCash = _generateQuickCash(total);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cart',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      notifier.clearCart();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 18),
                    label: const Text('Clear',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              const Divider(),

              // Cart items
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.product.productName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        Formatters.currency(
                            item.product.sellingPrice,
                            symbol: widget.symbol),
                        style:
                            TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => notifier.setQuantity(
                              item.product.id!,
                              item.quantity - 1,
                            ),
                          ),
                          Text(
                            '${item.quantity.toInt()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => notifier.setQuantity(
                              item.product.id!,
                              item.quantity + 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.currency(item.lineTotal,
                                symbol: widget.symbol),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Total
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(
                    Formatters.currency(total, symbol: widget.symbol),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick cash buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickCash.map((amount) {
                  final label = amount == total
                      ? 'Exact'
                      : Formatters.currency(amount, symbol: widget.symbol);
                  return OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _processPayment(amount),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    child: Text(label),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // Custom amount input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cashController,
                      decoration: const InputDecoration(
                        hintText: 'Custom amount',
                        prefixText: '₱ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            final cash =
                                double.tryParse(_cashController.text);
                            if (cash != null && cash >= total) {
                              _processPayment(cash);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Insufficient amount'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 52),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Text('Pay'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Generate smart quick cash amounts based on the total.
  List<double> _generateQuickCash(double total) {
    final amounts = <double>{total}; // Exact amount always first
    final denominations = [20, 50, 100, 200, 500, 1000];
    for (final d in denominations) {
      if (d >= total) {
        amounts.add(d.toDouble());
        if (amounts.length >= 4) break;
      }
    }
    return amounts.toList()..sort();
  }
}
