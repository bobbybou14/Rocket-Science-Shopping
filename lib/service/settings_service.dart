import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_settings.dart';

class SettingsService {
  static const String _legacyMonthlyBudgetKey = 'monthly_grocery_budget';

  static SupabaseClient get _client => Supabase.instance.client;

  static User? get _currentUser => _client.auth.currentUser;

  /// Loads settings from Supabase when available.
  ///
  /// SharedPreferences acts as an offline cache. If Supabase cannot be
  /// reached, the most recently cached value is returned instead.
  static Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final user = _currentUser;

    final localBudget = await _loadCachedBudget(
      preferences: preferences,
      userId: user?.id,
    );

    final localSettings = AppSettings(
      monthlyBudget: _validBudgetOrDefault(localBudget),
    );

    if (user == null) {
      return localSettings;
    }

    try {
      final cloudRecord = await _client
          .from('user_settings')
          .select('monthly_budget')
          .eq('user_id', user.id)
          .maybeSingle();

      if (cloudRecord == null) {
        await _saveToCloud(userId: user.id, settings: localSettings);

        await _saveToCache(
          preferences: preferences,
          userId: user.id,
          settings: localSettings,
        );

        return localSettings;
      }

      final cloudBudget = _parseBudget(cloudRecord['monthly_budget']);

      final cloudSettings = AppSettings(
        monthlyBudget: _validBudgetOrDefault(cloudBudget),
      );

      await _saveToCache(
        preferences: preferences,
        userId: user.id,
        settings: cloudSettings,
      );

      return cloudSettings;
    } catch (_) {
      // Supabase may be unavailable. The local cache remains usable.
      return localSettings;
    }
  }

  /// Saves settings locally first, then synchronizes them to Supabase.
  ///
  /// Local saving succeeds even when the device is offline. The cached
  /// value will be used until cloud synchronization becomes available.
  static Future<void> save(AppSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    final user = _currentUser;

    final sanitizedSettings = AppSettings(
      monthlyBudget: _validBudgetOrDefault(settings.monthlyBudget),
    );

    await _saveToCache(
      preferences: preferences,
      userId: user?.id,
      settings: sanitizedSettings,
    );

    if (user == null) {
      return;
    }

    try {
      await _saveToCloud(userId: user.id, settings: sanitizedSettings);
    } catch (_) {
      // The local cache has already been saved. Cloud synchronization
      // can be retried the next time settings are loaded or updated.
    }
  }

  static Future<void> updateMonthlyBudget(double monthlyBudget) async {
    final currentSettings = await load();

    await save(currentSettings.copyWith(monthlyBudget: monthlyBudget));
  }

  /// Restores the monthly budget to the application default locally
  /// and in Supabase.
  static Future<void> reset() async {
    await save(const AppSettings.defaults());
  }

  static Future<double?> _loadCachedBudget({
    required SharedPreferences preferences,
    required String? userId,
  }) async {
    if (userId == null) {
      return preferences.getDouble(_legacyMonthlyBudgetKey);
    }

    final userKey = _monthlyBudgetKeyForUser(userId);
    final userBudget = preferences.getDouble(userKey);

    if (userBudget != null) {
      return userBudget;
    }

    // Migrate the budget saved before user-scoped caching was added.
    final legacyBudget = preferences.getDouble(_legacyMonthlyBudgetKey);

    if (legacyBudget != null) {
      await preferences.setDouble(userKey, _validBudgetOrDefault(legacyBudget));

      await preferences.remove(_legacyMonthlyBudgetKey);
    }

    return legacyBudget;
  }

  static Future<void> _saveToCache({
    required SharedPreferences preferences,
    required String? userId,
    required AppSettings settings,
  }) async {
    final key = userId == null
        ? _legacyMonthlyBudgetKey
        : _monthlyBudgetKeyForUser(userId);

    await preferences.setDouble(
      key,
      _validBudgetOrDefault(settings.monthlyBudget),
    );
  }

  static Future<void> _saveToCloud({
    required String userId,
    required AppSettings settings,
  }) async {
    await _client.from('user_settings').upsert({
      'user_id': userId,
      'monthly_budget': _validBudgetOrDefault(settings.monthlyBudget),
    }, onConflict: 'user_id');
  }

  static String _monthlyBudgetKeyForUser(String userId) {
    return '${_legacyMonthlyBudgetKey}_$userId';
  }

  static double? _parseBudget(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  static double _validBudgetOrDefault(double? budget) {
    if (budget == null ||
        budget <= 0 ||
        !budget.isFinite ||
        budget >= 1000000) {
      return AppSettings.defaultMonthlyBudget;
    }

    return budget;
  }
}
