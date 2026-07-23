class ShoppingSession {
  final String storeName;
  final DateTime startedAt;
  final String currency;
  final bool active;

  const ShoppingSession({
    required this.storeName,
    required this.startedAt,
    this.currency = 'CAD',
    this.active = true,
  });

  ShoppingSession copyWith({
    String? storeName,
    DateTime? startedAt,
    String? currency,
    bool? active,
  }) {
    return ShoppingSession(
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

  factory ShoppingSession.newSession({required String storeName}) {
    return ShoppingSession(storeName: storeName, startedAt: DateTime.now());
  }

  Map<String, dynamic> toMap() {
    return {
      'store_name': storeName,
      'started_at': startedAt.toIso8601String(),
      'currency': currency,
      'active': active,
    };
  }

  factory ShoppingSession.fromMap(Map<String, dynamic> map) {
    return ShoppingSession(
      storeName: map['store_name'] ?? '',
      startedAt: DateTime.parse(map['started_at']),
      currency: map['currency'] ?? 'CAD',
      active: map['active'] ?? true,
    );
  }
}
