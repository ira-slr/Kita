// Database table and column name constants to prevent typos
class DbConstants {
  // Table Names
  static const String tableSettings = 'settings';
  static const String tableCategories = 'categories';
  static const String tableSuppliers = 'suppliers';
  static const String tableInventory = 'inventory';
  static const String tableProductImages = 'product_images';
  static const String tableProductAliases = 'product_aliases';
  static const String tablePurchases = 'purchases';
  static const String tablePurchaseLineItems = 'purchase_line_items';
  static const String tableTransactions = 'transactions';
  static const String tableTransactionLineItems = 'transaction_line_items';

  // Common Columns
  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  // Settings Columns
  static const String colStoreName = 'store_name';
  static const String colOwnerName = 'owner_name';
  static const String colCurrencyCode = 'currency_code';
  static const String colLanguageCode = 'language_code';
  static const String colIsDarkMode = 'is_dark_mode';
  static const String colLastBackupTimestamp = 'last_backup_timestamp';
  static const String colPin = 'pin';

  // Category Columns
  static const String colName = 'name';
  static const String colColorHex = 'color_hex';
  static const String colIconName = 'icon_name';

  // Inventory Columns
  static const String colSku = 'sku';
  static const String colProductName = 'product_name';
  static const String colCategoryId = 'category_id';
  static const String colSupplierId = 'supplier_id';
  static const String colCostPrice = 'cost_price';
  static const String colSellingPrice = 'selling_price';
  static const String colCurrentStock = 'current_stock';
  static const String colMinimumThreshold = 'minimum_threshold';
  static const String colIsArchived = 'is_archived';
  static const String colIsFavorite = 'is_favorite';
  static const String colImagePath = 'image_path';
  static const String colBundleQty = 'bundle_qty';
  static const String colBundlePrice = 'bundle_price';

  // Transaction Columns
  static const String colTotalAmount = 'total_amount';
  static const String colCashTendered = 'cash_tendered';
  static const String colChangeGiven = 'change_given';
  static const String colGlobalDiscount = 'global_discount';
  static const String colStatus = 'status';

  // Transaction Line Item Columns
  static const String colTransactionId = 'transaction_id';
  static const String colProductId = 'product_id';
  static const String colQuantity = 'quantity';
  static const String colUnitSellingPrice = 'unit_selling_price';
  static const String colHistoricalCostPrice = 'historical_cost_price';
  static const String colItemDiscount = 'item_discount';

  // Transaction Statuses
  static const String statusCompleted = 'COMPLETED';
  static const String statusVoided = 'VOIDED';
  static const String statusHeld = 'HELD';
}
