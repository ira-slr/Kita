/// Confidence level of a receipt line item match against existing inventory.
enum MatchConfidence {
  /// >85% similarity — auto-mapped, shown in green.
  high,

  /// 50–85% similarity — flagged for review, shown in yellow.
  low,

  /// <50% similarity — treated as a new product, shown in blue.
  none,
}

/// Represents one parsed line item from a receipt scan.
class ScannedItem {
  /// The raw OCR text from the receipt line.
  final String rawText;

  /// Parsed or user-edited product name.
  String productName;

  /// Parsed or user-edited quantity.
  double quantity;

  /// Calculated unit cost (totalCost / quantity).
  double unitCost;

  /// Total cost as printed on the receipt.
  double totalCost;

  /// How confident the fuzzy match is.
  MatchConfidence confidence;

  /// ID of the matched existing inventory product (null if new).
  int? matchedProductId;

  /// Display name of the matched product.
  String? matchedProductName;

  /// Selling price — only required when adding a new product.
  double sellingPrice;

  /// Whether the user has marked this row for deletion.
  bool isDeleted;

  ScannedItem({
    required this.rawText,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    required this.confidence,
    this.matchedProductId,
    this.matchedProductName,
    this.sellingPrice = 0,
    this.isDeleted = false,
  });

  /// Whether this item should be inserted as a new product.
  bool get isNewProduct => matchedProductId == null && !isDeleted;

  /// Whether this item needs the user to set a selling price before confirming.
  bool get needsSellingPrice => isNewProduct && sellingPrice <= 0;
}
