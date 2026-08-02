import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_constants.dart';
import '../../core/models/product.dart';
import '../../core/models/transaction_record.dart';

/// Represents a single item in the POS cart.
class CartItem {
  final Product product;
  double quantity;
  double itemDiscount;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.itemDiscount = 0,
  });

  /// Total line price accounting for bundle pricing (e.g. 4 for ₱5).
  double get lineTotal {
    double base;
    if (product.hasBundle) {
      base = (quantity / product.bundleQty) * product.bundlePrice;
    } else {
      base = product.sellingPrice * quantity;
    }
    return base - itemDiscount;
  }

  CartItem copyWith({
    Product? product,
    double? quantity,
    double? itemDiscount,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      itemDiscount: itemDiscount ?? this.itemDiscount,
    );
  }
}

/// The state of the current POS session.
class CartState {
  final List<CartItem> items;
  final double globalDiscount;

  const CartState({
    this.items = const [],
    this.globalDiscount = 0,
  });

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get total => subtotal - globalDiscount;

  int get totalItemCount =>
      items.fold(0, (sum, item) => sum + item.quantity.toInt());

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    double? globalDiscount,
  }) {
    return CartState(
      items: items ?? this.items,
      globalDiscount: globalDiscount ?? this.globalDiscount,
    );
  }
}

/// Provider for the POS cart state.
final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// Add a product to the cart or increment its quantity.
  /// Returns [true] if successfully added, or [false] if stock limit was reached.
  bool addProduct(Product product) {
    if (product.isOutOfStock) return false;

    final existingIndex =
        state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final currentQty = state.items[existingIndex].quantity;
      if (currentQty + 1 > product.currentStock) {
        return false; // Stock limit reached!
      }
      final updatedItems = [...state.items];
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: currentQty + 1,
      );
      state = state.copyWith(items: updatedItems);
      return true;
    } else {
      if (product.currentStock < 1) return false;
      state = state.copyWith(
        items: [...state.items, CartItem(product: product)],
      );
      return true;
    }
  }

  /// Set a specific quantity for a cart item, capped at available stock.
  /// Returns actual set quantity.
  double setQuantity(int productId, double quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return 0;
    }

    double finalQty = quantity;
    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        final maxStock = item.product.currentStock;
        if (quantity > maxStock) {
          finalQty = maxStock;
        }
        return item.copyWith(quantity: finalQty);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
    return finalQty;
  }

  /// Remove a product from the cart.
  void removeProduct(int productId) {
    final updatedItems =
        state.items.where((item) => item.product.id != productId).toList();
    state = state.copyWith(items: updatedItems);
  }

  /// Apply a global discount.
  void setGlobalDiscount(double discount) {
    state = state.copyWith(globalDiscount: discount);
  }

  /// Clear the cart completely.
  void clearCart() {
    state = const CartState();
  }

  /// Commit the transaction to the database.
  /// Returns the change amount, or throws on failure.
  Future<double> commitTransaction(double cashTendered) async {
    if (state.isEmpty) throw Exception('Cart is empty');
    if (cashTendered < state.total) throw Exception('Insufficient cash');

    final changeGiven = cashTendered - state.total;
    final db = await DatabaseHelper().database;

    await db.transaction((txn) async {
      // 1. Insert the transaction header
      final transactionId = await txn.insert(
        DbConstants.tableTransactions,
        {
          DbConstants.colTotalAmount: state.total,
          DbConstants.colCashTendered: cashTendered,
          DbConstants.colChangeGiven: changeGiven,
          DbConstants.colGlobalDiscount: state.globalDiscount,
          DbConstants.colStatus: DbConstants.statusCompleted,
        },
      );

      // 2. Insert line items & decrement inventory
      for (final item in state.items) {
        final unitPrice = item.product.effectiveSellingPrice;
        await txn.insert(
          DbConstants.tableTransactionLineItems,
          {
            DbConstants.colTransactionId: transactionId,
            DbConstants.colProductId: item.product.id,
            DbConstants.colQuantity: item.quantity,
            DbConstants.colUnitSellingPrice: unitPrice,
            DbConstants.colHistoricalCostPrice: item.product.costPrice,
            DbConstants.colItemDiscount: item.itemDiscount,
          },
        );

        // Decrement stock
        await txn.rawUpdate('''
          UPDATE ${DbConstants.tableInventory}
          SET ${DbConstants.colCurrentStock} = ${DbConstants.colCurrentStock} - ?,
              ${DbConstants.colUpdatedAt} = datetime('now','localtime')
          WHERE ${DbConstants.colId} = ?
        ''', [item.quantity, item.product.id]);
      }
    });

    // Clear the cart after successful commit
    clearCart();
    return changeGiven;
  }
}

