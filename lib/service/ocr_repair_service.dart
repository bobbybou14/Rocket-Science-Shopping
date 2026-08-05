class OcrRepairService {
  OcrRepairService._();

  /// Applies deterministic OCR corrections after normalization and before
  /// receipt parsing.
  ///
  /// The input is processed line by line and token by token so repairs remain
  /// isolated and punctuation can be preserved.
  static String repair(String normalizedText) {
    if (normalizedText.trim().isEmpty) {
      return normalizedText;
    }

    return normalizedText.split('\n').map(_repairLine).join('\n');
  }

  static String _repairLine(String line) {
    if (line.trim().isEmpty) {
      return line;
    }

    return line.replaceAllMapped(
      RegExp(r"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)*"),
      (match) => _repairToken(match.group(0)!),
    );
  }

  static String _repairToken(String token) {
    if (token.isEmpty) {
      return token;
    }

    final upperToken = token.toUpperCase();

    final exactReplacement = _exactTokenReplacements[upperToken];

    if (exactReplacement != null) {
      return _matchOriginalCase(original: token, replacement: exactReplacement);
    }

    final patternReplacement = _applyPatternRepairs(upperToken);

    if (patternReplacement != upperToken) {
      return _matchOriginalCase(
        original: token,
        replacement: patternReplacement,
      );
    }

    return token;
  }

  static String _applyPatternRepairs(String token) {
    var repaired = token;

    for (final rule in _patternRules) {
      if (rule.pattern.hasMatch(repaired)) {
        repaired = repaired.replaceAll(rule.pattern, rule.replacement);
      }
    }

    return repaired;
  }

  static String _matchOriginalCase({
    required String original,
    required String replacement,
  }) {
    if (original == original.toUpperCase()) {
      return replacement.toUpperCase();
    }

    if (original == original.toLowerCase()) {
      return replacement.toLowerCase();
    }

    if (_isTitleCase(original)) {
      return _toTitleCase(replacement);
    }

    return replacement;
  }

  static bool _isTitleCase(String value) {
    if (value.isEmpty) {
      return false;
    }

    return value[0] == value[0].toUpperCase() &&
        value.substring(1) == value.substring(1).toLowerCase();
  }

  static String _toTitleCase(String value) {
    if (value.isEmpty) {
      return value;
    }

    final lowerValue = value.toLowerCase();

    return '${lowerValue[0].toUpperCase()}${lowerValue.substring(1)}';
  }

  /// High-confidence replacements for recurring receipt abbreviations and
  /// OCR errors.
  ///
  /// Only add entries that are safe enough to apply globally.
  static const Map<String, String> _exactTokenReplacements = {
    'BRED': 'BREAD',
    'BRD': 'BREAD',

    'CRML': 'CARAMEL',
    'CRM': 'CARAMEL',

    'DRMSTK': 'DRUMSTICK',
    'ORNSTCK': 'DRUMSTICK',

    'CHKN': 'CHICKEN',
    'CHK': 'CHICKEN',

    'MLK': 'MILK',

    'BNNS': 'BANANAS',

    'WHT': 'WHITE',
    'WHI': 'WHITE',
    'WHTE': 'WHITE',
    'MITE': 'WHITE',

    'ORG': 'ORGANIC',

    'NAT': 'NATURAL',

    'YOG': 'YOGURT',

    'CHS': 'CHEESE',
    'CHSE': 'CHEESE',

    'ENGY': 'ENERGY',

    'MCCN': 'MCCAIN',
    'MLADN': 'MCCAIN',
  };

  /// Pattern-based corrections for highly repeatable OCR damage.
  ///
  /// These rules run only when there is no exact token replacement.
  static final List<_OcrRepairRule> _patternRules = [
    _OcrRepairRule(pattern: RegExp(r'^DRMSTK$'), replacement: 'DRUMSTICK'),
    _OcrRepairRule(pattern: RegExp(r'^CR?ML$'), replacement: 'CARAMEL'),
    _OcrRepairRule(pattern: RegExp(r'^WH?TE$'), replacement: 'WHITE'),
    _OcrRepairRule(pattern: RegExp(r'^MCC?N$'), replacement: 'MCCAIN'),
  ];
}

class _OcrRepairRule {
  const _OcrRepairRule({required this.pattern, required this.replacement});

  final RegExp pattern;
  final String replacement;
}
