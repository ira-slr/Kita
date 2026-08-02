import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../inventory/inventory_provider.dart';
import '../../core/models/product.dart';
import 'scanned_item_model.dart';

/// Review screen — shows the parsed receipt items for user confirmation
/// before updating inventory.
class ReviewScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final List<ScannedItem> items;

  const ReviewScreen({
    super.key,
    required this.imagePath,
    required this.items,
  });

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late List<ScannedItem> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  // ---------------------------------------------------------------------------
  // Confirm & save
  // ---------------------------------------------------------------------------

  Future<void> _confirm() async {
    // Check if any new product is missing a selling price
    final missingPrice = _items
        .where((i) => !i.isDeleted && i.isNewProduct && i.sellingPrice <= 0);
    if (missingPrice.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '⚠️ Please set a Selling Price for all new (blue) items first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Build update batches
      final updates = <Map<String, dynamic>>[];
      final newProducts = <Product>[];

      for (final item in _items) {
        if (item.isDeleted) continue;

        if (item.matchedProductId != null) {
          // Update existing product
          updates.add({
            'productId': item.matchedProductId,
            'addQty': item.quantity,
            'newCostPrice': item.unitCost,
          });
        } else {
          // Insert new product
          newProducts.add(Product(
            productName: item.productName,
            costPrice: item.unitCost,
            sellingPrice: item.sellingPrice,
            currentStock: item.quantity,
          ));
        }
      }

      await ref.read(inventoryProvider.notifier).batchUpdateFromScan(
            updates: updates,
            newProducts: newProducts,
            receiptImagePath: widget.imagePath,
          );

      if (!mounted) return;

      final totalAdded =
          _items.where((i) => !i.isDeleted).fold(0.0, (s, i) => s + i.quantity);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 48),
          title: const Text('Inventory Updated!'),
          content: Text(
            'Successfully processed ${_items.where((i) => !i.isDeleted).length} items '
            '(${totalAdded.toInt()} units added to stock).',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // pop review screen
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Edit item dialog
  // ---------------------------------------------------------------------------

  void _editItem(int index) {
    final item = _items[index];
    final nameCtrl = TextEditingController(text: item.productName);
    final qtyCtrl =
        TextEditingController(text: item.quantity.toStringAsFixed(0));
    final costCtrl =
        TextEditingController(text: item.unitCost.toStringAsFixed(2));
    final sellCtrl =
        TextEditingController(text: item.sellingPrice > 0
            ? item.sellingPrice.toStringAsFixed(2)
            : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit Item',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Raw: "${item.rawText}"',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Product Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: costCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Unit Cost ₱'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            if (item.isNewProduct) ...[
              const SizedBox(height: 12),
              TextField(
                controller: sellCtrl,
                decoration: const InputDecoration(
                  labelText: 'Selling Price ₱ *',
                  hintText: 'Required for new products',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _items[index].productName =
                      nameCtrl.text.trim().isNotEmpty
                          ? nameCtrl.text.trim()
                          : item.productName;
                  _items[index].quantity =
                      double.tryParse(qtyCtrl.text) ?? item.quantity;
                  _items[index].unitCost =
                      double.tryParse(costCtrl.text) ?? item.unitCost;
                  _items[index].totalCost =
                      _items[index].quantity * _items[index].unitCost;
                  if (item.isNewProduct) {
                    _items[index].sellingPrice =
                        double.tryParse(sellCtrl.text) ?? 0;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((i) => !i.isDeleted).toList();
    final totalUnits = visible.fold(0.0, (s, i) => s + i.quantity);
    final totalCost = visible.fold(0.0, (s, i) => s + i.totalCost);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _confirm,
              icon: const Icon(Icons.check),
              label: const Text('Confirm'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Receipt image thumbnail
          SizedBox(
            height: 120,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(widget.imagePath),
                      width: 80,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${visible.length} items found',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                          '${totalUnits.toInt()} units  •  ₱${totalCost.toStringAsFixed(2)} total cost',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                      const SizedBox(height: 8),
                      _LegendRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Items list
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'All items removed.\nTap Confirm to exit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      if (item.isDeleted) return const SizedBox.shrink();
                      return _ScannedItemTile(
                        item: item,
                        onEdit: () => _editItem(index),
                        onDelete: () =>
                            setState(() => _items[index].isDeleted = true),
                      );
                    },
                  ),
          ),
        ],
      ),

      // Sticky bottom confirm button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _confirm,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.inventory_2),
            label: Text(_isSaving
                ? 'Saving…'
                : 'Confirm & Update Inventory (${visible.length})'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendDot(color: Colors.green.shade600, label: 'Match'),
        const SizedBox(width: 12),
        _LegendDot(color: Colors.orange.shade700, label: 'Review'),
        const SizedBox(width: 12),
        _LegendDot(color: Colors.blue.shade700, label: 'New'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }
}

class _ScannedItemTile extends StatelessWidget {
  final ScannedItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScannedItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _rowColor {
    switch (item.confidence) {
      case MatchConfidence.high:
        return Colors.green.shade50;
      case MatchConfidence.low:
        return Colors.orange.shade50;
      case MatchConfidence.none:
        return Colors.blue.shade50;
    }
  }

  Color get _badgeColor {
    switch (item.confidence) {
      case MatchConfidence.high:
        return Colors.green.shade600;
      case MatchConfidence.low:
        return Colors.orange.shade700;
      case MatchConfidence.none:
        return Colors.blue.shade700;
    }
  }

  String get _badgeLabel {
    switch (item.confidence) {
      case MatchConfidence.high:
        return '✓ Match';
      case MatchConfidence.low:
        return '⚠ Review';
      case MatchConfidence.none:
        return '+ New';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: _rowColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _badgeColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge + Name
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_badgeLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),

                    // Qty + Cost
                    Text(
                      'Qty: ${item.quantity.toInt()}  •  Unit Cost: ₱${item.unitCost.toStringAsFixed(2)}  •  Total: ₱${item.totalCost.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: Colors.grey[700], fontSize: 12),
                    ),

                    // Selling price warning for new items
                    if (item.isNewProduct && item.sellingPrice <= 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '⚠️ Tap to set selling price',
                          style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    if (item.isNewProduct && item.sellingPrice > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Sell: ₱${item.sellingPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Colors.blue.shade800, fontSize: 12),
                        ),
                      ),

                    // Matched product
                    if (item.matchedProductName != null)
                      Text(
                        '→ ${item.matchedProductName}',
                        style: TextStyle(
                            color: _badgeColor,
                            fontSize: 11),
                      ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.red.shade300),
                onPressed: onDelete,
                tooltip: 'Remove this item',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
