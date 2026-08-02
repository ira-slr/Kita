import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_provider.dart';
import '../inventory/inventory_provider.dart';
import '../reports/reports_provider.dart';
import '../../core/services/cloud_sync_service.dart';

/// Settings screen: store profile, dark mode, PIN, cloud backup.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isBacking = false;
  bool _isRestoring = false;
  BackupInfo? _backupInfo;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = CloudSyncService.currentUser;
    if (_currentUser != null) _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    final info = await CloudSyncService.getBackupInfo();
    if (mounted) setState(() => _backupInfo = info);
  }

  // ─── Sign In / Out ────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    try {
      final user = await CloudSyncService.signInWithGoogle();
      if (mounted) {
        setState(() => _currentUser = user);
        if (user != null) {
          _loadBackupInfo();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Signed in as ${user.email}'),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Sign-in failed: $e\n\nMake sure you have internet access. If the error says "PlatformException(sign_in_failed)", let your developer know.');
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await _confirm(
        'Sign Out', 'Sign out from Google? Your local data will not be deleted.');
    if (!confirmed) return;
    await CloudSyncService.signOut();
    if (mounted) setState(() { _currentUser = null; _backupInfo = null; });
  }

  // ─── Backup ───────────────────────────────────────────────────────────────

  Future<void> _backup() async {
    final settings = ref.read(settingsProvider);
    setState(() => _isBacking = true);
    try {
      final result = await CloudSyncService.backupToCloud(settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ));
      if (result.success) _loadBackupInfo();
    } finally {
      if (mounted) setState(() => _isBacking = false);
    }
  }

  // ─── Restore ──────────────────────────────────────────────────────────────

  Future<void> _restore() async {
    final confirmed = await _confirm(
      'Restore from Cloud',
      'This will replace ALL products, categories, and sales history on this phone with your cloud backup.\n\nContinue?',
    );
    if (!confirmed) return;

    setState(() => _isRestoring = true);
    try {
      final result = await CloudSyncService.restoreFromCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ));
      if (result.success) {
        // Reload all state so UI updates instantly across all tabs
        await ref.read(settingsProvider.notifier).loadSettings();
        await ref.read(inventoryProvider.notifier).loadProducts();
        ref.invalidate(categoriesProvider);
        ref.invalidate(reportDataProvider);
        await _loadBackupInfo();
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
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

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'))
        ],
      ),
    );
  }

  String _formatBackupDate(DateTime? dt) {
    if (dt == null) return 'Never';
    final local = dt.toLocal();
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, ${local.year}  $h:$m $ampm';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final isSignedIn = _currentUser != null;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

        // ── Cloud Backup ──────────────────────────────────────────────────
        _SectionHeader(title: 'Cloud Backup (Google)'),

        // Google account tile
        if (!isSignedIn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.account_circle_outlined,
                          color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sign in with Google',
                              style:
                                  TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            'Required to backup & restore your store data',
                            style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Sign In with Google'),
                  ),
                ),
              ],
            ),
          )

        else ...[
          // Signed-in account info
          ListTile(
            leading: CircleAvatar(
              backgroundImage: _currentUser?.photoURL != null
                  ? NetworkImage(_currentUser!.photoURL!)
                  : null,
              backgroundColor: colorScheme.primaryContainer,
              child: _currentUser?.photoURL == null
                  ? Text(
                      (_currentUser?.displayName ?? 'G')[0].toUpperCase(),
                      style: TextStyle(color: colorScheme.primary),
                    )
                  : null,
            ),
            title: Text(_currentUser?.displayName ?? 'Google Account'),
            subtitle: Text(_currentUser?.email ?? ''),
            trailing: TextButton(
              onPressed: _signOut,
              child: const Text('Sign Out',
                  style: TextStyle(color: Colors.red)),
            ),
          ),

          // Last backup info
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_outlined,
                      size: 20, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last backup: ${_formatBackupDate(_backupInfo?.backedUpAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_backupInfo != null)
                          Text(
                            '${_backupInfo!.productCount} products · ${_backupInfo!.categoryCount} categories · ${_backupInfo!.transactionCount} sales',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colorScheme.outline),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Backup & Restore buttons
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isBacking ? null : _backup,
                    icon: _isBacking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_isBacking ? 'Backing up…' : 'Backup Now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isRestoring ? null : _restore,
                    icon: _isRestoring
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary))
                        : const Icon(Icons.cloud_download_outlined),
                    label:
                        Text(_isRestoring ? 'Restoring…' : 'Restore'),
                  ),
                ),
              ],
            ),
          ),
        ],

        const Divider(),

        // ── About ─────────────────────────────────────────────────────────
        _SectionHeader(title: 'About'),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('SariSmart'),
          subtitle: Text('Version 1.0.0 (MVP)'),
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
                        backgroundColor: Colors.green,
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
                    backgroundColor: Colors.green,
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
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

