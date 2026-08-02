import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'inventory_provider.dart';
import '../../core/models/product.dart';
import '../../core/utils/formatters.dart';

/// Opens the Quick Restock modal sheet for any product.
Future<void> showQuickRestockSheet(BuildContext context, WidgetRef ref, Product product, {String symbol = '₱'}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => QuickRestockSheet(product: product, symbol: symbol),
  );
}

class QuickRestockSheet extends ConsumerStatefulWidget {
  final Product product;
  final String symbol;

  const QuickRestockSheet({
    super.key,
    required this.product,
    this.symbol = '₱',
  });

  @override
  ConsumerState<QuickRestockSheet> createState() => _QuickRestockSheetState();
}

class _QuickRestockSheetState extends ConsumerState<QuickRestockSheet> {
  final _qtyController = TextEditingController();
  final _costController = TextEditingController();
  bool _usePackMode = false;
  final _packCountController = TextEditingController();
  bool _updateCostPrice = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _costController.text = widget.product.costPrice > 0
        ? widget.product.costPrice.toStringAsFixed(2)
        : '';
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _packCountController.dispose();
    super.dispose();
  }

  void _addPreset(int amount) {
    final currentVal = double.tryParse(_qtyController.text) ?? 0;
    final newVal = currentVal + amount;
    setState(() {
      _qtyController.text = newVal.toInt().toString();
    });
  }

  Future<void> _submitRestock() async {
    double addedPieces = 0;

    if (_usePackMode) {
      final packs = double.tryParse(_packCountController.text) ?? 0;
      final pcsPerPack = widget.product.bundleQty > 1 ? widget.product.bundleQty : 1.0;
      addedPieces = packs * pcsPerPack;
    } else {
      addedPieces = double.tryParse(_qtyController.text) ?? 0;
    }

    if (addedPieces <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity to add.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(inventoryProvider.notifier);

      // Adjust stock
      await notifier.adjustStock(widget.product.id!, addedPieces);

      // Optionally update cost price
      if (_updateCostPrice) {
        final newCost = double.tryParse(_costController.text);
        if (newCost != null && newCost > 0) {
          final updatedProduct = widget.product.copyWith(
            costPrice: newCost,
            currentStock: widget.product.currentStock + addedPieces,
          );
          await notifier.updateProduct(updatedProduct);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restocked +${addedPieces.toInt()} pcs for ${widget.product.productName}!',
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restocking: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isOut = p.isOutOfStock;
    final currentStockInt = p.currentStock.toInt();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Current Stock Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isOut
                      ? Colors.red.shade100
                      : Colors.blue.shade100,
                  child: Icon(
                    Icons.add_shopping_cart_rounded,
                    color: isOut ? Colors.red.shade800 : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restock ${p.productName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isOut
                            ? 'Status: OUT OF STOCK (0 left)'
                            : 'Current Stock: $currentStockInt pcs',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isOut ? Colors.red.shade700 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quick Add Presets
            const Text(
              'Quick Add Presets',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [5, 10, 20, 50].map((amt) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      onPressed: () => _addPreset(amt),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      child: Text('+$amt'),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Toggle Pack Mode if bundle info exists
            if (p.hasBundle)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Restock by Packs / Boxes (${p.bundleQty.toInt()} pcs/pack)'),
                subtitle: const Text('Enter total packs bought instead of single pieces.'),
                value: _usePackMode,
                onChanged: (val) => setState(() => _usePackMode = val),
              ),

            if (_usePackMode) ...[
              const Text(
                'Number of Packs / Boxes Bought',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _packCountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 2 packs (${(double.tryParse(_packCountController.text) ?? 0) * p.bundleQty} pcs)',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
              ),
            ] else ...[
              const Text(
                'Quantity of Single Pieces to Add',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _qtyController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g. 10',
                  prefixIcon: Icon(Icons.add),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Option to update Cost Price
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Supplier cost price changed? Update cost price'),
              subtitle: Text('Current Cost: ${Formatters.currency(p.costPrice, symbol: widget.symbol)}'),
              value: _updateCostPrice,
              onChanged: (val) => setState(() => _updateCostPrice = val ?? false),
            ),

            if (_updateCostPrice) ...[
              const SizedBox(height: 4),
              const Text(
                'New Unit Cost Price (₱)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '₱ ',
                  hintText: '0.00',
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Confirm Restock Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _submitRestock,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded),
              label: const Text('Confirm Restock'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
