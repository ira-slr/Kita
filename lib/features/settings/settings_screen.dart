import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../inventory/inventory_provider.dart';
import '../reports/reports_provider.dart';
import '../../core/services/local_backup_service.dart';
import '../../core/services/csv_export_service.dart';
import '../../app/theme.dart';

/// Settings screen: store profile, dark mode, PIN, local backup & CSV, cloud backup.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLocalActionRunning = false;

  // ─── Local On-Device Backup & Restore ─────────────────────────────────────

  Future<void> _createLocalBackup() async {
    setState(() => _isLocalActionRunning = true);
    try {
      final msg = await LocalBackupService.createLocalBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.profitGreen,
        duration: const Duration(seconds: 4),
      ));
    } finally {
      if (mounted) setState(() => _isLocalActionRunning = false);
    }
  }

  Future<void> _restoreLocalBackup() async {
    final confirmed = await _confirm(
      'Restore Local Backup',
      'This will replace your current local database with the selected backup file.\n\nContinue?',
    );
    if (!confirmed) return;

    setState(() => _isLocalActionRunning = true);
    try {
      final msg = await LocalBackupService.restoreLocalBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: msg.contains('Successfully') ? AppTheme.profitGreen : AppTheme.lossRed,
        duration: const Duration(seconds: 4),
      ));
      if (msg.contains('Successfully')) {
        await _reloadAllProviders();
      }
    } finally {
      if (mounted) setState(() => _isLocalActionRunning = false);
    }
  }

  // ─── CSV Import & Export ──────────────────────────────────────────────────

  Future<void> _exportProductsCsv() async {
    final err = await CsvExportService.exportProductsToCsv();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AppTheme.lossRed,
      ));
    }
  }

  Future<void> _exportSalesCsv() async {
    final err = await CsvExportService.exportTransactionsToCsv();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AppTheme.lossRed,
      ));
    }
  }

  Future<void> _importProductsCsv() async {
    final msg = await CsvExportService.importProductsFromCsv();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: msg.contains('Successfully') ? AppTheme.profitGreen : AppTheme.lossRed,
      duration: const Duration(seconds: 4),
    ));
    if (msg.contains('Successfully')) {
      await ref.read(inventoryProvider.notifier).loadProducts();
      ref.invalidate(categoriesProvider);
    }
  }

  Future<void> _reloadAllProviders() async {
    await ref.read(settingsProvider.notifier).loadSettings();
    await ref.read(inventoryProvider.notifier).loadProducts();
    ref.invalidate(categoriesProvider);
    ref.invalidate(reportDataProvider);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm')),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [


        // ── Store Profile ──────────────────────────────────────────────────
        _SectionHeader(title: 'Store Profile'),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.store, color: colorScheme.primary),
          ),
          title: Text(settings.storeName.isEmpty
              ? 'Tap to set store name'
              : settings.storeName),
          subtitle:
              settings.ownerName != null ? Text(settings.ownerName!) : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showEditStoreDialog(context, ref),
        ),
        const Divider(),

        // ── Appearance ────────────────────────────────────────────────────
        _SectionHeader(title: 'Appearance'),
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Use dark theme throughout the app'),
          secondary:
              Icon(settings.isDarkMode ? Icons.dark_mode : Icons.light_mode),
          value: settings.isDarkMode,
          onChanged: (_) => notifier.toggleDarkMode(),
        ),
        const Divider(),

        // ── Backup & Restore ──────────────────────────────────────────────
        _SectionHeader(title: 'Backup & Restore'),
        ListTile(
          leading: Icon(Icons.sd_storage_outlined, color: colorScheme.primary),
          title: const Text('Export Local Backup'),
          subtitle: const Text('Save a complete database snapshot to device files'),
          trailing: _isLocalActionRunning
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: _isLocalActionRunning ? null : _createLocalBackup,
        ),
        ListTile(
          leading: Icon(Icons.restore_outlined, color: colorScheme.primary),
          title: const Text('Restore Local Backup'),
          subtitle: const Text('Restore database from a local snapshot file'),
          trailing: _isLocalActionRunning
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: _isLocalActionRunning ? null : _restoreLocalBackup,
        ),
        const Divider(),

        // ── CSV Import & Export ───────────────────────────────────────────
        _SectionHeader(title: 'CSV Import & Export'),
        ListTile(
          leading: Icon(Icons.file_upload_outlined, color: colorScheme.primary),
          title: const Text('Import Products (CSV)'),
          subtitle: const Text('Bulk import products from CSV file'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _importProductsCsv,
        ),
        ListTile(
          leading: Icon(Icons.table_chart_outlined, color: colorScheme.primary),
          title: const Text('Export Products Catalog (CSV)'),
          subtitle: const Text('Download all products to CSV format'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _exportProductsCsv,
        ),
        ListTile(
          leading: Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
          title: const Text('Export Sales History (CSV)'),
          subtitle: const Text('Download sales transactions to CSV format'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _exportSalesCsv,
        ),
        const Divider(),

        // ── Security ──────────────────────────────────────────────────────
        _SectionHeader(title: 'Security'),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('PIN Lock'),
          subtitle: Text(
              settings.pin != null ? 'PIN is set' : 'No PIN configured'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showPinDialog(context, ref),
        ),
        const Divider(),



        // ── About ─────────────────────────────────────────────────────────
        _SectionHeader(title: 'About'),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Kita POS'),
          subtitle: Text('Version 1.0.0 (Private & Local-First)'),
        ),
        ListTile(
          leading: Icon(Icons.system_update_outlined, color: colorScheme.primary),
          title: const Text('Check for Updates'),
          subtitle: const Text('You are using the latest version (v1.0.0)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kita POS is up to date! (Version 1.0.0)'),
                backgroundColor: AppTheme.profitGreen,
              ),
            );
          },
        ),
      ],
    );
  }

  void _showEditStoreDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final nameController =
        TextEditingController(text: settings.storeName);
    final ownerController =
        TextEditingController(text: settings.ownerName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Store Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration:
                  const InputDecoration(labelText: 'Store Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ownerController,
              decoration:
                  const InputDecoration(labelText: 'Owner Name'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).updateSettings(
                    settings.copyWith(
                      storeName: nameController.text.trim(),
                      ownerName: ownerController.text.trim().isEmpty
                          ? null
                          : ownerController.text.trim(),
                    ),
                  );
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPinDialog(BuildContext context, WidgetRef ref) {
    final pinController = TextEditingController();
    final settings = ref.read(settingsProvider);
    final hasPin = settings.pin != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hasPin ? 'Change or Remove PIN' : 'Set PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'Enter 4-digit PIN',
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
            ),
            if (hasPin)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: () {
                    ref.read(settingsProvider.notifier).setPin(null);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PIN removed'),
                        backgroundColor: AppTheme.profitGreen,
                      ),
                    );
                  },
                  child: const Text('Remove PIN',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinController.text.length == 4) {
                ref
                    .read(settingsProvider.notifier)
                    .setPin(pinController.text);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN saved!'),
                    backgroundColor: AppTheme.profitGreen,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}


