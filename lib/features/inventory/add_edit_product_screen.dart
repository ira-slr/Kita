import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'inventory_provider.dart';
import 'product_catalog_screen.dart';
import '../scanner/barcode_scanner_dialog.dart';
import '../../core/models/product.dart';
import '../../core/services/barcode_lookup_service.dart';

/// Form screen for adding or editing a product.
/// [catalogStub] is optionally provided when navigating from the product catalog
/// so that the product name and category are pre-filled for the user.
class AddEditProductScreen extends ConsumerStatefulWidget {
  final Product? existingProduct;
  final Product? catalogStub;

  const AddEditProductScreen({super.key, this.existingProduct, this.catalogStub});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState
    extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _stockController;
  late TextEditingController _thresholdController;

  // Pack / Wholesale calculator controllers
  bool _usePackCalculator = false;
  late TextEditingController _packCostController;
  late TextEditingController _packQtyController;

  // Bundle pricing controllers
  bool _enableBundlePricing = false;
  late TextEditingController _bundleQtyController;
  late TextEditingController _bundlePriceController;

  int? _selectedCategoryId;
  String? _imagePath;

  bool _isSearchingBarcode = false;
  String? _barcodeNotice;

  bool get isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    // existingProduct for editing, catalogStub for pre-filling from catalog
    final p = widget.existingProduct;
    final stub = widget.catalogStub;

    _nameController = TextEditingController(text: p?.productName ?? stub?.productName ?? '');
    _skuController = TextEditingController(text: p?.sku ?? stub?.sku ?? '');
    _costPriceController =
        TextEditingController(text: p != null && p.costPrice > 0 ? p.costPrice.toStringAsFixed(2) : '');
    _sellingPriceController =
        TextEditingController(text: p != null && p.sellingPrice > 0 ? p.sellingPrice.toStringAsFixed(2) : '');
    _stockController =
        TextEditingController(text: p != null ? p.currentStock.toInt().toString() : '');
    _thresholdController = TextEditingController(
        text: p != null ? p.minimumThreshold.toInt().toString() : '5');
    _selectedCategoryId = p?.categoryId ?? stub?.categoryId;
    _imagePath = p?.imagePath;

    _packCostController = TextEditingController();
    _packQtyController = TextEditingController();

    _enableBundlePricing = p?.hasBundle ?? false;
    _bundleQtyController = TextEditingController(
        text: p != null && p.bundleQty > 1 ? p.bundleQty.toInt().toString() : '');
    _bundlePriceController = TextEditingController(
        text: p != null && p.bundlePrice > 0 ? p.bundlePrice.toStringAsFixed(2) : '');

