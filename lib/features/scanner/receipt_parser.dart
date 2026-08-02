import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/models/product.dart';
import 'scanned_item_model.dart';

/// Pure-Dart & ML Kit spatial receipt parser.
/// Optimized for Philippine Supermarket (Savemore, SM, Puregold, Robinsons)
/// and Wholesale supplier invoices.
class ReceiptParser {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Parse structured ML Kit [RecognizedText] with spatial line reconstruction.
  static List<ScannedItem> parseRecognizedText(
    RecognizedText recognizedText,
    List<Product> existingProducts,
  ) {
    final spatialLines = _reconstructSpatialLines(recognizedText);
    return parseLines(spatialLines, existingProducts);
  }

  /// Fallback plain-text parser.
  static List<ScannedItem> parse(
    String ocrText,
    List<Product> existingProducts,
  ) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return parseLines(lines, existingProducts);
  }

  /// Parse a list of text lines into [ScannedItem]s.
  static List<ScannedItem> parseLines(
    List<String> lines,
    List<Product> existingProducts,
  ) {
    final items = <ScannedItem>[];

    for (final line in lines) {
      final item = _parseLine(line, existingProducts);
      if (item != null) {
        // Avoid duplicate raw lines
        if (!items.any((i) => i.rawText == item.rawText)) {
          items.add(item);
        }
      }
    }

    return items;
  }

  // ---------------------------------------------------------------------------
  // Spatial Line Reconstruction from ML Kit Bounding Boxes
  // ---------------------------------------------------------------------------

  static List<String> _reconstructSpatialLines(RecognizedText recognizedText) {
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) return [];

    // Filter out tiny zero-height noise
    final validLines = allLines.where((l) => l.boundingBox.height > 2).toList();
    if (validLines.isEmpty) return [];

    // Sort all lines vertically by top Y coordinate
    validLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    // Group lines that fall in approximately the same vertical band (y-overlap)
    final lineGroups = <List<TextLine>>[];

    for (final line in validLines) {
      final box = line.boundingBox;
      final yCenter = box.top + (box.height / 2);

      bool added = false;
      for (final group in lineGroups) {
        final groupYSum = group.fold<double>(
            0, (sum, l) => sum + l.boundingBox.top + (l.boundingBox.height / 2));
        final groupYAvg = groupYSum / group.length;

        final avgHeight = group.fold<double>(
                0, (sum, l) => sum + l.boundingBox.height) /
            group.length;
        final tolerance = (avgHeight * 0.65).clamp(8.0, 22.0);

        if ((yCenter - groupYAvg).abs() <= tolerance) {
          group.add(line);
          added = true;
          break;
        }
      }

      if (!added) {
        lineGroups.add([line]);
      }
    }

    // Convert each horizontal line group into a single merged text string
    final result = <String>[];
    for (final group in lineGroups) {
      // Sort elements horizontally left to right
      group.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final merged = group.map((l) => l.text.trim()).join(' ').trim();
      if (merged.length > 2) {
        result.add(merged);
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Single-Line Extraction Logic (Tailored for Savemore / Supermarket receipts)
  // ---------------------------------------------------------------------------

  // Match leading quantity at the very start of the line (e.g. "3 Nissin...", "1 # Turon...")
  static final _leadingQtyPattern = RegExp(r'^(\d{1,3})\s*(?:[#*])?\s+');

  // Match @ unit price (e.g. "@33.50", "@ 22.95")
  static final _atUnitPricePattern =
      RegExp(r'@\s*(\d{1,6}(?:[.,]\d{1,2})?)', caseSensitive: false);

  // Match trailing total cost at the end of the line (e.g. "100.50", "68.75", "114.75")
  static final _trailingPricePattern =
      RegExp(r'(?:PHP|P|₱)?\s*(\d{1,6}\.\d{2})\s*$', caseSensitive: false);

  // General price fallback matcher
  static final _generalPricePattern =
      RegExp(r'\b(\d{1,6}\.\d{2})\b');

  static ScannedItem? _parseLine(String rawLine, List<Product> products) {
    final line = rawLine.trim();
    if (line.length < 3) return null;

    final lower = line.toLowerCase();
    if (_isNoise(lower)) return null;

    double qty = 1;
    double? unitCost;
    double? totalCost;

    var workLine = line;

    // --- STEP 1: Extract Leading Quantity ---
    final qtyMatch = _leadingQtyPattern.firstMatch(workLine);
    if (qtyMatch != null) {
      final qVal = double.tryParse(qtyMatch.group(1)!);
      if (qVal != null && qVal > 0 && qVal <= 500) {
        qty = qVal;
        // Strip leading qty from workLine
        workLine = workLine.substring(qtyMatch.end).trim();
      }
    }

    // --- STEP 2: Extract @ Unit Cost ---
    final atMatch = _atUnitPricePattern.firstMatch(workLine);
    if (atMatch != null) {
      final uVal = double.tryParse(atMatch.group(1)!.replaceAll(',', '.'));
      if (uVal != null && uVal > 0) {
        unitCost = uVal;
      }
      // Strip @unit price from workLine
      workLine = workLine.replaceAll(_atUnitPricePattern, '').trim();
    }

    // --- STEP 3: Extract Trailing Total Price ---
    final trailingMatch = _trailingPricePattern.firstMatch(workLine);
    if (trailingMatch != null) {
      final tVal = double.tryParse(trailingMatch.group(1)!.replaceAll(',', '.'));
      if (tVal != null && tVal > 0) {
        totalCost = tVal;
        workLine = workLine.substring(0, trailingMatch.start).trim();
      }
    } else {
      // Fallback: look for last 2-decimal number
      final matches = _generalPricePattern.allMatches(workLine).toList();
      if (matches.isNotEmpty) {
        final lastMatch = matches.last;
        final tVal = double.tryParse(lastMatch.group(1)!.replaceAll(',', '.'));
        if (tVal != null && tVal > 0) {
          totalCost = tVal;
          workLine = workLine.substring(0, lastMatch.start).trim();
        }
      }
    }

    // If no total cost price was found, this line is not a product item
    if (totalCost == null && unitCost == null) return null;

    if (totalCost == null && unitCost != null) {
      totalCost = unitCost * qty;
    } else if (unitCost == null && totalCost != null) {
      unitCost = qty > 0 ? totalCost / qty : totalCost;
    }

    // Ignore non-product prices (too cheap under 0.50 or huge numbers > 100k)
    if (totalCost! < 0.50 || totalCost > 100000) return null;

    // --- STEP 4: Clean Product Description ---
    var name = _cleanName(workLine);
    if (name.length < 2) return null;
    if (_isNoise(name.toLowerCase())) return null;

    // Format concatenated words (e.g. "FemmeTsu2Ply250" -> "Femme Tsu 2Ply 250")
    name = _formatProductName(name);

    // --- STEP 5: Fuzzy Matching against Existing Products ---
    int? matchedId;
    String? matchedName;
    MatchConfidence confidence = MatchConfidence.none;

    if (products.isNotEmpty) {
      double bestScore = 0;
      Product? bestMatch;

      final normalizedInput = _normalizeAbbreviations(name.toLowerCase());

      for (final p in products) {
        final normalizedProduct =
            _normalizeAbbreviations(p.productName.toLowerCase());
        final score = similarity(normalizedInput, normalizedProduct);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = p;
        }
      }

      if (bestMatch != null) {
        if (bestScore >= 0.75) {
          confidence = MatchConfidence.high;
          matchedId = bestMatch.id;
          matchedName = bestMatch.productName;
        } else if (bestScore >= 0.45) {
          confidence = MatchConfidence.low;
          matchedId = bestMatch.id;
          matchedName = bestMatch.productName;
        }
      }
    }

    return ScannedItem(
      rawText: rawLine,
      productName: matchedName ?? _toTitleCase(name),
      quantity: qty,
      unitCost: unitCost!,
      totalCost: totalCost,
      confidence: confidence,
      matchedProductId: matchedId,
      matchedProductName: matchedName,
    );
  }

  // ---------------------------------------------------------------------------
  // Comprehensive Noise Filter (Philippine Supermarket & Supplier Invoices)
  // ---------------------------------------------------------------------------

  static const _noiseKeywords = [
    'thank you', 'thanks', 'total', 'subtotal', 'grand total', 'vat', 'tax',
    'change', 'cash', 'amount due', 'receipt', 'invoice', 'cashier', 'date',
    'time', 'official', 'address', 'tel', 'phone', 'store', 'shop', 'discount',
    'balance', 'payment', 'paid', 'customer', 'tin', 'or no', 'or #',
    'inv #', 'inv no', 'pos #', 'terminal', 'sn:', 'permit', 'serial',
    'sales invoice', 'official receipt', 'item count', 'item(s)', 'items:',
    'bagger', 'tendered', 'vattable', 'vat-exempt', 'zero-rated', 'non-vat',
    'bdo atm', 'card no', 'authcode', 'order id', 'bus style', 'for exchange',
    'warranty', 'sanford marketing', 'savemore', 'puregold', 'robinsons',
    'super8', 'mandaue', 'cebu', 'manila', 'philippines', 'trans#', 'si#',
  ];

  static bool _isNoise(String lower) {
    for (final kw in _noiseKeywords) {
      if (lower.contains(kw)) return true;
    }
    // Skip purely numeric / date / timestamp lines
    if (RegExp(r'^\d+[\s\d.,:/-]*$').hasMatch(lower)) return true;
    // Skip very short tokens
    if (lower.length <= 2) return true;
    return false;
  }

  // ---------------------------------------------------------------------------
  // Text Cleaning & Word Unpacking
  // ---------------------------------------------------------------------------

  static String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'^[#*@\s\-_]+'), '') // strip leading symbols like #
        .replaceAll(RegExp(r'[*|/:;@#\-_=+\\()<>{}\[\]]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Unpacks concatenated words like "FemmeTsu2Ply250" -> "Femme Tsu 2Ply 250"
  static String _formatProductName(String name) {
    // Add spaces between lower-to-upper CamelCase boundaries and letters-to-numbers
    final spaced = name
        .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
        .replaceAllMapped(
            RegExp(r'([a-zA-Z])(\d{2,})'), (m) => '${m.group(1)} ${m.group(2)}');
    return _cleanName(spaced);
  }

  static String _normalizeAbbreviations(String text) {
    return text
        .replaceAll(RegExp(r'\bnesc\b'), 'nescafe')
        .replaceAll(RegExp(r'\bcoke\b'), 'coca-cola')
        .replaceAll(RegExp(r'\bmarl\b'), 'marlboro')
        .replaceAll(RegExp(r'\bsig\b'), 'sigarilyo')
        .replaceAll(RegExp(r'\bblk\b'), 'black')
        .replaceAll(RegExp(r'\borig\b'), 'original')
        .replaceAll(RegExp(r'\breg\b'), 'regular')
        .replaceAll(RegExp(r'\bbtl\b'), 'bottle')
        .replaceAll(RegExp(r'\bcan\b'), 'canned');
  }

  static String _toTitleCase(String s) {
    return s
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : w)
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // Levenshtein Similarity Ratio
  // ---------------------------------------------------------------------------

  static double similarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    final dist = _levenshtein(s1, s2);
    return 1.0 - (dist / maxLen);
  }

  static int _levenshtein(String s, String t) {
    final m = s.length;
    final n = t.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (s[i - 1] == t[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 +
              [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                  .reduce((a, b) => a < b ? a : b);
        }
      }
    }
    return dp[m][n];
  }
}
