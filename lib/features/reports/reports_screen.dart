import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reports_provider.dart';
import '../pos/pos_provider.dart';
import '../inventory/inventory_provider.dart';
import '../settings/settings_provider.dart';
import '../../core/models/transaction_record.dart';
import '../../core/database/database_constants.dart';
import '../../core/utils/formatters.dart';
import '../../app/theme.dart';

/// Reports screen with Financial Overview, Top Sellers, and Sales History with Void/Edit features.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(reportDataProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(inventoryProvider);
    ref.invalidate(todaySalesProvider);
    ref.invalidate(todayProfitProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final symbol = settings.currencySymbol;

    return Column(
      children: [
        // Tab Header: Overview vs Sales History
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Financial Overview'),
              Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Sales History & Edit'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Financial Overview & Top Sellers
              _OverviewTab(symbol: symbol),

              // Tab 2: Sales History (View, Edit & Void Transactions)
              _SalesHistoryTab(
                symbol: symbol,
                onRefresh: () => _refreshAll(ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 1: Financial Overview
// -----------------------------------------------------------------------------

class _OverviewTab extends ConsumerWidget {
  final String symbol;
  const _OverviewTab({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final reportAsync = ref.watch(reportDataProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reportDataProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(inventoryProvider);
        ref.invalidate(todaySalesProvider);
        ref.invalidate(todayProfitProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: [
          // Time filter chips & Refresh button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ReportPeriod.values.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_periodLabel(p)),
                            selected: period == p,
                            onSelected: (_) =>
                                ref.read(reportPeriodProvider.notifier).state = p,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: () {
                    ref.invalidate(reportDataProvider);
                    ref.invalidate(recentTransactionsProvider);
                    ref.invalidate(inventoryProvider);
                    ref.invalidate(todaySalesProvider);
                    ref.invalidate(todayProfitProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Financial Overview',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

        reportAsync.when(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _SummaryCard(
                      title: 'Total Sales',
                      value: Formatters.currency(data.totalSales, symbol: symbol),
                      icon: Icons.trending_up,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _SummaryCard(
                      title: 'Net Profit',
                      value: Formatters.currency(data.netProfit, symbol: symbol),
                      icon: data.netProfit >= 0
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: data.netProfit >= 0
                          ? AppTheme.profitGreen
                          : AppTheme.lossRed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _SummaryCard(
                      title: 'Expenses (COGS)',
                      value: Formatters.currency(data.totalCost, symbol: symbol),
                      icon: Icons.shopping_cart_outlined,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _SummaryCard(
                      title: 'Completed Txns',
                      value: '${data.transactionCount}',
                      icon: Icons.receipt_long,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),

              // Top sellers
              if (data.topSellers.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    'Top Sellers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...data.topSellers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final name = item['product_name'] as String? ?? '';
                  final qty = (item['qty_sold'] as num?)?.toDouble() ?? 0;
                  final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: index < 3
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: index < 3
                              ? Colors.amber.shade800
                              : Colors.grey,
                        ),
                      ),
                    ),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${qty.toInt()} sold'),
                    trailing: Text(
                      Formatters.currency(revenue, symbol: symbol),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.bar_chart,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'No sales data for this period.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    ),
  );
  }

  String _periodLabel(ReportPeriod p) {
    switch (p) {
      case ReportPeriod.today:
        return 'Today';
      case ReportPeriod.yesterday:
        return 'Yesterday';
      case ReportPeriod.thisWeek:
        return 'This Week';
      case ReportPeriod.thisMonth:
        return 'This Month';
      case ReportPeriod.thisYear:
        return 'This Year';
    }
  }
}

// -----------------------------------------------------------------------------
// Tab 2: Sales History & Void/Edit Transactions
// -----------------------------------------------------------------------------

class _SalesHistoryTab extends ConsumerWidget {
  final String symbol;
  final VoidCallback onRefresh;

  const _SalesHistoryTab({
    required this.symbol,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(recentTransactionsProvider);

    return historyAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No transactions recorded yet.',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isVoided = tx.status == DbConstants.statusVoided;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isVoided
                      ? Colors.red.shade200
                      : Colors.grey.shade200,
                ),
              ),
              color: isVoided ? Colors.red.shade50 : null,
              child: ListTile(
                onTap: () => _showTransactionDetailModal(
                    context, ref, tx, symbol, onRefresh),
                leading: CircleAvatar(
                  backgroundColor: isVoided
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                  child: Icon(
                    isVoided
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline,
                    color: isVoided
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      'Txn #${tx.id}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration:
                            isVoided ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isVoided
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tx.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${Formatters.fromDbString(tx.createdAt)}  •  ${tx.itemCount ?? 0} items',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          Formatters.currency(tx.totalAmount, symbol: symbol),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isVoided ? Colors.grey[500] : Colors.black87,
                            decoration:
                                isVoided ? TextDecoration.lineThrough : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showTransactionDetailModal(
    BuildContext context,
    WidgetRef ref,
    TransactionRecord tx,
    String symbol,
    VoidCallback onRefresh,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TransactionDetailSheet(
        transaction: tx,
        symbol: symbol,
        onRefresh: onRefresh,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Transaction Detail & Edit / Void Sheet Modal
// -----------------------------------------------------------------------------

class _TransactionDetailSheet extends ConsumerStatefulWidget {
  final TransactionRecord transaction;
  final String symbol;
  final VoidCallback onRefresh;

  const _TransactionDetailSheet({
    required this.transaction,
    required this.symbol,
    required this.onRefresh,
  });

  @override
  ConsumerState<_TransactionDetailSheet> createState() =>
      __TransactionDetailSheetState();
}

class __TransactionDetailSheetState
    extends ConsumerState<_TransactionDetailSheet> {
  late Future<List<TransactionLineItem>> _lineItemsFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    _lineItemsFuture =
        TransactionService.fetchLineItems(widget.transaction.id!);
  }

  // --- VOID TRANSACTION ACTION ---
  Future<void> _voidTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.red, size: 44),
        title: Text('Void Transaction #${widget.transaction.id}?'),
        content: const Text(
          'This will cancel the transaction and automatically return all items back into inventory stock.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Void Transaction'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      await TransactionService.voidTransaction(widget.transaction.id!);
      widget.onRefresh();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Transaction #${widget.transaction.id} Voided & Stock Restored!'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error voiding: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- EDIT LINE ITEM QTY ACTION ---
  Future<void> _editItemQty(TransactionLineItem item) async {
    final ctrl = TextEditingController(text: item.quantity.toInt().toString());

    final newQty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Quantity — ${item.productName ?? "Item"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Qty in Txn: ${item.quantity.toInt()} pcs',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Quantity (Set 0 to remove item)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              Navigator.pop(ctx, val);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (newQty == null || newQty == item.quantity) return;

    setState(() => _isProcessing = true);

    try {
      await TransactionService.updateLineItemQuantity(
        transactionId: widget.transaction.id!,
        lineItemId: item.id!,
        productId: item.productId,
        oldQty: item.quantity,
        newQty: newQty,
      );

      widget.onRefresh();
      setState(() {
        _isProcessing = false;
        _loadItems();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction updated & stock adjusted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating item: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final isVoided = tx.status == DbConstants.statusVoided;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction #${tx.id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      Formatters.fromDbString(tx.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isVoided ? Colors.red.shade700 : Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tx.status,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Line Items
          FutureBuilder<List<TransactionLineItem>>(
            future: _lineItemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ));
              }

              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No line items remaining.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500])),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName ?? 'Product #${item.productId}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Qty: ${item.quantity.toInt()} × ${Formatters.currency(item.unitSellingPrice, symbol: widget.symbol)}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.currency(item.lineTotal,
                              symbol: widget.symbol),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (!isVoided) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: _isProcessing
                                ? null
                                : () => _editItemQty(item),
                            tooltip: 'Edit quantity / Remove item',
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const Divider(height: 24),

          // Financial Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                Formatters.currency(tx.totalAmount, symbol: widget.symbol),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isVoided
                      ? Colors.grey[500]
                      : Theme.of(context).colorScheme.primary,
                  decoration: isVoided ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cash Tendered:', style: TextStyle(color: Colors.grey[700])),
              Text(Formatters.currency(tx.cashTendered, symbol: widget.symbol),
                  style: TextStyle(color: Colors.grey[800])),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Change Given:', style: TextStyle(color: Colors.grey[700])),
              Text(Formatters.currency(tx.changeGiven, symbol: widget.symbol),
                  style: TextStyle(color: Colors.grey[800])),
            ],
          ),

          const SizedBox(height: 24),

          // Actions Row
          if (!isVoided)
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _voidTransaction,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.block_rounded),
              label: const Text('Void Transaction & Restore Stock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
