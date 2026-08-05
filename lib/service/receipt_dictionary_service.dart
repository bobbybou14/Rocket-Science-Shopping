class ReceiptDictionaryService {
  ReceiptDictionaryService._();

  static const Map<String, String> _dictionary = {
    // Brands
    'GV': 'GREAT VALUE',
    'NN': 'NO NAME',

    // Common grocery abbreviations
    'SWICH': 'SANDWICH',
    'PLN': 'PLAIN',
    'ORG': 'ORGANIC',
    'NAT': 'NATURAL',

    // Dairy
    'MLD': 'MILD',
    'SHR': 'SHREDDED',
    'MOZZ': 'MOZZARELLA',
    'MOZZSH': 'MOZZARELLA SHREDDED',

    // Bakery
    'WHIT': 'WHITE',
    'WHT': 'WHITE',

    // Frozen
    'CRML': 'CARAMEL',

    // Meat
    'GRBF': 'GROUND BEEF',
    'CHKN': 'CHICKEN',

    // Pantry
    'MRSH': 'MARSHMALLOW',
    'LS': 'LARGE',
    'TORT': 'TORTILLA',
  };

  static String expand(String value) {
    final words = value.toUpperCase().split(RegExp(r'\s+'));

    final expanded = <String>[];

    for (final word in words) {
      final exactReplacement = _dictionary[word];

      if (exactReplacement != null) {
        expanded.add(exactReplacement);
        continue;
      }

      expanded.add(_expandCombinedToken(word));
    }

    return expanded.join(' ');
  }

  static String _expandCombinedToken(String word) {
    switch (word) {
      case 'MOZZSHR':
      case 'MOZZSH':
        return 'MOZZARELLA SHREDDED';

      case 'SWICHWHITE':
        return 'SANDWICH WHITE';

      case 'MINIMRSH':
        return 'MINI MARSHMALLOW';

      case 'CHKNPK':
        return 'CHICKEN PACK';

      case 'CRMLMAC':
        return 'CARAMEL MACCHIATO';

      default:
        return word;
    }
  }
}
