import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_constants.dart';
import '../../core/models/product.dart';
import '../../core/models/category.dart';

/// Provider for the list of categories.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final db = await DatabaseHelper().database;
  final result = await db.query(DbConstants.tableCategories);
  return result.map((m) => Category.fromMap(m)).toList();
});

/// Provider for the full inventory list with category join.
final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, AsyncValue<List<Product>>>((ref) {
  return InventoryNotifier();
});

class InventoryNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  InventoryNotifier() : super(const AsyncValue.loading()) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    state = const AsyncValue.loading();
    try {
      final db = await DatabaseHelper().database;
      final result = await db.rawQuery('''
        SELECT i.*, c.${DbConstants.colName} as category_name,
               c.${DbConstants.colColorHex} as category_color_hex
        FROM ${DbConstants.tableInventory} i
        LEFT JOIN ${DbConstants.tableCategories} c
          ON i.${DbConstants.colCategoryId} = c.${DbConstants.colId}
        WHERE i.${DbConstants.colIsArchived} = 0
        ORDER BY i.${DbConstants.colProductName} ASC
      ''');
      final products = result.map((m) => Product.fromMap(m)).toList();
      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addProduct(Product product) async {
    final db = await DatabaseHelper().database;
    await db.insert(
      DbConstants.tableInventory,
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DbConstants.tableInventory,
      product.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [product.id],
    );
    await loadProducts();
  }

  Future<void> archiveProduct(int productId) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DbConstants.tableInventory,
      {
        DbConstants.colIsArchived: 1,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [productId],
    );
    await loadProducts();
  }

  /// Checks if a product with the same SKU or Name already exists in active inventory.
  Future<Product?> checkDuplicateProduct({
    String? sku,
    String? name,
    int? excludeId,
  }) async {
    final db = await DatabaseHelper().database;
    final cleanSku = sku?.trim();
    final cleanName = name?.trim().toLowerCase();

    final whereClause = StringBuffer('${DbConstants.colIsArchived} = 0 AND (');
    final args = <dynamic>[];

    var addedOr = false;
    if (cleanSku != null && cleanSku.isNotEmpty) {
      whereClause.write('${DbConstants.colSku} = ?');
      args.add(cleanSku);
      addedOr = true;
    }

    if (cleanName != null && cleanName.isNotEmpty) {
      if (addedOr) whereClause.write(' OR ');
      whereClause.write('LOWER(${DbConstants.colProductName}) = ?');
      args.add(cleanName);
      addedOr = true;
    }

    whereClause.write(')');

    if (!addedOr) return null;

    if (excludeId != null) {
      whereClause.write(' AND ${DbConstants.colId} != ?');
      args.add(excludeId);
    }

    final res = await db.query(
      DbConstants.tableInventory,
      where: whereClause.toString(),
      whereArgs: args,
      limit: 1,
    );

    if (res.isNotEmpty) {
      return Product.fromMap(res.first);
    }
    return null;
  }

  Future<void> adjustStock(int productId, double adjustment) async {
    final db = await DatabaseHelper().database;
    await db.rawUpdate('''
      UPDATE ${DbConstants.tableInventory}
      SET ${DbConstants.colCurrentStock} = ${DbConstants.colCurrentStock} + ?,
          ${DbConstants.colUpdatedAt} = datetime('now','localtime')
      WHERE ${DbConstants.colId} = ?
    ''', [adjustment, productId]);
    await loadProducts();
  }

  Future<void> toggleFavorite(int productId, bool isFavorite) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DbConstants.tableInventory,
      {DbConstants.colIsFavorite: isFavorite ? 1 : 0},
      where: '${DbConstants.colId} = ?',
      whereArgs: [productId],
    );
    await loadProducts();
  }

  /// Set stock to an exact value (e.g., after a physical count).
  Future<void> setStock(int productId, double newStock) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DbConstants.tableInventory,
      {
        DbConstants.colCurrentStock: newStock,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [productId],
    );
    await loadProducts();
  }

  /// Batch update inventory from a confirmed receipt scan.
  /// [updates] is a list of {productId, addQty, newCostPrice}.
  /// [newProducts] is a list of Products to insert.
  /// [receiptImagePath] is the path to the scanned receipt photo.
  Future<void> batchUpdateFromScan({
    required List<Map<String, dynamic>> updates,
    required List<Product> newProducts,
    String? receiptImagePath,
  }) async {
    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      // Update existing products stock + cost
      for (final u in updates) {
        await txn.rawUpdate('''
          UPDATE ${DbConstants.tableInventory}
          SET ${DbConstants.colCurrentStock} = ${DbConstants.colCurrentStock} + ?,
              ${DbConstants.colCostPrice} = ?,
              ${DbConstants.colUpdatedAt} = datetime('now','localtime')
          WHERE ${DbConstants.colId} = ?
        ''', [u['addQty'], u['newCostPrice'], u['productId']]);
      }
      // Insert new products
      for (final p in newProducts) {
        await txn.insert(DbConstants.tableInventory, p.toMap());
      }
      // Record the purchase
      final totalCost = updates.fold<double>(
        0,
        (sum, u) => sum + ((u['addQty'] as double) * (u['newCostPrice'] as double)),
      );
      await txn.insert(DbConstants.tablePurchases, {
        'receipt_image_path': receiptImagePath,
        DbConstants.colTotalAmount: totalCost,
        'items_count': updates.length + newProducts.length,
      });
    });
    await loadProducts();
  }
}

/// Provider for low-stock products (Dashboard widget).
final lowStockProvider = FutureProvider<List<Product>>((ref) async {
  final db = await DatabaseHelper().database;
  final result = await db.rawQuery('''
    SELECT i.*, c.${DbConstants.colName} as category_name,
           c.${DbConstants.colColorHex} as category_color_hex
    FROM ${DbConstants.tableInventory} i
    LEFT JOIN ${DbConstants.tableCategories} c
      ON i.${DbConstants.colCategoryId} = c.${DbConstants.colId}
    WHERE i.${DbConstants.colIsArchived} = 0
      AND i.${DbConstants.colCurrentStock} <= i.${DbConstants.colMinimumThreshold}
    ORDER BY i.${DbConstants.colCurrentStock} ASC
  ''');
  return result.map((m) => Product.fromMap(m)).toList();
});
