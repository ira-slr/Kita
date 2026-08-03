import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_constants.dart';

/// Singleton class managing the local SQLite database lifecycle.
/// Implements WAL mode, foreign keys, versioned migrations,
/// and seeds default categories on first launch.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const int _databaseVersion = 3;
  static const String _databaseName = 'kita_pos.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Enable foreign keys before any operations.
  /// Note: WAL mode is Android's default — no need to set it manually.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Create all tables on first launch.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Settings table (singleton row)
    batch.execute('''
      CREATE TABLE ${DbConstants.tableSettings} (
        ${DbConstants.colId} INTEGER PRIMARY KEY,
        ${DbConstants.colStoreName} TEXT NOT NULL DEFAULT '',
        ${DbConstants.colOwnerName} TEXT,
        ${DbConstants.colCurrencyCode} TEXT NOT NULL DEFAULT 'PHP',
        ${DbConstants.colLanguageCode} TEXT NOT NULL DEFAULT 'en',
        ${DbConstants.colIsDarkMode} INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colLastBackupTimestamp} TEXT,
        ${DbConstants.colPin} TEXT
      )
    ''');

    // Insert default settings row
    batch.execute('''
      INSERT INTO ${DbConstants.tableSettings} (${DbConstants.colId})
      VALUES (1)
    ''');

    // Categories table
    batch.execute('''
      CREATE TABLE ${DbConstants.tableCategories} (
        ${DbConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colName} TEXT NOT NULL UNIQUE,
        ${DbConstants.colColorHex} TEXT,
        ${DbConstants.colIconName} TEXT
      )
    ''');

    // Suppliers table
    batch.execute('''
      CREATE TABLE ${DbConstants.tableSuppliers} (
        ${DbConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colName} TEXT NOT NULL UNIQUE,
        contact_info TEXT
      )
    ''');

    // Inventory (Master Product Catalog)
    batch.execute('''
      CREATE TABLE ${DbConstants.tableInventory} (
        ${DbConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colSku} TEXT UNIQUE,
        ${DbConstants.colProductName} TEXT NOT NULL UNIQUE,
        ${DbConstants.colCategoryId} INTEGER,
        ${DbConstants.colSupplierId} INTEGER,
        ${DbConstants.colCostPrice} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colSellingPrice} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colBundleQty} REAL NOT NULL DEFAULT 1,
        ${DbConstants.colBundlePrice} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colCurrentStock} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colMinimumThreshold} REAL NOT NULL DEFAULT 5,
        ${DbConstants.colIsArchived} INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colIsFavorite} INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colImagePath} TEXT,
        ${DbConstants.colCreatedAt} TEXT NOT NULL DEFAULT (datetime('now','localtime')),
        ${DbConstants.colUpdatedAt} TEXT NOT NULL DEFAULT (datetime('now','localtime')),
        FOREIGN KEY (${DbConstants.colCategoryId}) REFERENCES ${DbConstants.tableCategories}(${DbConstants.colId}),
        FOREIGN KEY (${DbConstants.colSupplierId}) REFERENCES ${DbConstants.tableSuppliers}(${DbConstants.colId})
      )
    ''');

    // Indexes for inventory
    batch.execute('''
      CREATE INDEX idx_inventory_product_name
      ON ${DbConstants.tableInventory}(${DbConstants.colProductName})
    ''');
    batch.execute('''
      CREATE INDEX idx_inventory_category_id
      ON ${DbConstants.tableInventory}(${DbConstants.colCategoryId})
    ''');

    // Transactions (POS Sales)
    batch.execute('''
      CREATE TABLE ${DbConstants.tableTransactions} (
        ${DbConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colTotalAmount} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colCashTendered} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colChangeGiven} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colGlobalDiscount} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colStatus} TEXT NOT NULL DEFAULT '${DbConstants.statusCompleted}',
        ${DbConstants.colCreatedAt} TEXT NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');

    // Indexes for transactions
    batch.execute('''
      CREATE INDEX idx_transactions_created_at
      ON ${DbConstants.tableTransactions}(${DbConstants.colCreatedAt})
    ''');
    batch.execute('''
      CREATE INDEX idx_transactions_status
      ON ${DbConstants.tableTransactions}(${DbConstants.colStatus})
    ''');

    // Transaction Line Items
    batch.execute('''
      CREATE TABLE ${DbConstants.tableTransactionLineItems} (
        ${DbConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colTransactionId} INTEGER NOT NULL,
        ${DbConstants.colProductId} INTEGER NOT NULL,
        ${DbConstants.colQuantity} REAL NOT NULL DEFAULT 1,
        ${DbConstants.colUnitSellingPrice} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colHistoricalCostPrice} REAL NOT NULL DEFAULT 0,
        ${DbConstants.colItemDiscount} REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (${DbConstants.colTransactionId}) REFERENCES ${DbConstants.tableTransactions}(${DbConstants.colId}),
        FOREIGN KEY (${DbConstants.colProductId}) REFERENCES ${DbConstants.tableInventory}(${DbConstants.colId})
      )
    ''');

    // Indexes for transaction line items
    batch.execute('''
      CREATE INDEX idx_tli_transaction_id
      ON ${DbConstants.tableTransactionLineItems}(${DbConstants.colTransactionId})
    ''');
    batch.execute('''
      CREATE INDEX idx_tli_product_id
      ON ${DbConstants.tableTransactionLineItems}(${DbConstants.colProductId})
    ''');

    await batch.commit(noResult: true);

    // Seed default categories
    await _seedDefaultCategories(db);

    // Create v2 tables
    await _createV2Tables(db);
  }

  /// Seed the database with common sari-sari store categories.
  Future<void> _seedDefaultCategories(Database db) async {
    final categories = [
      {'name': 'Beverages', 'color_hex': '#2196F3', 'icon_name': 'local_drink'},
      {'name': 'Canned Goods', 'color_hex': '#FF9800', 'icon_name': 'inventory_2'},
      {'name': 'Snacks', 'color_hex': '#E91E63', 'icon_name': 'cookie'},
      {'name': 'Condiments', 'color_hex': '#9C27B0', 'icon_name': 'kitchen'},
      {'name': 'Personal Care', 'color_hex': '#00BCD4', 'icon_name': 'soap'},
      {'name': 'Tobacco', 'color_hex': '#795548', 'icon_name': 'smoking_rooms'},
      {'name': 'Frozen', 'color_hex': '#03A9F4', 'icon_name': 'ac_unit'},
      {'name': 'Rice & Grains', 'color_hex': '#8BC34A', 'icon_name': 'rice_bowl'},
      {'name': 'Household', 'color_hex': '#607D8B', 'icon_name': 'home'},
      {'name': 'Others', 'color_hex': '#9E9E9E', 'icon_name': 'category'},
    ];

    for (final cat in categories) {
      await db.insert(DbConstants.tableCategories, cat);
    }
  }

  /// Versioned schema migrations.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
  }

  /// Tables added in schema version 2.
  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tableProductAliases} (
        ${DbConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colProductId} INTEGER NOT NULL,
        alias_text TEXT NOT NULL,
        FOREIGN KEY (${DbConstants.colProductId}) REFERENCES ${DbConstants.tableInventory}(${DbConstants.colId})
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tablePurchases} (
        ${DbConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_image_path TEXT,
        ${DbConstants.colTotalAmount} REAL NOT NULL DEFAULT 0,
        items_count INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colCreatedAt} TEXT NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');
  }

  /// Migrations for version 3 (bundle pricing columns).
  Future<void> _migrateToV3(Database db) async {
    try {
      await db.execute('''
        ALTER TABLE ${DbConstants.tableInventory}
        ADD COLUMN ${DbConstants.colBundleQty} REAL NOT NULL DEFAULT 1
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        ALTER TABLE ${DbConstants.tableInventory}
        ADD COLUMN ${DbConstants.colBundlePrice} REAL NOT NULL DEFAULT 0
      ''');
    } catch (_) {}
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
