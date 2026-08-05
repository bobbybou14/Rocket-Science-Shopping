import 'receipt_dictionary_service.dart';

class ReceiptCleanupService {
  ReceiptCleanupService._();

  static const Set<String> _noiseWords = {
    'EA',
    'EACH',
    'HAJ',
    'MRD',
    'MRS',
    'OS',
    'PTS',
    'POINTS',
    'PRNIZ',
  };

  static String clean(String value) {
    var cleaned = value.toUpperCase();

    cleaned = cleaned.replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');

    cleaned = cleaned.replaceAll(RegExp(r'\b\d{8,14}\b'), ' ');

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    final initialTokens = cleaned
        .split(' ')
        .where((token) => token.isNotEmpty)
        .where((token) => !_noiseWords.contains(token))
        .where((token) => !_looksLikeWeakFragment(token))
        .toList();

    cleaned = initialTokens.join(' ');

    cleaned = ReceiptDictionaryService.expand(cleaned);

    final expandedTokens = cleaned
        .split(' ')
        .where((token) => token.isNotEmpty)
        .where((token) => !_noiseWords.contains(token))
        .where((token) => !_looksLikeWeakFragment(token))
        .toList();

    return expandedTokens.join(' ');
  }

  static bool _looksLikeWeakFragment(String token) {
    final normalized = token.trim().toUpperCase();

    if (normalized.isEmpty) {
      return true;
    }

    const protectedShortTokens = {
      'GV',
      'NN',
      'PC',
      'DR',
      'PK',
      'CT',
      'LB',
      'KG',
      'ML',
      'OZ',
    };

    if (protectedShortTokens.contains(normalized)) {
      return false;
    }

    // Keep numbers (package sizes, counts, etc.)
    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return false;
    }

    // Throw away very short fragments.
    if (normalized.length <= 2) {
      return true;
    }

    // Throw away OCR garbage that is mostly vowels.
    final lettersOnly = normalized.replaceAll(RegExp(r'[^A-Z]'), '');

    if (lettersOnly.length >= 3) {
      final vowelCount = RegExp(r'[AEIOU]').allMatches(lettersOnly).length;

      if (vowelCount / lettersOnly.length >= 0.75) {
        return true;
      }
    }

    // Throw away repeated-character OCR artifacts.
    if (RegExp(r'^(.)\1+$').hasMatch(lettersOnly)) {
      return true;
    }

    return false;
  }
}
