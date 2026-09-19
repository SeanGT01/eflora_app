/// Set of minor/stop words that should remain lowercased in title case unless
/// they are at the beginning or end of the title.
const Set<String> _titleCaseMinorWords = {
  'a',
  'an',
  'the',
  'and',
  'but',
  'or',
  'nor',
  'for',
  'yet',
  'so',
  'in',
  'on',
  'at',
  'to',
  'from',
  'by',
  'with',
  'of',
  'off',
  'as',
  'into',
  'onto',
  'upon',
  'via',
  'vs',
  'v.',
};

/// Converts a string into smart Title Case format.
///
/// Example:
/// - "bouquet of jewelry" -> "Bouquet of Jewelry"
/// - "BOUQUET OF JEWELRY" -> "Bouquet of Jewelry"
/// - "fresh gerbera and rose Bouquet" -> "Fresh Gerbera and Rose Bouquet"
/// - "hand-tied bouquet of flowers" -> "Hand-Tied Bouquet of Flowers"
/// - "valentine's day special" -> "Valentine's Day Special"
String formatTitleCase(String? text) {
  if (text == null) return '';
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';

  final words = trimmed.split(RegExp(r'\s+'));
  if (words.isEmpty) return trimmed;

  const firstIdx = 0;
  final lastIdx = words.length - 1;

  String capWord(String w) {
    if (w.contains('-')) {
      return w.split('-').map(capWord).join('-');
    }
    final match = RegExp(r'^([^a-zA-Z0-9]*)(.*?)([^a-zA-Z0-9]*)$').firstMatch(w);
    if (match == null) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }
    final lead = match.group(1) ?? '';
    final core = match.group(2) ?? '';
    final trail = match.group(3) ?? '';
    if (core.isEmpty) return w;

    if (core.contains("'")) {
      final aposParts = core.split("'");
      final firstPart = aposParts[0].isEmpty
          ? ''
          : aposParts[0][0].toUpperCase() + aposParts[0].substring(1).toLowerCase();
      final restParts = aposParts.sublist(1).map((p) => p.toLowerCase()).join("'");
      return '$lead$firstPart\'$restParts$trail';
    }

    return '$lead${core[0].toUpperCase()}${core.substring(1).toLowerCase()}$trail';
  }

  final result = <String>[];
  for (int i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.isEmpty) continue;

    final clean = word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (i == firstIdx || i == lastIdx) {
      result.add(capWord(word));
    } else if (_titleCaseMinorWords.contains(clean)) {
      final match = RegExp(r'^([^a-zA-Z0-9]*)(.*?)([^a-zA-Z0-9]*)$').firstMatch(word);
      if (match != null) {
        final lead = match.group(1) ?? '';
        final core = match.group(2) ?? '';
        final trail = match.group(3) ?? '';
        result.add('$lead${core.toLowerCase()}$trail');
      } else {
        result.add(word.toLowerCase());
      }
    } else {
      result.add(capWord(word));
    }
  }

  return result.join(' ');
}

extension TitleCaseStringExtension on String {
  String toTitleCase() => formatTitleCase(this);
}

/// Strips redundant product name from a variant name if it was included.
///
/// Examples:
/// - cleanVariantName("Sunflower Bouquet - Red", "Sunflower Bouquet") -> "Red"
/// - cleanVariantName("Red Sunflower Bouquet", "Sunflower Bouquet") -> "Red"
/// - cleanVariantName("Red", "Sunflower Bouquet") -> "Red"
/// - cleanVariantName("Sunflower Bouquet", "Sunflower Bouquet") -> "Sunflower Bouquet"
String cleanVariantName(String? variantName, String? productName) {
  if (variantName == null) return '';
  var v = variantName.trim();
  final p = (productName ?? '').trim();
  if (v.isEmpty) return '';
  if (p.isNotEmpty && v.toLowerCase().contains(p.toLowerCase())) {
    final cleaned = v.replaceAll(RegExp(RegExp.escape(p), caseSensitive: false), '').trim();
    // Strip leading or trailing separators: ' - ', ' / ', ':', '—', '–', '(', ')'
    final stripped = cleaned.replaceAll(RegExp(r'^[\s\-_:–—|/()]+|[\s\-_:–—|/()]+$'), '').trim();
    if (stripped.isNotEmpty) {
      return stripped;
    }
  }
  return v;
}
