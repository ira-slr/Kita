import '../database/database_constants.dart';

/// Singleton store settings stored in local SQLite.
class StoreSettings {
  final String storeName;
  final String? ownerName;
  final String currencyCode;
  final String languageCode;
  final bool isDarkMode;
  final String? lastBackupTimestamp;
  final String? pin;

  const StoreSettings({
    this.storeName = '',
    this.ownerName,
    this.currencyCode = 'PHP',
    this.languageCode = 'en',
    this.isDarkMode = false,
    this.lastBackupTimestamp,
    this.pin,
  });

  /// Returns the currency symbol for the configured currency code.
  String get currencySymbol {
    switch (currencyCode) {
      case 'PHP':
        return '₱';
      case 'USD':
        return '\$';
      default:
        return currencyCode;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      DbConstants.colId: 1,
      DbConstants.colStoreName: storeName,
      DbConstants.colOwnerName: ownerName,
      DbConstants.colCurrencyCode: currencyCode,
      DbConstants.colLanguageCode: languageCode,
      DbConstants.colIsDarkMode: isDarkMode ? 1 : 0,
      DbConstants.colLastBackupTimestamp: lastBackupTimestamp,
      DbConstants.colPin: pin,
    };
  }

  factory StoreSettings.fromMap(Map<String, dynamic> map) {
    return StoreSettings(
      storeName: map[DbConstants.colStoreName] as String? ?? '',
      ownerName: map[DbConstants.colOwnerName] as String?,
      currencyCode: map[DbConstants.colCurrencyCode] as String? ?? 'PHP',
      languageCode: map[DbConstants.colLanguageCode] as String? ?? 'en',
      isDarkMode: (map[DbConstants.colIsDarkMode] as int?) == 1,
      lastBackupTimestamp: map[DbConstants.colLastBackupTimestamp] as String?,
      pin: map[DbConstants.colPin] as String?,
    );
  }

  StoreSettings copyWith({
    String? storeName,
    String? ownerName,
    String? currencyCode,
    String? languageCode,
    bool? isDarkMode,
    String? lastBackupTimestamp,
    String? pin,
  }) {
    return StoreSettings(
      storeName: storeName ?? this.storeName,
      ownerName: ownerName ?? this.ownerName,
      currencyCode: currencyCode ?? this.currencyCode,
      languageCode: languageCode ?? this.languageCode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      lastBackupTimestamp: lastBackupTimestamp ?? this.lastBackupTimestamp,
      pin: pin ?? this.pin,
    );
  }
}
