import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store.dart';

class StoreService {
  static final _client = Supabase.instance.client;

  static Future<List<Store>> getStores() async {
    try {
      final response = await _client
          .from('stores')
          .select()
          .order('name');

      return response
          .map<Store>(
            (store) => Store.fromMap(store),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveStore(Store store) async {
    try {
      await _client
          .from('stores')
          .insert(store.toMap());
    } catch (_) {
      return;
    }
  }
}