import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_constants.dart';
import '../../core/models/store_settings.dart';

/// Provider for store settings.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, StoreSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<StoreSettings> {
  SettingsNotifier() : super(const StoreSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      DbConstants.tableSettings,
      where: '${DbConstants.colId} = ?',
      whereArgs: [1],
    );
    if (result.isNotEmpty) {
      state = StoreSettings.fromMap(result.first);
    }
  }

  Future<void> updateSettings(StoreSettings settings) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DbConstants.tableSettings,
      settings.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [1],
    );
    state = settings;
  }

  Future<void> toggleDarkMode() async {
    final updated = state.copyWith(isDarkMode: !state.isDarkMode);
    await updateSettings(updated);
  }

  Future<void> setPin(String? pin) async {
    final updated = pin == null || pin.isEmpty
        ? state.copyWith(clearPin: true)
        : state.copyWith(pin: pin);
    await updateSettings(updated);
  }
}
