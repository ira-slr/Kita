import '../database/database_constants.dart';

/// Represents a completed, voided, or held POS transaction.
class TransactionRecord {
  final int? id;
  final double totalAmount;
  final double cashTendered;
  final double changeGiven;
  final double globalDiscount;
  final String status;
  final String? createdAt;

  // Populated by joins, not stored directly
  final int? itemCount;
  final List<TransactionLineItem>? lineItems;

  const TransactionRecord({
    this.id,
    this.totalAmount = 0,
    this.cashTendered = 0,
    this.changeGiven = 0,
    this.globalDiscount = 0,
    this.status = DbConstants.statusCompleted,
    this.createdAt,
    this.itemCount,
    this.lineItems,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DbConstants.colId: id,
      DbConstants.colTotalAmount: totalAmount,
      DbConstants.colCashTendered: cashTendered,
      DbConstants.colChangeGiven: changeGiven,
      DbConstants.colGlobalDiscount: globalDiscount,
      DbConstants.colStatus: status,
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map[DbConstants.colId] as int?,
      totalAmount:
          (map[DbConstants.colTotalAmount] as num?)?.toDouble() ?? 0,
      cashTendered:
          (map[DbConstants.colCashTendered] as num?)?.toDouble() ?? 0,
      changeGiven:
          (map[DbConstants.colChangeGiven] as num?)?.toDouble() ?? 0,
      globalDiscount:
          (map[DbConstants.colGlobalDiscount] as num?)?.toDouble() ?? 0,
      status: map[DbConstants.colStatus] as String? ??
          DbConstants.statusCompleted,
      createdAt: map[DbConstants.colCreatedAt] as String?,
      itemCount: map['item_count'] as int?,
    );
  }
}

/// Represents a single line item within a transaction.
class TransactionLineItem {
  final int? id;
  final int transactionId;
  final int productId;
  final double quantity;
  final double unitSellingPrice;
  final double historicalCostPrice;
  final double itemDiscount;

  // Joined fields
  final String? productName;

  const TransactionLineItem({
    this.id,
    required this.transactionId,
    required this.productId,
    this.quantity = 1,
    this.unitSellingPrice = 0,
    this.historicalCostPrice = 0,
    this.itemDiscount = 0,
    this.productName,
  });

  double get lineTotal => (unitSellingPrice * quantity) - itemDiscount;
  double get lineProfit =>
      ((unitSellingPrice - historicalCostPrice) * quantity) - itemDiscount;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DbConstants.colId: id,
      DbConstants.colTransactionId: transactionId,
      DbConstants.colProductId: productId,
      DbConstants.colQuantity: quantity,
      DbConstants.colUnitSellingPrice: unitSellingPrice,
      DbConstants.colHistoricalCostPrice: historicalCostPrice,
      DbConstants.colItemDiscount: itemDiscount,
    };
  }

  factory TransactionLineItem.fromMap(Map<String, dynamic> map) {
    return TransactionLineItem(
      id: map[DbConstants.colId] as int?,
      transactionId: map[DbConstants.colTransactionId] as int,
      productId: map[DbConstants.colProductId] as int,
      quantity: (map[DbConstants.colQuantity] as num?)?.toDouble() ?? 1,
      unitSellingPrice:
          (map[DbConstants.colUnitSellingPrice] as num?)?.toDouble() ?? 0,
      historicalCostPrice:
          (map[DbConstants.colHistoricalCostPrice] as num?)?.toDouble() ?? 0,
      itemDiscount:
          (map[DbConstants.colItemDiscount] as num?)?.toDouble() ?? 0,
      productName: map[DbConstants.colProductName] as String?,
    );
  }
}
