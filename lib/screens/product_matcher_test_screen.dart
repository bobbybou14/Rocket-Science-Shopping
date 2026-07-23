import 'package:flutter/material.dart';

import '../models/product.dart';
import '../service/product_matcher_service.dart';
import '../service/product_service.dart';
import '../service/receipt_parser_service.dart';

class ProductMatcherTestScreen extends StatefulWidget {
  const ProductMatcherTestScreen({super.key});

  @override
  State<ProductMatcherTestScreen> createState() =>
      _ProductMatcherTestScreenState();
}

class _ProductMatcherTestScreenState extends State<ProductMatcherTestScreen> {
  final TextEditingController textController = TextEditingController();

  List<ProductMatchResult> results = [];
  bool isLoading = false;

  Future<void> parseAndMatch() async {
    setState(() {
      isLoading = true;
      results = [];
    });

    try {
      final parsedReceipt = ReceiptParserService.parse(textController.text);
      final products = await ProductService.getProducts();

      final matches = ProductMatcherService.matchItems(
        receiptItems: parsedReceipt.items,
        products: products,
      );

      if (!mounted) return;

      setState(() {
        results = matches;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Matching failed: $error')));
    }
  }

  void loadSampleText() {
    textController.text =
        'WALMART\n'
        '2026-07-09\n'
        'MLK HOMO 2L 5.49\n'
        'WHT BRD 3.29\n'
        'BNNS 1.264 KG 2.73\n'
        'EGGS 4.99\n'
        'SUBTOTAL 16.50\n'
        'HST 0.65\n'
        'TOTAL 17.15\n'
        'VISA CARD ****1234\n'
        'AUTH 123456';
  }

  String productName(Product? product) {
    if (product == null) return 'No match';

    final parts = [
      product.brand,
      product.name,
      product.size,
    ].where((part) => part.isNotEmpty).join(' ');

    return parts.isEmpty ? product.barcode : parts;
  }

  Widget resultCard(ProductMatchResult result) {
    return Card(
      child: ListTile(
        title: Text(result.receiptItem.name),
        subtitle: Text(
          'Matched: ${productName(result.product)}\n'
          'Reason: ${result.reason}',
        ),
        isThreeLine: true,
        trailing: Text(
          '${result.confidenceScore.toStringAsFixed(0)}%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: result.confidenceScore >= 75
                ? Colors.green
                : result.confidenceScore >= 55
                ? Colors.orange
                : Colors.red,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Matcher Test')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Product Matcher Test',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Paste receipt text, parse it, and match each item against your SmartCart product database.',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: textController,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Raw receipt text',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLoading ? null : loadSampleText,
            icon: const Icon(Icons.text_snippet),
            label: const Text('Load Sample Receipt Text'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isLoading ? null : parseAndMatch,
            icon: const Icon(Icons.auto_awesome),
            label: Text(isLoading ? 'Matching...' : 'Parse and Match'),
          ),
          const SizedBox(height: 20),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (results.isNotEmpty) ...[
            Text(
              'Matches Found: ${results.length}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...results.map(resultCard),
          ],
        ],
      ),
    );
  }
}
