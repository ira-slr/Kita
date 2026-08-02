import '../database/database_constants.dart';

/// Represents a product category (e.g., Beverages, Snacks).
class Category {
  final int? id;
  final String name;
  final String? colorHex;
  final String? iconName;

  const Category({
    this.id,
    required this.name,
    this.colorHex,
    this.iconName,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DbConstants.colId: id,
      DbConstants.colName: name,
      DbConstants.colColorHex: colorHex,
      DbConstants.colIconName: iconName,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map[DbConstants.colId] as int?,
      name: map[DbConstants.colName] as String,
      colorHex: map[DbConstants.colColorHex] as String?,
      iconName: map[DbConstants.colIconName] as String?,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? colorHex,
    String? iconName,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
    );
  }
}
