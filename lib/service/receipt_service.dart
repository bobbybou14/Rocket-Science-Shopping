import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/receipt.dart';
import '../models/receipt_item.dart';

class ReceiptService {
  static final _client = Supabase.instance.client;

  static Future<Receipt> saveReceipt(Receipt receipt) async {
    final response = await _client
        .from('receipts')
        .insert(receipt.toMap())
        .select()
        .single();

    return Receipt.fromMap(response);
  }

  static Future<Receipt> updateReceipt(Receipt receipt) async {
    final response = await _client
        .from('receipts')
        .update(receipt.toMap())
        .eq('id', receipt.id)
        .select()
        .single();

    return Receipt.fromMap(response);
  }

  static Future<void> saveReceiptItems(List<ReceiptItem> items) async {
    if (items.isEmpty) return;

    final rows = items.map((item) => item.toMap()).toList();

    await _client.from('receipt_items').insert(rows);
  }

  static Future<List<Receipt>> getReceipts() async {
    final response = await _client
        .from('receipts')
        .select()
        .order('created_at', ascending: false);

    return response.map<Receipt>((item) => Receipt.fromMap(item)).toList();
  }

  static Future<List<ReceiptItem>> getReceiptItems(String receiptId) async {
    final response = await _client
        .from('receipt_items')
        .select()
        .eq('receipt_id', receiptId);

    return response
        .map<ReceiptItem>((item) => ReceiptItem.fromMap(item))
        .toList();
  }
}
