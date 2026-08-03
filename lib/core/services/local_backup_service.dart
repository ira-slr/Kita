import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_constants.dart';

class LocalBackupService {
  /// Exports full database state to a local JSON snapshot file.
  static Future<String> createLocalBackup() async {
    try {
      final db = await DatabaseHelper().database;

      final categories = await db.query(DbConstants.tableCategories);
      final suppliers = await db.query(DbConstants.tableSuppliers);
      final products = await db.query(DbConstants.tableInventory);
      final transactions = await db.query(DbConstants.tableTransactions);
      final lineItems = await db.query(DbConstants.tableTransactionLineItems);
      final settings = await db.query(DbConstants.tableSettings);

      final payload = {
        'appName': 'Kita POS',
        'backupVersion': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'counts': {
          'categories': categories.length,
          'suppliers': suppliers.length,
          'products': products.length,
          'transactions': transactions.length,
          'lineItems': lineItems.length,
        },
        'categories': categories,
        'suppliers': suppliers,
        'products': products,
        'transactions': transactions,
        'lineItems': lineItems,
        'settings': settings.isNotEmpty ? settings.first : {},
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
      final dir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${dir.path}/kita_pos_backup_$dateStr.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'Kita POS Local Backup Snapshot JSON');
      return 'Local backup created successfully! Saved ${products.length} products & ${transactions.length} sales.';
    } catch (e, st) {
      debugPrint('❌ Local Backup Error: $e\n$st');
      return 'Failed to create local backup: $e';
    }
  }

  /// Restores database state from a user-selected local JSON snapshot file.
  static Future<String> restoreLocalBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return 'No backup file selected.';
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (data['appName'] != 'Kita POS' && data['categories'] == null) {
        return 'Invalid backup file format for Kita POS.';
      }

      final categories = List<Map<String, dynamic>>.from(data['categories'] ?? []);
      final suppliers = List<Map<String, dynamic>>.from(data['suppliers'] ?? []);
      final products = List<Map<String, dynamic>>.from(data['products'] ?? []);
      final transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
      final lineItems = List<Map<String, dynamic>>.from(data['lineItems'] ?? []);

      final db = await DatabaseHelper().database;
      await db.execute('PRAGMA foreign_keys = OFF');

      try {
        await db.transaction((txn) async {
          await txn.delete(DbConstants.tableTransactionLineItems);
          await txn.delete(DbConstants.tableTransactions);
          await txn.delete(DbConstants.tableInventory);
          await txn.delete(DbConstants.tableSuppliers);
          await txn.delete(DbConstants.tableCategories);

          for (final row in categories) {
            await txn.insert(DbConstants.tableCategories, row, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final row in suppliers) {
            await txn.insert(DbConstants.tableSuppliers, row, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final row in products) {
            await txn.insert(DbConstants.tableInventory, row, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final row in transactions) {
            await txn.insert(DbConstants.tableTransactions, row, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final row in lineItems) {
            await txn.insert(DbConstants.tableTransactionLineItems, row, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
      } finally {
        await db.execute('PRAGMA foreign_keys = ON');
      }

      return 'Successfully restored ${products.length} products & ${transactions.length} sales from local backup!';
    } catch (e, st) {
      debugPrint('❌ Local Restore Error: $e\n$st');
      return 'Failed to restore local backup: $e';
    }
  }
}
