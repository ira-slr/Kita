import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_constants.dart';

/// Time period filter for reports.
enum ReportPeriod { today, yesterday, thisWeek, thisMonth, thisYear }

/// Aggregated report data.
class ReportData {
  final double totalSales;
  final double totalCost;
  final double netProfit;
  final int transactionCount;
  final List<Map<String, dynamic>> salesByPeriod;
  final List<Map<String, dynamic>> topSellers;

  const ReportData({
    this.totalSales = 0,
    this.totalCost = 0,
    this.netProfit = 0,
    this.transactionCount = 0,
    this.salesByPeriod = const [],
    this.topSellers = const [],
  });
}

/// Provider for the selected report period.
final reportPeriodProvider = StateProvider<ReportPeriod>((ref) {
  return ReportPeriod.today;
});

/// Provider for aggregated report data.
final reportDataProvider = FutureProvider<ReportData>((ref) async {
  final period = ref.watch(reportPeriodProvider);
  final db = await DatabaseHelper().database;

  String dateFilter;
  switch (period) {
    case ReportPeriod.today:
      dateFilter = "date(t.${DbConstants.colCreatedAt}) = date('now','localtime')";
      break;
    case ReportPeriod.yesterday:
      dateFilter =
          "date(t.${DbConstants.colCreatedAt}) = date('now','localtime','-1 day')";
      break;
    case ReportPeriod.thisWeek:
      dateFilter =
          "t.${DbConstants.colCreatedAt} >= datetime('now','localtime','weekday 0','-6 days','start of day')";
      break;
    case ReportPeriod.thisMonth:
      dateFilter =
          "t.${DbConstants.colCreatedAt} >= datetime('now','localtime','start of month')";
      break;
    case ReportPeriod.thisYear:
      dateFilter =
          "t.${DbConstants.colCreatedAt} >= datetime('now','localtime','start of year')";
      break;
  }

  // Financial summary
  final summaryResult = await db.rawQuery('''
    SELECT
      COALESCE(SUM(t.${DbConstants.colTotalAmount}), 0) as total_sales,
      COUNT(t.${DbConstants.colId}) as tx_count
    FROM ${DbConstants.tableTransactions} t
    WHERE t.${DbConstants.colStatus} = '${DbConstants.statusCompleted}'
      AND $dateFilter
  ''');

  final totalSales =
      (summaryResult.first['total_sales'] as num?)?.toDouble() ?? 0;
  final txCount = (summaryResult.first['tx_count'] as int?) ?? 0;

  // Cost / Profit
  final costResult = await db.rawQuery('''
    SELECT COALESCE(SUM(
      tli.${DbConstants.colHistoricalCostPrice} * tli.${DbConstants.colQuantity}
    ), 0) as total_cost
    FROM ${DbConstants.tableTransactionLineItems} tli
    JOIN ${DbConstants.tableTransactions} t
      ON tli.${DbConstants.colTransactionId} = t.${DbConstants.colId}
    WHERE t.${DbConstants.colStatus} = '${DbConstants.statusCompleted}'
      AND $dateFilter
  ''');
  final totalCost =
      (costResult.first['total_cost'] as num?)?.toDouble() ?? 0;

  // Top sellers by quantity
  final topSellers = await db.rawQuery('''
    SELECT i.${DbConstants.colProductName},
           SUM(tli.${DbConstants.colQuantity}) as qty_sold,
           SUM(tli.${DbConstants.colUnitSellingPrice} * tli.${DbConstants.colQuantity}) as revenue
    FROM ${DbConstants.tableTransactionLineItems} tli
    JOIN ${DbConstants.tableTransactions} t
      ON tli.${DbConstants.colTransactionId} = t.${DbConstants.colId}
    JOIN ${DbConstants.tableInventory} i
      ON tli.${DbConstants.colProductId} = i.${DbConstants.colId}
    WHERE t.${DbConstants.colStatus} = '${DbConstants.statusCompleted}'
      AND $dateFilter
    GROUP BY tli.${DbConstants.colProductId}
    ORDER BY qty_sold DESC
    LIMIT 10
  ''');

  return ReportData(
    totalSales: totalSales,
    totalCost: totalCost,
    netProfit: totalSales - totalCost,
    transactionCount: txCount,
    topSellers: topSellers,
  );
});
