import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/ph_product_catalog.dart';
import '../database/database_helper.dart';
import '../database/database_constants.dart';
import '../models/product.dart';

/// Result from barcode lookup service
class BarcodeLookupResult {
  final String productName;
  final String? categoryName;
  final String source; // 'existing', 'local', 'online', 'none'
  final String? message;
  final Product? existingProduct;

  const BarcodeLookupResult({
    required this.productName,
    this.categoryName,
    required this.source,
    this.message,
    this.existingProduct,
  });

  bool get isFound => productName.isNotEmpty;
}

/// Hybrid Barcode Lookup Service (Existing Store Inventory + Offline Local Catalog + Online Open Food Facts API)
class BarcodeLookupService {
  /// Looks up product details by barcode (EAN-13, UPC, etc.)
  static Future<BarcodeLookupResult> lookup(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) {
      return const BarcodeLookupResult(
        productName: '',
        source: 'none',
        message: 'Empty barcode.',
      );
    }

    // --- STEP 0: Check Active Store Inventory (Existing Product) ---
    try {
      final db = await DatabaseHelper().database;
      final existing = await db.query(
        DbConstants.tableInventory,
        where: '${DbConstants.colSku} = ? AND ${DbConstants.colIsArchived} = 0',
        whereArgs: [cleanCode],
      );

      if (existing.isNotEmpty) {
        final pMap = existing.first;
        final existingProduct = Product.fromMap(pMap);
        return BarcodeLookupResult(
          productName: existingProduct.productName,
          categoryName: null,
          source: 'existing',
          existingProduct: existingProduct,
          message: 'Product already in your inventory: "${existingProduct.productName}"',
        );
      }
    } catch (_) {}

    // --- STEP 1: Offline Local Philippine Product Catalog Lookup ---
    for (final p in PhProductCatalog.products) {
      if (p.sku == cleanCode) {
        return BarcodeLookupResult(
          productName: p.name,
          categoryName: p.category,
          source: 'local',
          message: 'Found in local Philippine catalog (Offline)',
        );
      }
    }

    // --- STEP 2: Online Open Food Facts Database Lookup ---
    try {
      final uri = Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/$cleanCode.json');
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent':
                  'SariSmartPOS/1.0 (Contact: support@sarismart.app)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final productData = data['product'] as Map<String, dynamic>;

          String name = (productData['product_name_en'] as String?)?.trim() ??
              (productData['product_name'] as String?)?.trim() ??
              (productData['abbreviated_product_name'] as String?)?.trim() ??
              (productData['brands'] as String?)?.trim() ??
              '';

          if (name.isNotEmpty) {
            String? category;
            final categoriesStr =
                (productData['categories'] as String?)?.toLowerCase() ?? '';
            if (categoriesStr.contains('beverage') ||
                categoriesStr.contains('drink') ||
                categoriesStr.contains('coffee') ||
                categoriesStr.contains('soda') ||
                categoriesStr.contains('tea') ||
                categoriesStr.contains('water')) {
              category = 'Beverages';
            } else if (categoriesStr.contains('snack') ||
                categoriesStr.contains('chip') ||
                categoriesStr.contains('biscuit') ||
                categoriesStr.contains('candy') ||
                categoriesStr.contains('chocolate')) {
              category = 'Snacks & Biscuits';
            } else if (categoriesStr.contains('canned') ||
                categoriesStr.contains('noodle') ||
                categoriesStr.contains('soup') ||
                categoriesStr.contains('pasta')) {
              category = 'Canned Goods & Instant Noodles';
            } else if (categoriesStr.contains('hygiene') ||
                categoriesStr.contains('soap') ||
                categoriesStr.contains('shampoo') ||
                categoriesStr.contains('cleaning')) {
              category = 'Personal Care & Household';
            } else if (categoriesStr.contains('rice') ||
                categoriesStr.contains('grain') ||
                categoriesStr.contains('condiment') ||
                categoriesStr.contains('sauce')) {
              category = 'Rice, Cooking & Condiments';
            }

            return BarcodeLookupResult(
              productName: name,
              categoryName: category,
              source: 'online',
              message: 'Auto-fetched online via Open Food Facts',
            );
          }
        }
      }
    } catch (e) {
      // Network timeout or offline
      return BarcodeLookupResult(
        productName: '',
        source: 'none',
        message:
            'Offline / Network unavailable. Connect to internet for online barcode lookup.',
      );
    }

    return const BarcodeLookupResult(
      productName: '',
      source: 'none',
      message: 'Barcode not found in catalog or online database.',
    );
  }
}
