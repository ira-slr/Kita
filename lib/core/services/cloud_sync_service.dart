import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_constants.dart';
import '../models/store_settings.dart';

/// How many transactions to store per Firestore batch document.
/// Keeps each document safely under Firestore's 1 MB limit.
const _txBatchSize = 100;

/// Handles Google Sign-In and complete cloud backup/restore via Firestore.
class CloudSyncService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();
  static final _fs = FirebaseFirestore.instance;

  // ─── Auth Accessors ──────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;
  static String? get userEmail => _auth.currentUser?.email;
  static String? get userName => _auth.currentUser?.displayName;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Auth Actions ─────────────────────────────────────────────────────────

  static Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── Backup ───────────────────────────────────────────────────────────────

  /// Backs up ALL local data to Firestore:
  /// categories, suppliers, products, transactions, line items, and settings.
  static Future<BackupResult> backupToCloud(StoreSettings settings) async {
    if (!isSignedIn) return BackupResult.error('Please sign in first.');

    try {
      final db = await DatabaseHelper().database;

      // Read every table (join category_name so restore can map by name if IDs differ)
      final categories = await db.query(DbConstants.tableCategories);
      final suppliers = await db.query(DbConstants.tableSuppliers);
      final products = await db.rawQuery('''
        SELECT i.*, c.${DbConstants.colName} as category_name
        FROM ${DbConstants.tableInventory} i
        LEFT JOIN ${DbConstants.tableCategories} c
          ON i.${DbConstants.colCategoryId} = c.${DbConstants.colId}
      ''');
      final transactions = await db.query(
          DbConstants.tableTransactions,
          orderBy: '${DbConstants.colId} ASC');
      final lineItems =
          await db.query(DbConstants.tableTransactionLineItems);

      debugPrint('▶ [Backup] Local state: ${products.length} products, ${categories.length} categories, ${transactions.length} sales');

      final uid = currentUser!.uid;
      final mainRef =
          _fs.collection('users').doc(uid).collection('backups').doc('latest');

      final batchCount =
          transactions.isEmpty ? 0 : (transactions.length / _txBatchSize).ceil();

      // ── Write main document ─────────────────────────────────────────────────
      await mainRef.set({
        'backedUpAt': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0',
        'productCount': products.length,
        'categoryCount': categories.length,
        'supplierCount': suppliers.length,
        'transactionCount': transactions.length,
        'txBatchCount': batchCount,
        'settings': {
          'storeName': settings.storeName,
          'ownerName': settings.ownerName,
          'currencyCode': settings.currencyCode,
          'isDarkMode': settings.isDarkMode,
        },
        'categories': categories
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
        'suppliers': suppliers
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
        'products': products
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
      });

      // ── Delete old transaction batch docs ───────────────────────────────────
      final oldBatches = await mainRef.collection('tx_batches').get();
      for (final doc in oldBatches.docs) {
        await doc.reference.delete();
      }

      // ── Write transaction batches ───────────────────────────────────────────
      for (int i = 0; i < batchCount; i++) {
        final start = i * _txBatchSize;
        final end = min(start + _txBatchSize, transactions.length);
        final batchTxs = transactions.sublist(start, end);
        final batchIds =
            batchTxs.map((t) => t[DbConstants.colId]).toSet();
        final batchLineItems = lineItems
            .where((li) => batchIds.contains(li[DbConstants.colTransactionId]))
            .toList();

        await mainRef.collection('tx_batches').doc('$i').set({
          'transactions':
              batchTxs.map((r) => Map<String, dynamic>.from(r)).toList(),
          'lineItems':
              batchLineItems.map((r) => Map<String, dynamic>.from(r)).toList(),
        });
      }

      return BackupResult.success(
          '${products.length} products · ${categories.length} categories · '
          '${transactions.length} transactions backed up!');
    } catch (e, st) {
      debugPrint('❌ [Backup Error] $e\n$st');
      return BackupResult.error('Backup failed: $e');
    }
  }

  // ─── Restore ──────────────────────────────────────────────────────────────

  /// Restores ALL data from Firestore, replacing everything locally.
  static Future<RestoreResult> restoreFromCloud() async {
    if (!isSignedIn) return RestoreResult.error('Please sign in first.');

    try {
      final uid = currentUser!.uid;
      final mainRef =
          _fs.collection('users').doc(uid).collection('backups').doc('latest');
      final doc = await mainRef.get();

      if (!doc.exists || doc.data() == null) {
        return RestoreResult.error('No backup found for this Google account.');
      }

      final data = doc.data()!;
      final rawCategories =
          List<Map<String, dynamic>>.from(data['categories'] ?? []);
      final rawSuppliers =
          List<Map<String, dynamic>>.from(data['suppliers'] ?? []);
      final rawProducts =
          List<Map<String, dynamic>>.from(data['products'] ?? []);
      final settingsData =
          Map<String, dynamic>.from(data['settings'] ?? {});

      // ── Read all transaction batches ────────────────────────────────────────
      final rawTx = <Map<String, dynamic>>[];
      final rawLi = <Map<String, dynamic>>[];

      // 1. Check if transactions/lineItems exist directly in main document (legacy/root backups)
      if (data['transactions'] != null) {
        rawTx.addAll(List<Map<String, dynamic>>.from(data['transactions']));
      }
      if (data['lineItems'] != null) {
        rawLi.addAll(List<Map<String, dynamic>>.from(data['lineItems']));
      }

      // 2. Fetch all tx_batches subcollection documents
      final batchDocs = await mainRef.collection('tx_batches').get();
      for (final bDoc in batchDocs.docs) {
        final bd = bDoc.data();
        if (bd['transactions'] != null) {
          rawTx.addAll(List<Map<String, dynamic>>.from(bd['transactions']));
        }
        if (bd['lineItems'] != null) {
          rawLi.addAll(List<Map<String, dynamic>>.from(bd['lineItems']));
        }
      }

      final db = await DatabaseHelper().database;

      // Disable foreign key checks outside the transaction
      await db.execute('PRAGMA foreign_keys = OFF');

      try {
        await db.transaction((txn) async {
          // Delete existing data in child to parent order
          await txn.delete(DbConstants.tableTransactionLineItems);
          await txn.delete(DbConstants.tableTransactions);
          await txn.delete(DbConstants.tableInventory);
          await txn.delete(DbConstants.tableSuppliers);
          await txn.delete(DbConstants.tableCategories);

          // Restore categories (using normalized snake_case columns)
          for (final raw in rawCategories) {
            final row = _normalizeCategory(raw);
            await txn.insert(
              DbConstants.tableCategories,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Build category lookup maps for smart product category mapping
          final currentCategories = await txn.query(DbConstants.tableCategories);
          final catIdSet = currentCategories.map((c) => (c['id'] as num).toInt()).toSet();
          final catNameToId = <String, int>{};
          for (final c in currentCategories) {
            final id = (c['id'] as num).toInt();
            final name = (c['name'] as String).toLowerCase().trim();
            catNameToId[name] = id;
          }

          // Restore suppliers
          for (final raw in rawSuppliers) {
            final row = _cleanMap(raw);
            await txn.insert(
              DbConstants.tableSuppliers,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Restore products with smart category ID resolution
          for (final raw in rawProducts) {
            final row = _normalizeProduct(raw);
            var catId = (row['category_id'] as num?)?.toInt();

            // If category_id is missing or doesn't match any restored category ID, smartly resolve by product name/keywords!
            if (catId == null || !catIdSet.contains(catId)) {
              final prodName = (row['product_name'] ?? raw['productName'] ?? '').toString();
              final catName = (raw['category_name'] ?? raw['categoryName'] ?? '').toString();
              catId = _resolveCategoryForProduct(prodName, catName, currentCategories);
            }
            row['category_id'] = catId;

            await txn.insert(
              DbConstants.tableInventory,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Restore transactions
          for (final raw in rawTx) {
            final row = _normalizeTransaction(raw);
            await txn.insert(
              DbConstants.tableTransactions,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Restore line items
          for (final raw in rawLi) {
            final row = _normalizeLineItem(raw);
            await txn.insert(
              DbConstants.tableTransactionLineItems,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Restore settings
          await txn.rawInsert(
            '''INSERT OR REPLACE INTO ${DbConstants.tableSettings}
               (id, store_name, owner_name, currency_code, language_code,
                is_dark_mode, last_backup_timestamp)
               VALUES (1, ?, ?, ?, 'en', ?, ?)''',
            [
              settingsData['storeName'] ?? '',
              settingsData['ownerName'],
              settingsData['currencyCode'] ?? 'PHP',
              settingsData['isDarkMode'] == true ? 1 : 0,
              DateTime.now().toIso8601String(),
            ],
          );
        });
      } finally {
        await db.execute('PRAGMA foreign_keys = ON');
      }

      debugPrint('✔ [Restore] Restored ${rawProducts.length} products, ${rawCategories.length} categories, ${rawTx.length} sales');

      return RestoreResult.success(
          '${rawProducts.length} products · ${rawCategories.length} categories · '
          '${rawTx.length} transactions restored!');
    } catch (e, st) {
      debugPrint('❌ [Restore Error] $e\n$st');
      return RestoreResult.error('Restore failed: $e');
    }
  }

  // ─── Normalizers ───────────────────────────────────────────────────────────

  static Map<String, dynamic> _cleanMap(Map<String, dynamic> map) {
    final res = <String, dynamic>{};
    for (final e in map.entries) {
      if (e.value != null) res[e.key] = e.value;
    }
    return res;
  }

  static Map<String, dynamic> _normalizeCategory(Map<String, dynamic> row) {
    final res = <String, dynamic>{};
    if (row['id'] != null) res['id'] = row['id'];
    res['name'] = row['name'] ?? 'General';
    res['color_hex'] = row['color_hex'] ?? row['colorHex'] ?? '#9E9E9E';
    res['icon_name'] = row['icon_name'] ?? row['iconName'] ?? 'category';
    return res;
  }

  static Map<String, dynamic> _normalizeProduct(Map<String, dynamic> row) {
    final res = <String, dynamic>{};
    if (row['id'] != null) res['id'] = row['id'];
    if (row['sku'] != null) res['sku'] = row['sku'];
    res['product_name'] = row['product_name'] ?? row['productName'] ?? 'Unnamed Item';
    if (row['category_id'] != null || row['categoryId'] != null) {
      res['category_id'] = row['category_id'] ?? row['categoryId'];
    }
    if (row['supplier_id'] != null || row['supplierId'] != null) {
      res['supplier_id'] = row['supplier_id'] ?? row['supplierId'];
    }
    res['cost_price'] = row['cost_price'] ?? row['costPrice'] ?? 0.0;
    res['selling_price'] = row['selling_price'] ?? row['sellingPrice'] ?? 0.0;
    res['bundle_qty'] = row['bundle_qty'] ?? row['bundleQty'] ?? 1.0;
    res['bundle_price'] = row['bundle_price'] ?? row['bundlePrice'] ?? 0.0;
    res['current_stock'] = row['current_stock'] ?? row['currentStock'] ?? 0.0;
    res['minimum_threshold'] = row['minimum_threshold'] ?? row['minimumThreshold'] ?? 5.0;
    res['is_archived'] = row['is_archived'] ?? row['isArchived'] ?? 0;
    res['is_favorite'] = row['is_favorite'] ?? row['isFavorite'] ?? 0;
    if (row['image_path'] != null || row['imagePath'] != null) {
      res['image_path'] = row['image_path'] ?? row['imagePath'];
    }
    res['created_at'] = row['created_at'] ?? row['createdAt'] ?? DateTime.now().toIso8601String();
    res['updated_at'] = row['updated_at'] ?? row['updatedAt'] ?? DateTime.now().toIso8601String();
    return res;
  }

  static Map<String, dynamic> _normalizeTransaction(Map<String, dynamic> row) {
    final res = <String, dynamic>{};
    if (row['id'] != null) res['id'] = (row['id'] as num).toInt();
    res['total_amount'] = (row['total_amount'] ?? row['totalAmount'] ?? 0.0) as num;
    res['cash_tendered'] = (row['cash_tendered'] ?? row['cashTendered'] ?? 0.0) as num;
    res['change_given'] = (row['change_given'] ?? row['changeGiven'] ?? 0.0) as num;
    res['global_discount'] = (row['global_discount'] ?? row['globalDiscount'] ?? 0.0) as num;
    res['status'] = row['status'] ?? 'COMPLETED';

    final rawDate = row['created_at'] ?? row['createdAt'];
    if (rawDate != null) {
      final str = rawDate.toString();
      res['created_at'] = str.replaceAll('T', ' ').split('.').first;
    } else {
      res['created_at'] = DateTime.now().toString().split('.').first;
    }
    return res;
  }

  static Map<String, dynamic> _normalizeLineItem(Map<String, dynamic> row) {
    final res = <String, dynamic>{};
    if (row['id'] != null) res['id'] = row['id'];
    res['transaction_id'] = row['transaction_id'] ?? row['transactionId'];
    res['product_id'] = row['product_id'] ?? row['productId'];
    res['quantity'] = row['quantity'] ?? 1.0;
    res['unit_selling_price'] = row['unit_selling_price'] ?? row['unitSellingPrice'] ?? 0.0;
    res['historical_cost_price'] = row['historical_cost_price'] ?? row['historicalCostPrice'] ?? 0.0;
    res['item_discount'] = row['item_discount'] ?? row['itemDiscount'] ?? 0.0;
    return res;
  }

  static int _resolveCategoryForProduct(
      String productName, String? rawCatName, List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) return 1;

    final nameLower = productName.toLowerCase().trim();
    final rawLower = (rawCatName ?? '').toLowerCase().trim();

    // 1. Match by raw category name
    if (rawLower.isNotEmpty) {
      for (final c in categories) {
        final cName = (c['name'] as String).toLowerCase().trim();
        if (cName == rawLower || rawLower.contains(cName) || cName.contains(rawLower)) {
          return (c['id'] as num).toInt();
        }
      }
    }

    // 2. Keyword matching for common Philippine products
    String? targetCatKey;
    if (nameLower.contains('marlboro') ||
        nameLower.contains('camel') ||
        nameLower.contains('sig') ||
        nameLower.contains('fortune') ||
        nameLower.contains('winston')) {
      targetCatKey = 'tobacco';
    } else if (nameLower.contains('sarap') ||
        nameLower.contains('knorr') ||
        nameLower.contains('ajinomoto') ||
        nameLower.contains('toyo') ||
        nameLower.contains('patis') ||
        nameLower.contains('suka') ||
        nameLower.contains('salt') ||
        nameLower.contains('seasoning')) {
      targetCatKey = 'condiment';
    } else if (nameLower.contains('coffee') ||
        nameLower.contains('nescaf') ||
        nameLower.contains('kopiko') ||
        nameLower.contains('great taste') ||
        nameLower.contains('c2') ||
        nameLower.contains('coke') ||
        nameLower.contains('sprite') ||
        nameLower.contains('royal') ||
        nameLower.contains('milo') ||
        nameLower.contains('water') ||
        nameLower.contains('tea')) {
      targetCatKey = 'beverage';
    } else if (nameLower.contains('lucky me') ||
        nameLower.contains('pancit') ||
        nameLower.contains('canton') ||
        nameLower.contains('sardine') ||
        nameLower.contains('555') ||
        nameLower.contains('san jose') ||
        nameLower.contains('corned beef') ||
        nameLower.contains('meat') ||
        nameLower.contains('tuna')) {
      targetCatKey = 'canned';
    } else if (nameLower.contains('piattos') ||
        nameLower.contains('nova') ||
        nameLower.contains('ding dong') ||
        nameLower.contains('boy bawang') ||
        nameLower.contains('chip') ||
        nameLower.contains('biscuit')) {
      targetCatKey = 'snack';
    } else if (nameLower.contains('rice') || nameLower.contains('bigas')) {
      targetCatKey = 'rice';
    }

    if (targetCatKey != null) {
      for (final c in categories) {
        final cName = (c['name'] as String).toLowerCase();
        if (cName.contains(targetCatKey)) {
          return (c['id'] as num).toInt();
        }
      }
    }

    // 3. Fallback: 'Others' or first category
    final others = categories.where((c) => (c['name'] as String).toLowerCase() == 'others').firstOrNull;
    return others != null ? (others['id'] as num).toInt() : (categories.first['id'] as num).toInt();
  }

  // ─── Metadata ─────────────────────────────────────────────────────────────

  static Future<BackupInfo?> getBackupInfo() async {
    if (!isSignedIn) return null;
    try {
      final uid = currentUser!.uid;
      final doc = await _fs
          .collection('users')
          .doc(uid)
          .collection('backups')
          .doc('latest')
          .get();
      if (!doc.exists || doc.data() == null) return null;
      final d = doc.data()!;
      final ts = d['backedUpAt'] as Timestamp?;
      return BackupInfo(
        backedUpAt: ts?.toDate(),
        productCount: (d['productCount'] as int?) ?? 0,
        categoryCount: (d['categoryCount'] as int?) ?? 0,
        transactionCount: (d['transactionCount'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

// ─── Result & Info Types ──────────────────────────────────────────────────────

class BackupResult {
  final bool success;
  final String message;
  BackupResult._(this.success, this.message);
  factory BackupResult.success(String msg) => BackupResult._(true, msg);
  factory BackupResult.error(String msg) => BackupResult._(false, msg);
}

class RestoreResult {
  final bool success;
  final String message;
  RestoreResult._(this.success, this.message);
  factory RestoreResult.success(String msg) => RestoreResult._(true, msg);
  factory RestoreResult.error(String msg) => RestoreResult._(false, msg);
}

class BackupInfo {
  final DateTime? backedUpAt;
  final int productCount;
  final int categoryCount;
  final int transactionCount;
  const BackupInfo({
    this.backedUpAt,
    required this.productCount,
    required this.categoryCount,
    required this.transactionCount,
  });
}
