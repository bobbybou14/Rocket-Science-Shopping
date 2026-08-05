import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/receipt.dart';
import '../models/receipt_item.dart';

class ReceiptService {
  static final SupabaseClient _client = Supabase.instance.client;

  static String _requireUserId() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('A signed-in user is required to access receipts.');
    }

    return user.id;
  }

  static Future<Receipt> saveReceipt(Receipt receipt) async {
    final userId = _requireUserId();

    final receiptData = Map<String, dynamic>.from(receipt.toMap());
    receiptData['user_id'] = userId;

    final response = await _client
        .from('receipts')
        .insert(receiptData)
        .select()
        .single();

    return Receipt.fromMap(Map<String, dynamic>.from(response));
  }

  static Future<Receipt> updateReceipt(Receipt receipt) async {
    final userId = _requireUserId();

    if (receipt.id.isEmpty) {
      throw ArgumentError('A receipt ID is required when updating a receipt.');
    }

    final receiptData = Map<String, dynamic>.from(receipt.toMap());

    // Ownership must never be reassigned during an update.
    receiptData.remove('user_id');

    final response = await _client
        .from('receipts')
        .update(receiptData)
        .eq('id', receipt.id)
        .eq('user_id', userId)
        .select()
        .maybeSingle();

    if (response == null) {
      throw StateError(
        'The receipt could not be updated because it was not found '
        'or does not belong to the signed-in user.',
      );
    }

    return Receipt.fromMap(Map<String, dynamic>.from(response));
  }

  static Future<void> saveReceiptItems(List<ReceiptItem> items) async {
    if (items.isEmpty) {
      return;
    }

    final receiptIds = items
        .map((item) => item.receiptId.trim())
        .where((receiptId) => receiptId.isNotEmpty)
        .toSet();

    if (receiptIds.isEmpty) {
      throw ArgumentError('Every receipt item must contain a receipt ID.');
    }

    if (receiptIds.length != 1) {
      throw ArgumentError(
        'Receipt items from different receipts cannot be saved '
        'in the same operation.',
      );
    }

    final receiptId = receiptIds.single;

    await _verifyReceiptOwnership(receiptId);

    final rows = items.map((item) {
      return Map<String, dynamic>.from(item.toMap());
    }).toList();

    await _client.from('receipt_items').insert(rows);
  }

  static Future<void> deleteReceipt(String receiptId) async {
    final userId = _requireUserId();
    final cleanedReceiptId = receiptId.trim();

    if (cleanedReceiptId.isEmpty) {
      throw ArgumentError('A receipt ID is required for deletion.');
    }

    await _verifyReceiptOwnership(cleanedReceiptId);

    // Delete the permanent receipt-item snapshot first so this works
    // whether or not the database foreign key uses cascade deletion.
    await _client
        .from('receipt_items')
        .delete()
        .eq('receipt_id', cleanedReceiptId);

    await _client
        .from('receipts')
        .delete()
        .eq('id', cleanedReceiptId)
        .eq('user_id', userId);
  }

  static Future<List<Receipt>> getReceipts() async {
    final userId = _requireUserId();

    final response = await _client
        .from('receipts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response.map<Receipt>((item) {
      return Receipt.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  static Future<Receipt> getReceipt(String receiptId) async {
    final userId = _requireUserId();

    if (receiptId.trim().isEmpty) {
      throw ArgumentError('A receipt ID is required.');
    }

    final response = await _client
        .from('receipts')
        .select()
        .eq('id', receiptId)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      throw StateError(
        'The receipt was not found or does not belong '
        'to the signed-in user.',
      );
    }

    return Receipt.fromMap(Map<String, dynamic>.from(response));
  }

  static Future<List<ReceiptItem>> getReceiptItems(String receiptId) async {
    if (receiptId.trim().isEmpty) {
      throw ArgumentError('A receipt ID is required.');
    }

    await _verifyReceiptOwnership(receiptId);

    final response = await _client
        .from('receipt_items')
        .select()
        .eq('receipt_id', receiptId)
        .order('created_at');

    return response.map<ReceiptItem>((item) {
      return ReceiptItem.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  static Future<void> _verifyReceiptOwnership(String receiptId) async {
    final userId = _requireUserId();
   
    debugPrint('========== VERIFY RECEIPT ==========');
    debugPrint('Looking up receipt ID: $receiptId');
    debugPrint('Current user ID: $userId');

    final receipt = await _client
        .from('receipts')
        .select('id')
        .eq('id', receiptId)
        .eq('user_id', userId)
        .maybeSingle();

    if (receipt == null) {
      throw StateError(
        'The receipt was not found or does not belong '
        'to the signed-in user.',
      );
    }
  }
}
