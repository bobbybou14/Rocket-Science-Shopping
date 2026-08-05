class ProductImportError {
  final int rowNumber;
  final String message;
  final Map<String, dynamic> rowData;

  const ProductImportError({
    required this.rowNumber,
    required this.message,
    required this.rowData,
  });
}

class ProductImportResult {
  final int totalRows;
  final int validRows;
  final int added;
  final int updated;
  final int skipped;
  final int failed;
  final List<ProductImportError> errors;

  const ProductImportResult({
    required this.totalRows,
    required this.validRows,
    required this.added,
    required this.updated,
    required this.skipped,
    required this.failed,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;

  bool get isSuccessful => failed == 0;

  int get processed => added + updated + skipped + failed;

  ProductImportResult copyWith({
    int? totalRows,
    int? validRows,
    int? added,
    int? updated,
    int? skipped,
    int? failed,
    List<ProductImportError>? errors,
  }) {
    return ProductImportResult(
      totalRows: totalRows ?? this.totalRows,
      validRows: validRows ?? this.validRows,
      added: added ?? this.added,
      updated: updated ?? this.updated,
      skipped: skipped ?? this.skipped,
      failed: failed ?? this.failed,
      errors: errors ?? this.errors,
    );
  }

  static const empty = ProductImportResult(
    totalRows: 0,
    validRows: 0,
    added: 0,
    updated: 0,
    skipped: 0,
    failed: 0,
  );
}
