import 'package:flutter/material.dart';

import '../../models/product_import_candidate.dart';
import '../../service/product_import_candidate_service.dart';
import '../../service/product_suggestion_service.dart';
import '../../widgets/create_product_dialog.dart';

class ProductImportCandidatesScreen extends StatefulWidget {
  const ProductImportCandidatesScreen({super.key});

  @override
  State<ProductImportCandidatesScreen> createState() =>
      _ProductImportCandidatesScreenState();
}

class _ProductImportCandidatesScreenState
    extends State<ProductImportCandidatesScreen> {
  late Future<List<ProductImportCandidate>> _candidates;

  @override
  void initState() {
    super.initState();
    _candidates = ProductImportCandidateService.getCandidates();
  }

  Future<void> _openCandidate(ProductImportCandidate candidate) async {
    if (!mounted) {
      return;
    }

    final suggestionResult = ProductSuggestionService.buildSuggestion(
      receiptItemName: candidate.receiptName,
      existingProducts: const [],
    );

    final suggestion = suggestionResult.suggestion.copyWith(
      barcode: candidate.barcode.isNotEmpty
          ? candidate.barcode
          : suggestionResult.suggestion.barcode,
      brand: candidate.suggestedBrand.isNotEmpty
          ? candidate.suggestedBrand
          : suggestionResult.suggestion.brand,
      category: candidate.suggestedCategory.isNotEmpty
          ? candidate.suggestedCategory
          : suggestionResult.suggestion.category,
      confidenceScore: candidate.confidenceScore,
    );

    final savedProduct = await CreateProductDialog.show(
      context: context,
      suggestion: suggestion,
      receiptItemName: candidate.receiptName,
    );

    if (!mounted || savedProduct == null) {
      return;
    }

    setState(() {
      _candidates = ProductImportCandidateService.getCandidates();
    });
  }

  Color _confidenceColor(double score) {
    if (score >= 90) {
      return Colors.green;
    }

    if (score >= 70) {
      return Colors.blue;
    }

    if (score >= 50) {
      return Colors.orange;
    }

    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Candidates')),
      body: FutureBuilder<List<ProductImportCandidate>>(
        future: _candidates,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load import candidates: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _candidates =
                              ProductImportCandidateService.getCandidates();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final candidates = snapshot.data!;

          if (candidates.isEmpty) {
            return const Center(child: Text('No import candidates found.'));
          }

          return ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final candidate = candidates[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      candidate.occurrences.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    candidate.receiptName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (candidate.suggestedBrand.isNotEmpty)
                        Text('Brand: ${candidate.suggestedBrand}'),
                      if (candidate.suggestedCategory.isNotEmpty)
                        Text('Category: ${candidate.suggestedCategory}'),
                      if (candidate.barcode.isNotEmpty)
                        Text('Barcode: ${candidate.barcode}'),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _confidenceColor(
                            candidate.confidenceScore,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Confidence: ${candidate.confidenceScore.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: _confidenceColor(candidate.confidenceScore),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Priority Score: '
                        '${candidate.priorityScore.toStringAsFixed(0)}',
                      ),
                      if (candidate.priorityScore >= 500)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Chip(
                            avatar: const Icon(Icons.priority_high, size: 18),
                            label: const Text('High Priority'),
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _openCandidate(candidate);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
