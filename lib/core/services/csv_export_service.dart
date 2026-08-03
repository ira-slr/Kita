import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../database/database_constants.dart';

class CsvExportService {
  /// Exports all inventory products to a CSV file and opens the share dialog.
  static Future<String?> exportProductsToCsv() async {
    try {
      final db = await DatabaseHelper().database;
      final products = await db.rawQuery('''
        SELECT i.*, c.${DbConstants.colName} as category_name
        FROM ${DbConstants.tableInventory} i
        LEFT JOIN ${DbConstants.tableCategories} c
          ON i.${DbConstants.colCategoryId} = c.${DbConstants.colId}
        ORDER BY i.${DbConstants.colProductName} ASC
      ''');

      if (products.isEmpty) {
        return 'No products found to export.';
      }

      final rows = <List<dynamic>>[];
      // Header
      rows.add([
        'ID',
        'SKU/Barcode',
        'Product Name',
        'Category',
        'Cost Price (₱)',
        'Selling Price (₱)',
        'Bundle Qty',
        'Bundle Price (₱)',
        'Current Stock',
        'Min Threshold',
        'Archived',
        'Created At'
      ]);

      for (final p in products) {
        rows.add([
          p[DbConstants.colId],
          p[DbConstants.colSku] ?? '',
          p[DbConstants.colProductName],
          p['category_name'] ?? 'General',
          p[DbConstants.colCostPrice] ?? 0.0,
          p[DbConstants.colSellingPrice] ?? 0.0,
          p[DbConstants.colBundleQty] ?? 1.0,
          p[DbConstants.colBundlePrice] ?? 0.0,
          p[DbConstants.colCurrentStock] ?? 0.0,
          p[DbConstants.colMinimumThreshold] ?? 5.0,
          p[DbConstants.colIsArchived] == 1 ? 'Yes' : 'No',
          p[DbConstants.colCreatedAt] ?? '',
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${dir.path}/products_export_$dateStr.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: 'Kita POS Products Catalog CSV Export');
      return null; // Success
    } catch (e, st) {
      debugPrint('❌ CSV Export Error: $e\n$st');
      return 'Failed to export products CSV: $e';
    }
  }

  /// Exports transaction sales history with line items to a CSV file.
  static Future<String?> exportTransactionsToCsv() async {
    try {
      final db = await DatabaseHelper().database;
      final query = await db.rawQuery('''
        SELECT 
          t.${DbConstants.colId} as tx_id,
          t.${DbConstants.colCreatedAt} as tx_date,
          t.${DbConstants.colStatus} as tx_status,
          t.${DbConstants.colTotalAmount} as tx_total,
          t.${DbConstants.colCashTendered} as tx_cash,
          t.${DbConstants.colChangeGiven} as tx_change,
          p.${DbConstants.colProductName} as prod_name,
          li.${DbConstants.colQuantity} as item_qty,
          li.${DbConstants.colUnitSellingPrice} as unit_price,
          li.${DbConstants.colHistoricalCostPrice} as unit_cost
        FROM ${DbConstants.tableTransactions} t
        LEFT JOIN ${DbConstants.tableTransactionLineItems} li
          ON t.${DbConstants.colId} = li.${DbConstants.colTransactionId}
        LEFT JOIN ${DbConstants.tableInventory} p
          ON li.${DbConstants.colProductId} = p.${DbConstants.colId}
        ORDER BY t.${DbConstants.colId} DESC
      ''');

      if (query.isEmpty) {
        return 'No transactions found to export.';
      }

      final rows = <List<dynamic>>[];
      // Header
      rows.add([
        'Transaction ID',
        'Date & Time',
        'Status',
        'Product Name',
        'Quantity Sold',
        'Unit Selling Price (₱)',
        'Unit Cost Price (₱)',
        'Line Total (₱)',
        'Transaction Grand Total (₱)',
        'Cash Tendered (₱)',
        'Change Given (₱)'
      ]);

      for (final q in query) {
        final qty = (q['item_qty'] as num?)?.toDouble() ?? 0.0;
        final unitPrice = (q['unit_price'] as num?)?.toDouble() ?? 0.0;
        rows.add([
          '#${q['tx_id']}',
          q['tx_date'] ?? '',
          q['tx_status'] ?? 'COMPLETED',
          q['prod_name'] ?? 'Deleted Product',
          qty,
          unitPrice,
          q['unit_cost'] ?? 0.0,
          qty * unitPrice,
          q['tx_total'] ?? 0.0,
          q['tx_cash'] ?? 0.0,
          q['tx_change'] ?? 0.0,
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${dir.path}/sales_history_$dateStr.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: 'Kita POS Sales History CSV Export');
      return null; // Success
    } catch (e, st) {
      debugPrint('❌ CSV Sales Export Error: $e\n$st');
      return 'Failed to export sales CSV: $e';
    }
  }

  /// Imports products from a CSV file picked by the user.
  static Future<String> importProductsFromCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return 'No file selected.';
      }

      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      final fields = const CsvToListConverter().convert(csvString);

      if (fields.isEmpty || fields.length < 2) {
        return 'CSV file is empty or missing data rows.';
      }

      final headers = fields.first.map((e) => e.toString().toLowerCase().trim()).toList();
      
      // Determine column indices
      final nameIdx = _findHeaderIndex(headers, ['product name', 'product_name', 'name', 'item']);
      final costIdx = _findHeaderIndex(headers, ['cost price', 'cost_price', 'cost', 'puhunan']);
      final priceIdx = _findHeaderIndex(headers, ['selling price', 'selling_price', 'price', 'benta']);
      final stockIdx = _findHeaderIndex(headers, ['current stock', 'current_stock', 'stock', 'qty', 'quantity']);
      final skuIdx = _findHeaderIndex(headers, ['sku/barcode', 'sku', 'barcode', 'code']);

      if (nameIdx == -1) {
        return 'CSV file must contain a "Product Name" column.';
      }

      final db = await DatabaseHelper().database;
      int importedCount = 0;

      await db.transaction((txn) async {
        for (int i = 1; i < fields.length; i++) {
          final row = fields[i];
          if (row.isEmpty || row[nameIdx].toString().trim().isEmpty) continue;

          final name = row[nameIdx].toString().trim();
          final cost = costIdx != -1 ? (double.tryParse(row[costIdx].toString()) ?? 0.0) : 0.0;
          final price = priceIdx != -1 ? (double.tryParse(row[priceIdx].toString()) ?? 0.0) : 0.0;
          final stock = stockIdx != -1 ? (double.tryParse(row[stockIdx].toString()) ?? 0.0) : 0.0;
          final sku = skuIdx != -1 ? row[skuIdx].toString().trim() : null;

          await txn.insert(
            DbConstants.tableInventory,
            {
              DbConstants.colProductName: name,
              DbConstants.colCategoryId: 1, // Default General Category
              DbConstants.colCostPrice: cost,
              DbConstants.colSellingPrice: price,
              DbConstants.colCurrentStock: stock,
              DbConstants.colMinimumThreshold: 5.0,
              DbConstants.colSku: sku?.isEmpty == true ? null : sku,
              DbConstants.colCreatedAt: DateTime.now().toIso8601String(),
              DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
            },
          );
          importedCount++;
        }
      });

      return 'Successfully imported $importedCount products from CSV!';
    } catch (e, st) {
      debugPrint('❌ CSV Import Error: $e\n$st');
      return 'Import failed: $e';
    }
  }

  static int _findHeaderIndex(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final index = headers.indexWhere((h) => h.contains(candidate));
      if (index != -1) return index;
    }
    return -1;
  }
}
