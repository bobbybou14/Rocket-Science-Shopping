import 'package:shared_preferences/shared_preferences.dart';

import '../models/shopping_location.dart';

class LocationPreferenceService {
  static const String _cityKey = 'shopping_location_city';
  static const String _provinceKey = 'shopping_location_province';
  static const String _postalCodeKey = 'shopping_location_postal_code';
  static const String _radiusKey = 'shopping_location_radius_km';
  static const String _latitudeKey = 'shopping_location_latitude';
  static const String _longitudeKey = 'shopping_location_longitude';

  static const double defaultRadiusKm = 25;

  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static Future<ShoppingLocation?> getLocation() async {
    final city = await _preferences.getString(_cityKey) ?? '';
    final province = await _preferences.getString(_provinceKey) ?? '';

    if (city.trim().isEmpty || province.trim().isEmpty) {
      return null;
    }

    return ShoppingLocation(
      city: city,
      province: province,
      postalCode: await _preferences.getString(_postalCodeKey) ?? '',
      radiusKm: await _preferences.getDouble(_radiusKey) ?? defaultRadiusKm,
      latitude: await _preferences.getDouble(_latitudeKey),
      longitude: await _preferences.getDouble(_longitudeKey),
    );
  }

  static Future<bool> hasLocation() async {
    final location = await getLocation();
    return location?.isConfigured ?? false;
  }

  static Future<void> saveLocation(ShoppingLocation location) async {
    await Future.wait([
      _preferences.setString(_cityKey, location.city.trim()),
      _preferences.setString(
        _provinceKey,
        location.province.trim().toUpperCase(),
      ),
      _preferences.setString(
        _postalCodeKey,
        _normalizePostalCode(location.postalCode),
      ),
      _preferences.setDouble(_radiusKey, location.radiusKm),
    ]);

    if (location.latitude != null) {
      await _preferences.setDouble(_latitudeKey, location.latitude!);
    } else {
      await _preferences.remove(_latitudeKey);
    }

    if (location.longitude != null) {
      await _preferences.setDouble(_longitudeKey, location.longitude!);
    } else {
      await _preferences.remove(_longitudeKey);
    }
  }

  static Future<void> updateRadius(double radiusKm) async {
    if (radiusKm <= 0) {
      throw ArgumentError.value(
        radiusKm,
        'radiusKm',
        'The shopping radius must be greater than zero.',
      );
    }

    await _preferences.setDouble(_radiusKey, radiusKm);
  }

  static Future<void> clearLocation() async {
    await Future.wait([
      _preferences.remove(_cityKey),
      _preferences.remove(_provinceKey),
      _preferences.remove(_postalCodeKey),
      _preferences.remove(_radiusKey),
      _preferences.remove(_latitudeKey),
      _preferences.remove(_longitudeKey),
    ]);
  }

  static String _normalizePostalCode(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    if (normalized.length <= 3) {
      return normalized;
    }

    final limited = normalized.length > 6
        ? normalized.substring(0, 6)
        : normalized;

    return '${limited.substring(0, 3)} ${limited.substring(3)}';
  }
}