/// Service for Voiding & Editing past transactions.
class TransactionService {
  /// Void a transaction, restoring stock for all line items back to inventory.
  static Future<void> voidTransaction(int transactionId) async {
    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      // 1. Get line items
      final items = await txn.query(
        DbConstants.tableTransactionLineItems,
        where: '${DbConstants.colTransactionId} = ?',
        whereArgs: [transactionId],
      );

      // 2. Restore stock for each item
      for (final item in items) {
        final productId = item[DbConstants.colProductId] as int?;
        final qty = (item[DbConstants.colQuantity] as num?)?.toDouble() ?? 0;
        if (productId != null && qty > 0) {
          await txn.rawUpdate('''
            UPDATE ${DbConstants.tableInventory}
            SET ${DbConstants.colCurrentStock} = ${DbConstants.colCurrentStock} + ?,
                ${DbConstants.colUpdatedAt} = datetime('now','localtime')
            WHERE ${DbConstants.colId} = ?
          ''', [qty, productId]);
        }
      }

      // 3. Mark transaction status as VOIDED
      await txn.update(
        DbConstants.tableTransactions,
        {
          DbConstants.colStatus: DbConstants.statusVoided,
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [transactionId],
      );
    });
  }

  /// Update quantity of a line item in a transaction, adjusting stock and transaction totals.
  static Future<void> updateLineItemQuantity({
    required int transactionId,
    required int lineItemId,
    required int productId,
    required double oldQty,
    required double newQty,
  }) async {
    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      final delta = oldQty - newQty; // Positive = stock returned to inventory, Negative = stock taken

      if (newQty <= 0) {
        // Delete item from transaction
        await txn.delete(
          DbConstants.tableTransactionLineItems,
          where: '${DbConstants.colId} = ?',
          whereArgs: [lineItemId],
        );
      } else {
        // Update item quantity
        await txn.update(
          DbConstants.tableTransactionLineItems,
          {
            DbConstants.colQuantity: newQty,
          },
          where: '${DbConstants.colId} = ?',
          whereArgs: [lineItemId],
        );
      }

      // Restore/adjust inventory stock
      if (delta != 0) {
        await txn.rawUpdate('''
          UPDATE ${DbConstants.tableInventory}
          SET ${DbConstants.colCurrentStock} = ${DbConstants.colCurrentStock} + ?,
              ${DbConstants.colUpdatedAt} = datetime('now','localtime')
          WHERE ${DbConstants.colId} = ?
        ''', [delta, productId]);
      }

      // Recalculate transaction header total_amount
      final sumResult = await txn.rawQuery('''
        SELECT COALESCE(SUM(${DbConstants.colUnitSellingPrice} * ${DbConstants.colQuantity} - ${DbConstants.colItemDiscount}), 0) as new_total
        FROM ${DbConstants.tableTransactionLineItems}
        WHERE ${DbConstants.colTransactionId} = ?
      ''', [transactionId]);

      final newTotal = (sumResult.first['new_total'] as num?)?.toDouble() ?? 0;

      await txn.update(
        DbConstants.tableTransactions,
        {
          DbConstants.colTotalAmount: newTotal,
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [transactionId],
      );
    });
  }

  /// Fetch full details for a transaction including all line items.
  static Future<List<TransactionLineItem>> fetchLineItems(int transactionId) async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery('''
      SELECT tli.*, i.${DbConstants.colProductName}
      FROM ${DbConstants.tableTransactionLineItems} tli
      JOIN ${DbConstants.tableInventory} i
        ON tli.${DbConstants.colProductId} = i.${DbConstants.colId}
      WHERE tli.${DbConstants.colTransactionId} = ?
    ''', [transactionId]);

    return result.map((m) => TransactionLineItem.fromMap(m)).toList();
  }
}

/// Provider for recent transactions (Dashboard & History).
final recentTransactionsProvider =
    FutureProvider<List<TransactionRecord>>((ref) async {
  final db = await DatabaseHelper().database;
  final result = await db.rawQuery('''
    SELECT t.*,
      (SELECT COUNT(*) FROM ${DbConstants.tableTransactionLineItems}
       WHERE ${DbConstants.colTransactionId} = t.${DbConstants.colId}) as item_count
    FROM ${DbConstants.tableTransactions} t
    ORDER BY t.${DbConstants.colCreatedAt} DESC
    LIMIT 50
  ''');
  return result.map((m) => TransactionRecord.fromMap(m)).toList();
});

/// Provider for today's sales total.
final todaySalesProvider = FutureProvider<double>((ref) async {
  final db = await DatabaseHelper().database;
  final result = await db.rawQuery('''
    SELECT COALESCE(SUM(${DbConstants.colTotalAmount}), 0) as total
    FROM ${DbConstants.tableTransactions}
    WHERE ${DbConstants.colStatus} = '${DbConstants.statusCompleted}'
      AND date(${DbConstants.colCreatedAt}) = date('now','localtime')
  ''');
  return (result.first['total'] as num?)?.toDouble() ?? 0;
});

/// Provider for today's profit.
final todayProfitProvider = FutureProvider<double>((ref) async {
  final db = await DatabaseHelper().database;
  final result = await db.rawQuery('''
    SELECT COALESCE(SUM(
      (tli.${DbConstants.colUnitSellingPrice} - tli.${DbConstants.colHistoricalCostPrice})
      * tli.${DbConstants.colQuantity} - tli.${DbConstants.colItemDiscount}
    ), 0) as profit
    FROM ${DbConstants.tableTransactionLineItems} tli
    JOIN ${DbConstants.tableTransactions} t
      ON tli.${DbConstants.colTransactionId} = t.${DbConstants.colId}
    WHERE t.${DbConstants.colStatus} = '${DbConstants.statusCompleted}'
      AND date(t.${DbConstants.colCreatedAt}) = date('now','localtime')
  ''');
  return (result.first['profit'] as num?)?.toDouble() ?? 0;
});