    // Show hint to user that this came from catalog
    if (stub != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: ${stub.productName} — set your selling price and stock.'),
              backgroundColor: Colors.blue.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  bool _didCheckInitialBarcode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCheckInitialBarcode) {
      _didCheckInitialBarcode = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _skuController.text = args;
        _performBarcodeLookup(args);
      }
    }
  }

  Future<void> _performBarcodeLookup(String code) async {
    if (code.trim().isEmpty) return;

    setState(() {
      _isSearchingBarcode = true;
      _barcodeNotice = null;
    });

    final categories = ref.read(categoriesProvider).value ?? [];
    final result = await BarcodeLookupService.lookup(code);

    if (!mounted) return;

    setState(() {
      _isSearchingBarcode = false;
      if (result.isFound) {
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = result.productName;
        }

        if (result.categoryName != null) {
          final matchedCat = categories
              .where((c) =>
                  c.name.toLowerCase() == result.categoryName!.toLowerCase() ||
                  c.name.toLowerCase().contains(result.categoryName!.toLowerCase()))
              .firstOrNull;
          if (matchedCat != null) {
            _selectedCategoryId = matchedCat.id;
          }
        }

        _barcodeNotice = result.source == 'online'
            ? '🌐 Product details auto-filled via online database!'
            : '⚡ Product details found in local catalog!';
      } else {
        _barcodeNotice =
            'ℹ️ Barcode not in local catalog. Connect to Internet for automatic online product lookup.';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _packCostController.dispose();
    _packQtyController.dispose();
    _bundleQtyController.dispose();
    _bundlePriceController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Pack Calculator logic
  // ---------------------------------------------------------------------------

  void _calculatePackCost() {
    final packCost = double.tryParse(_packCostController.text) ?? 0;
    final packPieces = double.tryParse(_packQtyController.text) ?? 0;

    if (packCost > 0 && packPieces > 0) {
      final unitCost = packCost / packPieces;
      setState(() {
        _costPriceController.text = unitCost.toStringAsFixed(2);
        if (!isEditing && (_stockController.text.isEmpty || _stockController.text == '0')) {
          _stockController.text = packPieces.toInt().toString();
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Bundle Price logic
  // ---------------------------------------------------------------------------

  void _calculateBundlePrice() {
    final bQty = double.tryParse(_bundleQtyController.text) ?? 0;
    final bPrice = double.tryParse(_bundlePriceController.text) ?? 0;

    if (bQty > 1 && bPrice > 0) {
      final unitSell = bPrice / bQty;
      setState(() {
        _sellingPriceController.text = unitSell.toStringAsFixed(2);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Image picker
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (photo != null && mounted) {
        setState(() => _imagePath = photo.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access camera or gallery.')),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _imagePath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final cost = double.tryParse(_costPriceController.text) ?? 0;
    final sell = double.tryParse(_sellingPriceController.text) ?? 0;
    final bQty = _enableBundlePricing ? (double.tryParse(_bundleQtyController.text) ?? 1) : 1.0;
    final bPrice = _enableBundlePricing ? (double.tryParse(_bundlePriceController.text) ?? 0) : 0.0;

    final product = Product(
      id: widget.existingProduct?.id,
      productName: _nameController.text.trim(),
      sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
      categoryId: _selectedCategoryId,
      costPrice: cost,
      sellingPrice: sell,
      bundleQty: bQty > 1 ? bQty : 1,
      bundlePrice: bPrice > 0 ? bPrice : 0,
      currentStock: double.tryParse(_stockController.text) ?? 0,
      minimumThreshold: double.tryParse(_thresholdController.text) ?? 5,
      imagePath: _imagePath,
    );

    try {
      final notifier = ref.read(inventoryProvider.notifier);
      if (isEditing) {
        await notifier.updateProduct(product);
      } else {
        await notifier.addProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isEditing ? 'Product updated!' : 'Product added!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteProduct() async {
    final product = widget.existingProduct;
    if (product == null || product.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 44),
        title: const Text('Delete Product?'),
        content: Text(
          'Are you sure you want to delete "${product.productName}"?\n\nIt will be removed from your active inventory.',
        ),
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

    if (confirm != true) return;

    try {
      await ref.read(inventoryProvider.notifier).archiveProduct(product.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${product.productName}" deleted.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting product: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    final costPrice = double.tryParse(_costPriceController.text) ?? 0;
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0;
    final stock = double.tryParse(_stockController.text) ?? 0;

    final unitProfit = sellingPrice - costPrice;
    final totalProfit = unitProfit * stock;
    final margin = costPrice > 0 ? (unitProfit / costPrice) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          // Show catalog browse button only when adding a new product
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: 'Browse Product Catalog',
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const ProductCatalogScreen(),
                  ),
                );
              },
            ),
          // Show delete button when editing an existing product
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: 'Delete Product',
              onPressed: _confirmDeleteProduct,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product image
              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  height: 130,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imagePath != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_imagePath!),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 18),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                size: 36,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary),
                            const SizedBox(height: 8),
                            Text('Add Product Photo',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontWeight:
                                        FontWeight.w500)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Product Name
              const _FormLabel('Product Name *'),
              const SizedBox(height: 4),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Nescafe 3-in-1 / Marlboro Red',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Product name is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Category dropdown
              const _FormLabel('Category'),
              const SizedBox(height: 4),
              categoriesAsync.when(
                data: (categories) => DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCategoryId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // Barcode / SKU Input
              const _FormLabel('Barcode / SKU (Optional)'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _skuController,
                      decoration: InputDecoration(
                        hintText: 'e.g. 4800361000011',
                        prefixIcon: const Icon(Icons.qr_code),
                        suffixIcon: _isSearchingBarcode
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      onFieldSubmitted: (val) => _performBarcodeLookup(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () async {
                      final scanned = await showBarcodeScannerDialog(context);
                      if (scanned != null && scanned.isNotEmpty) {
                        setState(() => _skuController.text = scanned);
                        _performBarcodeLookup(scanned);
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    tooltip: 'Scan Barcode',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              if (_barcodeNotice != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _barcodeNotice!.contains('🌐') || _barcodeNotice!.contains('⚡')
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _barcodeNotice!.contains('🌐') || _barcodeNotice!.contains('⚡')
                          ? Colors.green.shade200
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Text(
                    _barcodeNotice!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _barcodeNotice!.contains('🌐') || _barcodeNotice!.contains('⚡')
                          ? Colors.green.shade900
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),


              // --- PACK / WHOLESALE COST CALCULATOR CARD ---
              Card(
                elevation: 0,
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calculate_outlined,
                              color: Colors.blue.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pack / Box Cost Calculator',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _usePackCalculator,
                            activeTrackColor: Colors.blue.shade700,
                            onChanged: (val) =>
                                setState(() => _usePackCalculator = val),
                          ),
                        ],
                      ),
                      if (_usePackCalculator) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Enter total pack cost & total pieces to auto-calculate price per piece.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue.shade800),
                        ),
                        const SizedBox(height: 14),

                        // Full width Total Pack Cost
                        _CardFieldLabel(
                          'Total Pack / Box Purchase Cost (₱)',
                          color: Colors.blue.shade900,
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _packCostController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 120.00',
                            prefixText: '₱ ',
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          onChanged: (_) => _calculatePackCost(),
                        ),
                        const SizedBox(height: 12),

                        // Full width Pieces in Pack
                        _CardFieldLabel(
                          'Total Pieces in Pack / Box',
                          color: Colors.blue.shade900,
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _packQtyController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 20 sticks / pieces',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _calculatePackCost(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- COST & SELLING PRICES SECTION ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel('Unit Cost Price'),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _costPriceController,
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            prefixText: '₱ ',
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel('Selling Price *'),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _sellingPriceController,
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            prefixText: '₱ ',
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final price = double.tryParse(v ?? '');
                            if (price == null || price <= 0) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- BUNDLE / COMBO PRICING SECTION ---
              Card(
                elevation: 0,
                color: Colors.purple.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.purple.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sell_outlined,
                              color: Colors.purple.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bundle Selling (e.g. 4 for ₱5)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _enableBundlePricing,
                            activeTrackColor: Colors.purple.shade700,
                            onChanged: (val) =>
                                setState(() => _enableBundlePricing = val),
                          ),
                        ],
                      ),
                      if (_enableBundlePricing) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Sell in multi-piece bundles (e.g. 4 candies = ₱5, or 2 paper = ₱1).',
                          style: TextStyle(
                              fontSize: 12, color: Colors.purple.shade800),
                        ),
                        const SizedBox(height: 14),

                        _CardFieldLabel(
                          'Bundle Piece Quantity',
                          color: Colors.purple.shade900,
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _bundleQtyController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 4 pieces',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _calculateBundlePrice(),
                        ),
                        const SizedBox(height: 12),

                        _CardFieldLabel(
                          'Total Bundle Selling Price (₱)',
                          color: Colors.purple.shade900,
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _bundlePriceController,
                          decoration: const InputDecoration(
                            prefixText: '₱ ',
                            hintText: 'e.g. 5.00',
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          onChanged: (_) => _calculateBundlePrice(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- LIVE TUBO (PROFIT) CALCULATOR BREAKDOWN ---
              if (costPrice > 0 || sellingPrice > 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: unitProfit >= 0
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: unitProfit >= 0
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            unitProfit >= 0
                                ? Icons.trending_up
                                : Icons.warning_amber_rounded,
                            color: unitProfit >= 0
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            unitProfit >= 0
                                ? 'Tubo (Profit) Calculation'
                                : 'Warning: Selling at a Loss',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: unitProfit >= 0
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tubo per piece:',
                              style: TextStyle(
                                  color: Colors.grey[800], fontSize: 13)),
                          Text(
                            '₱${unitProfit.toStringAsFixed(2)} / pc',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: unitProfit >= 0
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Profit Margin:',
                              style: TextStyle(
                                  color: Colors.grey[800], fontSize: 13)),
                          Text(
                            '${margin.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: unitProfit >= 0
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                      if (stock > 0) ...[
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Tubo (${stock.toInt()} pcs):',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[900],
                                  fontSize: 13),
                            ),
                            Text(
                              '₱${totalProfit.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: unitProfit >= 0
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Stock & Threshold row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel('Current Stock *'),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.inventory),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final s = double.tryParse(v ?? '');
                            if (s == null || s < 0) {
                              return 'Enter stock count';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel('Low Stock Alert'),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _thresholdController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.notifications_outlined),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Save button
              ElevatedButton(
                onPressed: _saveProduct,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(isEditing ? 'Update Product' : 'Add Product'),
              ),
              if (isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _confirmDeleteProduct,
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  label: const Text('Delete Product', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String label;
  const _FormLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Colors.black87,
      ),
    );
  }
}

class _CardFieldLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _CardFieldLabel(this.label, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: color,
      ),
    );
  }
}
