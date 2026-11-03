class ReceiptLineClassifier {
  const ReceiptLineClassifier._();

  static bool isDeposit(String text) {
    final compact = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Includes observed OCR forms:
    // BTL DEPOSIT L
    // BTL DEP 0 SIT L
    // Also recognises bottle/container deposits.
    return RegExp(
      r'^(?:(?:BTL|BOTTLE|CAN|CONTAINER))?DEP[O0]SIT[A-Z]?$',
    ).hasMatch(compact);
  }
}
