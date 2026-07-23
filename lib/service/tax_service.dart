class TaxService {
  static const double ontarioHstRate = 0.13;

  static double calculateTax({
    required double price,
    required int quantity,
    required bool taxable,
  }) {
    if (!taxable) return 0;
    return price * quantity * ontarioHstRate;
  }
}
