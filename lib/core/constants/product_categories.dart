class ProductCategories {
  ProductCategories._();

  static const String produce = 'Produce';
  static const String meatPoultry = 'Meat & Poultry';
  static const String seafood = 'Seafood';
  static const String dairyEggs = 'Dairy & Eggs';
  static const String bakery = 'Bakery';
  static const String deliPrepared = 'Deli & Prepared Foods';
  static const String frozen = 'Frozen Foods';
  static const String pantry = 'Pantry';
  static const String breakfast = 'Breakfast & Cereal';
  static const String snacks = 'Snacks';
  static const String beverages = 'Beverages';
  static const String candyChocolate = 'Candy & Chocolate';
  static const String condimentsSauces = 'Condiments & Sauces';
  static const String baking = 'Baking';
  static const String international = 'International Foods';
  static const String baby = 'Baby';
  static const String household = 'Household';
  static const String healthPersonalCare = 'Health & Personal Care';
  static const String pet = 'Pet';
  static const String other = 'Other';

  static const List<String> all = [
    produce,
    meatPoultry,
    seafood,
    dairyEggs,
    bakery,
    deliPrepared,
    frozen,
    pantry,
    breakfast,
    snacks,
    beverages,
    candyChocolate,
    condimentsSauces,
    baking,
    international,
    baby,
    household,
    healthPersonalCare,
    pet,
    other,
  ];

  static String normalize(String? category) {
    final value = category?.trim() ?? '';

    if (value.isEmpty) {
      return other;
    }

    final normalized = value.toLowerCase();

    const aliases = <String, String>{
      'beverage': beverages,
      'beverages': beverages,
      'drink': beverages,
      'drinks': beverages,

      'produce': produce,
      'fruit': produce,
      'fruits': produce,
      'vegetable': produce,
      'vegetables': produce,

      'meat': meatPoultry,
      'meats': meatPoultry,
      'meat & poultry': meatPoultry,
      'poultry': meatPoultry,

      'fish': seafood,
      'seafood': seafood,

      'dairy': dairyEggs,
      'dairy & eggs': dairyEggs,
      'eggs': dairyEggs,

      'bakery': bakery,
      'bread': bakery,

      'deli': deliPrepared,
      'prepared foods': deliPrepared,
      'deli & prepared foods': deliPrepared,

      'frozen': frozen,
      'frozen food': frozen,
      'frozen foods': frozen,

      'pantry': pantry,
      'grocery': pantry,

      'breakfast': breakfast,
      'cereal': breakfast,
      'breakfast & cereal': breakfast,

      'snack': snacks,
      'snacks': snacks,

      'candy': candyChocolate,
      'chocolate': candyChocolate,
      'candy & chocolate': candyChocolate,

      'condiment': condimentsSauces,
      'condiments': condimentsSauces,
      'sauce': condimentsSauces,
      'sauces': condimentsSauces,
      'condiments & sauces': condimentsSauces,

      'baking': baking,

      'international': international,
      'international foods': international,

      'baby': baby,

      'household': household,
      'household supplies': household,

      'health': healthPersonalCare,
      'personal care': healthPersonalCare,
      'health & personal care': healthPersonalCare,

      'pet': pet,
      'pets': pet,
      'pet food': pet,

      'other': other,
    };

    return aliases[normalized] ?? other;
  }

  static bool contains(String? category) {
    if (category == null) {
      return false;
    }

    return all.contains(category.trim());
  }
}
