import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/receipt.dart';
import '../service/receipt_service.dart';
import 'receipt_details_screen.dart';

class ReceiptHistoryScreen extends StatefulWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  List<Receipt> receipts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadReceipts();
  }

  Future<void> loadReceipts() async {
    final results = await ReceiptService.getReceipts();

    if (!mounted) return;

    setState(() {
      receipts = results;
      loading = false;
    });
  }

  void openReceiptDetails(Receipt receipt) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptDetailsScreen(receipt: receipt)),
    );
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Widget receiptCard(Receipt receipt) {
    return Card(
      child: ListTile(
        onTap: () => openReceiptDetails(receipt),
        leading: const Icon(Icons.receipt_long, color: AppColors.primary),
        title: Text(
          receipt.storeName.isEmpty ? 'Receipt Upload' : receipt.storeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Status: ${receipt.processingStatus}\n'
          'Privacy redacted: ${receipt.personalDataRedacted ? "Yes" : "No"}\n'
          'Created: ${formatDate(receipt.createdAt)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt History')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : receipts.isEmpty
          ? const Center(
              child: Text(
                'No receipts uploaded yet.',
                style: TextStyle(fontSize: 20),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadReceipts,
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: receipts.length,
                itemBuilder: (context, index) {
                  return receiptCard(receipts[index]);
                },
              ),
            ),
    );
  }
}
