import 'package:flutter/material.dart';

import '../service/receipt_parser_service.dart';

class ReceiptParserTestScreen extends StatefulWidget {
  const ReceiptParserTestScreen({super.key});

  @override
  State<ReceiptParserTestScreen> createState() =>
      _ReceiptParserTestScreenState();
}

class _ReceiptParserTestScreenState extends State<ReceiptParserTestScreen> {
  final TextEditingController textController = TextEditingController();

  ParsedReceipt? parsedReceipt;

  void parseReceipt() {
    final result = ReceiptParserService.parse(textController.text);

    setState(() {
      parsedReceipt = result;
    });
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Not found';

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Widget resultCard() {
    final receipt = parsedReceipt;

    if (receipt == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Parsed Result',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Store: ${receipt.storeName.isEmpty ? "Not found" : receipt.storeName}',
            ),
            Text('Date: ${formatDate(receipt.purchaseDate)}'),
            Text('Subtotal: \$${receipt.subtotal.toStringAsFixed(2)}'),
            Text('Tax: \$${receipt.tax.toStringAsFixed(2)}'),
            Text('Total: \$${receipt.total.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Text(
              'Items Found: ${receipt.items.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (receipt.items.isEmpty)
              const Text('No items found.')
            else
              ...receipt.items.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text(
                    'Confidence: ${item.confidenceScore.toStringAsFixed(0)}%',
                  ),
                  trailing: Text('\$${item.price.toStringAsFixed(2)}'),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Sensitive Lines Ignored: ${receipt.ignoredSensitiveLines.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
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
    const sampleText =
        'WALMART\n'
        '2026-07-09\n'
        'MILK 2L 5.49\n'
        'BREAD 3.29\n'
        'EGGS 4.99\n'
        'SUBTOTAL 13.77\n'
        'HST 0.65\n'
        'TOTAL 14.42\n'
        'VISA CARD ****1234\n'
        'AUTH 123456';

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Parser Test')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Receipt Parser Test',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Paste raw OCR receipt text below and SmartCart will try to extract store, date, items, prices, and totals.',
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
            onPressed: () {
              textController.text = sampleText;
            },
            icon: const Icon(Icons.text_snippet),
            label: const Text('Load Sample Receipt Text'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: parseReceipt,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Parse Receipt'),
          ),
          const SizedBox(height: 20),
          resultCard(),
        ],
      ),
    );
  }
}
