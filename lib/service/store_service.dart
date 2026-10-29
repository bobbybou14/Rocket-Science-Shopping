import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store.dart';

class StoreService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<Store>> getStores({bool includeInactive = false}) async {
    const pageSize = 1000;
    final stores = <Store>[];
    var start = 0;

    try {
      while (true) {
        var query = _client.from('stores').select();

        if (!includeInactive) {
          query = query.eq('is_active', true);
        }

        final response = await query
            .order('province')
            .order('city')
            .order('chain_name')
            .order('store_name')
            .order('id')
            .range(start, start + pageSize - 1);

        final page = response
            .map<Store>((row) => Store.fromMap(Map<String, dynamic>.from(row)))
            .toList();

        stores.addAll(page);

        if (page.isEmpty) {
          break;
        }

        start += page.length;
      }

      return stores;
    } catch (error, stackTrace) {
      debugPrint('Unable to load stores: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<List<Store>> searchStores(
    String query, {
    bool includeInactive = false,
  }) async {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return getStores(includeInactive: includeInactive);
    }

    const pageSize = 500;
    final storesById = <String, Store>{};
    var start = 0;

    // Quote the PostgREST filter value so punctuation in a store name
    // does not become part of the filter syntax.
    final escapedQuery = normalizedQuery
        .replaceAll('\\', '\\\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_')
        .replaceAll('*', r'\*')
        .replaceAll('"', '\\"');

    final searchPattern = '"%$escapedQuery%"';

    try {
      while (true) {
        var databaseQuery = _client
            .from('stores')
            .select()
            .or(
              'name.ilike.$searchPattern,'
              'chain_name.ilike.$searchPattern,'
              'store_name.ilike.$searchPattern,'
              'address.ilike.$searchPattern,'
              'city.ilike.$searchPattern,'
              'province.ilike.$searchPattern,'
              'postal_code.ilike.$searchPattern',
            );

        if (!includeInactive) {
          databaseQuery = databaseQuery.eq('is_active', true);
        }

        final response = await databaseQuery
            .order('province')
            .order('city')
            .order('chain_name')
            .order('store_name')
            .order('id')
            .range(start, start + pageSize - 1);

        final page = response
            .map<Store>((row) => Store.fromMap(Map<String, dynamic>.from(row)))
            .toList();

        if (page.isEmpty) break;

        for (final store in page) {
          storesById[store.id] = store;
        }

        start += page.length;
      }

      return storesById.values.toList();
    } catch (error, stackTrace) {
      debugPrint('Unable to search stores: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<bool> storeExists({
    required String name,
    required String city,
    required String province,
    String address = '',
    String postalCode = '',
    String? excludeStoreId,
  }) async {
    final normalizedName = name.trim();
    final normalizedCity = city.trim();
    final normalizedProvince = province.trim();
    final normalizedAddress = address.trim();
    final normalizedPostalCode = postalCode.trim();

    try {
      var query = _client
          .from('stores')
          .select('id')
          .ilike('name', normalizedName)
          .ilike('city', normalizedCity)
          .ilike('province', normalizedProvince);

      if (normalizedAddress.isNotEmpty) {
        query = query.ilike('address', normalizedAddress);
      } else if (normalizedPostalCode.isNotEmpty) {
        query = query.ilike('postal_code', normalizedPostalCode);
      }

      if (excludeStoreId != null && excludeStoreId.trim().isNotEmpty) {
        query = query.neq('id', excludeStoreId.trim());
      }

      final response = await query.limit(1);

      return response.isNotEmpty;
    } catch (error, stackTrace) {
      debugPrint('Unable to check for duplicate store: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<Store> saveStore(Store store) async {
    final name = store.name.trim();
    final chainName = store.chainName.trim();
    final storeName = store.storeName.trim();
    final address = store.address.trim();
    final city = store.city.trim();
    final province = store.province.trim();
    final postalCode = store.postalCode.trim();

    if (name.isEmpty) {
      throw ArgumentError('Store name is required.');
    }

    if (chainName.isEmpty) {
      throw ArgumentError('Chain name is required.');
    }

    if (storeName.isEmpty) {
      throw ArgumentError('Store location name is required.');
    }

    if (city.isEmpty) {
      throw ArgumentError('City is required.');
    }

    if (province.isEmpty) {
      throw ArgumentError('Province is required.');
    }

    final duplicateExists = await storeExists(
      name: name,
      city: city,
      province: province,
      address: address,
      postalCode: postalCode,
    );

    if (duplicateExists) {
      final location = address.isNotEmpty ? address : city;

      throw StateError('$storeName at $location, $province already exists.');
    }

    try {
      final response = await _client
          .from('stores')
          .insert(store.toMap())
          .select()
          .single();

      final savedStore = Store.fromMap(Map<String, dynamic>.from(response));

      debugPrint(
        'Store saved: ${savedStore.displayName}, '
        '${savedStore.locationLabel}',
      );

      return savedStore;
    } catch (error, stackTrace) {
      debugPrint('Unable to save store: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<Store> updateStore(Store store) async {
    if (store.id.trim().isEmpty) {
      throw ArgumentError('A store ID is required to update a store.');
    }

    final duplicateExists = await storeExists(
      name: store.name,
      city: store.city,
      province: store.province,
      address: store.address,
      postalCode: store.postalCode,
      excludeStoreId: store.id,
    );

    if (duplicateExists) {
      throw StateError('Another matching store location already exists.');
    }

    try {
      final values = store.toMap()..remove('id');

      final response = await _client
          .from('stores')
          .update(values)
          .eq('id', store.id.trim())
          .select()
          .single();

      final updatedStore = Store.fromMap(Map<String, dynamic>.from(response));

      debugPrint(
        'Store updated: ${updatedStore.displayName}, '
        '${updatedStore.locationLabel}',
      );

      return updatedStore;
    } catch (error, stackTrace) {
      debugPrint('Unable to update store: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<void> setStoreActive({
    required String storeId,
    required bool isActive,
  }) async {
    if (storeId.trim().isEmpty) {
      throw ArgumentError('A store ID is required.');
    }

    try {
      await _client
          .from('stores')
          .update({'is_active': isActive})
          .eq('id', storeId.trim());

      debugPrint('Store ${isActive ? 'activated' : 'deactivated'}: $storeId');
    } catch (error, stackTrace) {
      debugPrint('Unable to change store status: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
