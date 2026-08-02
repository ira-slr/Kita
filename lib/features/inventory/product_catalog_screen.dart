import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/ph_product_catalog.dart';
import '../../core/models/product.dart';
import '../inventory/inventory_provider.dart';
import 'add_edit_product_screen.dart';

/// Search-and-select screen for the built-in Philippine grocery product catalog.
/// Users search for a common sari-sari store product, tap it, and are taken
/// to the Add Product form with the name and category pre-filled.
class ProductCatalogScreen extends ConsumerStatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  ConsumerState<ProductCatalogScreen> createState() =>
      _ProductCatalogScreenState();
}

class _ProductCatalogScreenState
    extends ConsumerState<ProductCatalogScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', ...PhProductCatalog.categories];

  List<PhProduct> get _filtered =>
      PhProductCatalog.search(_searchQuery, category: _selectedCategory);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectProduct(PhProduct product) async {
    // Look up whether a matching category already exists in the DB
    final categories = await ref.read(categoriesProvider.future);
    int? categoryId;
    try {
      final match = categories.firstWhere(
        (c) => c.name.toLowerCase() == product.category.toLowerCase(),
      );
      categoryId = match.id;
    } catch (_) {
      categoryId = null;
    }

    if (!mounted) return;

    // Build a stub Product for pre-filling the Add form
    final stub = Product(
      productName: product.name,
      categoryId: categoryId,
      categoryName: product.category,
      sku: product.sku,
    );

    // Navigate to AddEditProductScreen with pre-filled data
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AddEditProductScreen(existingProduct: null, catalogStub: stub),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final results = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search product... (e.g. nescafe, lucky me)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat),
                  ),
                );
              },
            ),
          ),

          // Result count banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Text(
                  '${results.length} ${results.length == 1 ? "product" : "products"}',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (_searchQuery.isNotEmpty || _selectedCategory != 'All')
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedCategory = 'All';
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off, size: 16),
                    label: const Text('Clear filter'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: results.isEmpty
                ? _EmptyResult(
                    query: _searchQuery,
                    onAddManually: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const AddEditProductScreen(),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final product = results[index];
                      return _CatalogProductTile(
                        product: product,
                        onSelect: () => _selectProduct(product),
                      );
                    },
                  ),
          ),
        ],
      ),

      // "Add Manually" FAB at bottom
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
        ),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Add Manually'),
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Catalog Product Tile
// ─────────────────────────────────────────────────────────────────────────────

class _CatalogProductTile extends StatelessWidget {
  final PhProduct product;
  final VoidCallback onSelect;

  const _CatalogProductTile({
    required this.product,
    required this.onSelect,
  });

  Color _categoryColor(String category) {
    switch (category) {
      case 'Beverages':
        return const Color(0xFF2196F3);
      case 'Canned Goods':
        return const Color(0xFFFF9800);
      case 'Snacks':
        return const Color(0xFFE91E63);
      case 'Condiments':
        return const Color(0xFF9C27B0);
      case 'Personal Care':
        return const Color(0xFF00BCD4);
      case 'Tobacco':
        return const Color(0xFF795548);
      case 'Household':
        return const Color(0xFF607D8B);
      case 'Rice & Grains':
        return const Color(0xFF8BC34A);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Beverages':
        return Icons.local_drink_outlined;
      case 'Canned Goods':
        return Icons.inventory_2_outlined;
      case 'Snacks':
        return Icons.cookie_outlined;
      case 'Condiments':
        return Icons.kitchen_outlined;
      case 'Personal Care':
        return Icons.soap_outlined;
      case 'Tobacco':
        return Icons.smoking_rooms_outlined;
      case 'Household':
        return Icons.home_outlined;
      case 'Rice & Grains':
        return Icons.rice_bowl_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = product.category;
    final color = _categoryColor(cat);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onSelect,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(_categoryIcon(cat), color: color, size: 22),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: product.variant != null
            ? Text(
                product.variant!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyResult extends StatelessWidget {
  final String query;
  final VoidCallback onAddManually;

  const _EmptyResult({required this.query, required this.onAddManually});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              query.isEmpty
                  ? 'No products found in this category.'
                  : '"$query" is not in the catalog.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You can add products manually.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onAddManually,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Add Manually'),
            ),
          ],
        ),
      ),
    );
  }
}
