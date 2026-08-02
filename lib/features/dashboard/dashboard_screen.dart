import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/settings_provider.dart';
import '../pos/pos_provider.dart';
import '../inventory/inventory_provider.dart';
import '../../core/utils/formatters.dart';
import '../../app/theme.dart';

/// The main Dashboard screen — nerve center of the app.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final todaySales = ref.watch(todaySalesProvider);
    final todayProfit = ref.watch(todayProfitProvider);
    final lowStockItems = ref.watch(lowStockProvider);
    final recentTxns = ref.watch(recentTransactionsProvider);
    final symbol = settings.currencySymbol;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todaySalesProvider);
        ref.invalidate(todayProfitProvider);
        ref.invalidate(lowStockProvider);
        ref.invalidate(recentTransactionsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
        children: [
          // Hero Card — Financial Summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Sales Today',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  todaySales.when(
                    data: (sales) => Text(
                      Formatters.currency(sales, symbol: symbol),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    loading: () => const SizedBox(
                      height: 44,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    error: (_, __) => const Text(
                      '—',
                      style: TextStyle(color: Colors.white, fontSize: 36),
                    ),
                  ),
                  const SizedBox(height: 12),
                  todayProfit.when(
                    data: (profit) => Row(
                      children: [
                        Icon(
                          profit >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Est. Profit: ${Formatters.currency(profit, symbol: symbol)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // Quick Actions Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _QuickActionButton(
                  icon: Icons.add_box_outlined,
                  label: 'Add Product',
                  color: Colors.green,
                  onTap: () =>
                      Navigator.of(context).pushNamed('/inventory/add'),
                ),
                const SizedBox(width: 12),
                _QuickActionButton(
                  icon: Icons.point_of_sale,
                  label: 'New Sale',
                  color: Colors.blue,
                  onTap: () {
                    // Switch to POS tab via the parent shell
                    DefaultTabController.of(context).animateTo(2);
                  },
                ),
                const SizedBox(width: 12),
                _QuickActionButton(
                  icon: Icons.bar_chart,
                  label: 'Reports',
                  color: Colors.orange,
                  onTap: () {
                    DefaultTabController.of(context).animateTo(3);
                  },
                ),
              ],
            ),
          ),

          // Low Stock Alerts
          lowStockItems.when(
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: AppTheme.lowStockOrange, size: 20),
                        const SizedBox(width: 6),
                        const Text(
                          'Low Stock Alerts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 10),
                          child: Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pushNamed(
                                '/inventory/edit',
                                arguments: item,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.isOutOfStock
                                          ? 'Out of Stock!'
                                          : 'Only ${item.currentStock.toInt()} left',
                                      style: TextStyle(
                                        color: item.isOutOfStock
                                            ? AppTheme.lossRed
                                            : AppTheme.lowStockOrange,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to restock →',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Recent Transactions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to Reports tab (index 3) to see all transactions
                    DefaultTabController.of(context).animateTo(3);
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          recentTxns.when(
            data: (txns) {
              if (txns.isEmpty) {
                return _EmptyState(
                  icon: Icons.receipt_long,
                  message: 'No sales yet today.\nTap "New Sale" to get started!',
                );
              }
              return Column(
                children: txns.take(5).map((txn) {
                  return ListTile(
                    onTap: () => _showTransactionDetailDialog(context, txn, symbol),
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.receipt,
                        color:
                            Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      Formatters.currency(txn.totalAmount, symbol: symbol),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${txn.itemCount ?? 0} items',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Formatters.fromDbString(txn.createdAt, timeOnly: true),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetailDialog(
    BuildContext context,
    dynamic txn,
    String symbol,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction #${txn.id ?? '—'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      Formatters.fromDbString(txn.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            _DetailRow(
              label: 'Total Amount',
              value: Formatters.currency(txn.totalAmount, symbol: symbol),
              bold: true,
            ),
            _DetailRow(
              label: 'Items Sold',
              value: '${txn.itemCount ?? 0} items',
            ),
            _DetailRow(
              label: 'Cash Tendered',
              value: Formatters.currency(txn.cashTendered ?? 0, symbol: symbol),
            ),
            _DetailRow(
              label: 'Change Given',
              value: Formatters.currency(txn.changeGiven ?? 0, symbol: symbol),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  DefaultTabController.of(context).animateTo(3);
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('View Full History in Reports'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey[500], height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
