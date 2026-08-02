import '../database/database_constants.dart';

/// Represents a product in the store inventory.
class Product {
  final int? id;
  final String? sku;
  final String productName;
  final int? categoryId;
  final int? supplierId;
  final double costPrice;
  final double sellingPrice;
  final double bundleQty;
  final double bundlePrice;
  final double currentStock;
  final double minimumThreshold;
  final bool isArchived;
  final bool isFavorite;
  final String? imagePath;
  final String? createdAt;
  final String? updatedAt;

  // Joined fields (not in DB, populated by queries)
  final String? categoryName;
  final String? categoryColorHex;

  const Product({
    this.id,
    this.sku,
    required this.productName,
    this.categoryId,
    this.supplierId,
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.bundleQty = 1,
    this.bundlePrice = 0,
    this.currentStock = 0,
    this.minimumThreshold = 5,
    this.isArchived = false,
    this.isFavorite = false,
    this.imagePath,
    this.createdAt,
    this.updatedAt,
    this.categoryName,
    this.categoryColorHex,
  });

  /// Whether this product is sold in a bundle promo (e.g. 4 for ₱5).
  bool get hasBundle => bundleQty > 1 && bundlePrice > 0;

  /// Effective selling price per single piece/unit.
  double get effectiveSellingPrice =>
      hasBundle ? bundlePrice / bundleQty : sellingPrice;

  /// Profit per unit sold.
  double get unitProfit => effectiveSellingPrice - costPrice;

  /// Total profit earned if all current stock is sold.
  double get totalProfitForStock => unitProfit * currentStock;

  /// Profit margin as a percentage.
  double get profitMargin =>
      costPrice > 0 ? (unitProfit / costPrice) * 100 : 0;

  /// Friendly display label for bundle pricing (e.g., "4 for ₱5").
  String get bundleLabel {
    if (!hasBundle) return '';
    final formattedPrice = bundlePrice.truncateToDouble() == bundlePrice
        ? bundlePrice.toInt().toString()
        : bundlePrice.toStringAsFixed(2);
    return '${bundleQty.toInt()} for ₱$formattedPrice';
  }

  /// Whether the stock is below the minimum threshold.
  bool get isLowStock => currentStock <= minimumThreshold && currentStock > 0;

  /// Whether the product is out of stock.
  bool get isOutOfStock => currentStock <= 0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DbConstants.colId: id,
      DbConstants.colSku: sku,
      DbConstants.colProductName: productName,
      DbConstants.colCategoryId: categoryId,
      DbConstants.colSupplierId: supplierId,
      DbConstants.colCostPrice: costPrice,
      DbConstants.colSellingPrice: sellingPrice,
      DbConstants.colBundleQty: bundleQty,
      DbConstants.colBundlePrice: bundlePrice,
      DbConstants.colCurrentStock: currentStock,
      DbConstants.colMinimumThreshold: minimumThreshold,
      DbConstants.colIsArchived: isArchived ? 1 : 0,
      DbConstants.colIsFavorite: isFavorite ? 1 : 0,
      DbConstants.colImagePath: imagePath,
      DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map[DbConstants.colId] as int?,
      sku: map[DbConstants.colSku] as String?,
      productName: map[DbConstants.colProductName] as String,
      categoryId: map[DbConstants.colCategoryId] as int?,
      supplierId: map[DbConstants.colSupplierId] as int?,
      costPrice: (map[DbConstants.colCostPrice] as num?)?.toDouble() ?? 0,
      sellingPrice: (map[DbConstants.colSellingPrice] as num?)?.toDouble() ?? 0,
      bundleQty: (map[DbConstants.colBundleQty] as num?)?.toDouble() ?? 1,
      bundlePrice: (map[DbConstants.colBundlePrice] as num?)?.toDouble() ?? 0,
      currentStock: (map[DbConstants.colCurrentStock] as num?)?.toDouble() ?? 0,
      minimumThreshold:
          (map[DbConstants.colMinimumThreshold] as num?)?.toDouble() ?? 5,
      isArchived: (map[DbConstants.colIsArchived] as int?) == 1,
      isFavorite: (map[DbConstants.colIsFavorite] as int?) == 1,
      imagePath: map[DbConstants.colImagePath] as String?,
      createdAt: map[DbConstants.colCreatedAt] as String?,
      updatedAt: map[DbConstants.colUpdatedAt] as String?,
      categoryName: map['category_name'] as String?,
      categoryColorHex: map['category_color_hex'] as String?,
    );
  }

  Product copyWith({
    int? id,
    String? sku,
    String? productName,
    int? categoryId,
    int? supplierId,
    double? costPrice,
    double? sellingPrice,
    double? bundleQty,
    double? bundlePrice,
    double? currentStock,
    double? minimumThreshold,
    bool? isArchived,
    bool? isFavorite,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      productName: productName ?? this.productName,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      bundleQty: bundleQty ?? this.bundleQty,
      bundlePrice: bundlePrice ?? this.bundlePrice,
      currentStock: currentStock ?? this.currentStock,
      minimumThreshold: minimumThreshold ?? this.minimumThreshold,
      isArchived: isArchived ?? this.isArchived,
      isFavorite: isFavorite ?? this.isFavorite,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      categoryName: categoryName,
      categoryColorHex: categoryColorHex,
    );
  }
}
