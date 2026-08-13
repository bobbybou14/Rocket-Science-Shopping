class ShoppingSession {
  final String storeId;
  final String storeName;
  final DateTime startedAt;
  final String currency;
  final bool active;

  const ShoppingSession({
    this.storeId = '',
    required this.storeName,
    required this.startedAt,
    this.currency = 'CAD',
    this.active = true,
  });

  ShoppingSession copyWith({
    String? storeId,
    String? storeName,
    DateTime? startedAt,
    String? currency,
    bool? active,
  }) {
    return ShoppingSession(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      startedAt: startedAt ?? this.startedAt,
      currency: currency ?? this.currency,
      active: active ?? this.active,
    );
  }

  Duration get duration => DateTime.now().difference(startedAt);

  String get durationText {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${duration.inMinutes} min';
  }

  factory ShoppingSession.newSession({
    required String storeId,
    required String storeName,
  }) {
    return ShoppingSession(
      storeId: storeId,
      storeName: storeName,
      startedAt: DateTime.now(),
    );
  }

  factory ShoppingSession.fromMap(Map<String, dynamic> map) {
    return ShoppingSession(
      storeId: map['store_id']?.toString() ?? '',
      storeName: map['store_name']?.toString() ?? '',
      startedAt:
          DateTime.tryParse(map['started_at']?.toString() ?? '') ??
          DateTime.now(),
      currency: map['currency']?.toString() ?? 'CAD',
      active: map['active'] as bool? ?? true,
    );
  }
}
