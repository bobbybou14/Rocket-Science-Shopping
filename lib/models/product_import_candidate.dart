class ProductImportCandidate {
  final String receiptName;
  final int occurrences;
  final String suggestedBrand;
  final String suggestedCategory;
  final String barcode;
  final double confidenceScore;

  double get priorityScore => occurrences * confidenceScore;

  const ProductImportCandidate({
    required this.receiptName,
    required this.occurrences,
    this.suggestedBrand = '',
    this.suggestedCategory = '',
    this.barcode = '',
    this.confidenceScore = 0,
  });
}
