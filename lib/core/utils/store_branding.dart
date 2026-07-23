import 'package:flutter/material.dart';

class StoreBranding {
  final String displayName;
  final Color primaryColor;
  final Color backgroundColor;
  final IconData icon;

  const StoreBranding({
    required this.displayName,
    required this.primaryColor,
    required this.backgroundColor,
    required this.icon,
  });

  static StoreBranding fromStoreName(String storeName) {
    final normalizedName = storeName.trim().toLowerCase();

    if (normalizedName.contains('walmart')) {
      return const StoreBranding(
        displayName: 'Walmart',
        primaryColor: Color(0xFF0071CE),
        backgroundColor: Color(0xFFEAF4FF),
        icon: Icons.shopping_cart,
      );
    }

    if (normalizedName.contains('costco')) {
      return const StoreBranding(
        displayName: 'Costco',
        primaryColor: Color(0xFFE31837),
        backgroundColor: Color(0xFFFFECEF),
        icon: Icons.warehouse,
      );
    }

    if (normalizedName.contains('food basics')) {
      return const StoreBranding(
        displayName: 'Food Basics',
        primaryColor: Color(0xFF00843D),
        backgroundColor: Color(0xFFEAF7EF),
        icon: Icons.storefront,
      );
    }

    if (normalizedName.contains('freshco')) {
      return const StoreBranding(
        displayName: 'FreshCo',
        primaryColor: Color(0xFF2E7D32),
        backgroundColor: Color(0xFFEDF7ED),
        icon: Icons.eco,
      );
    }

    if (normalizedName.contains('no frills')) {
      return const StoreBranding(
        displayName: 'No Frills',
        primaryColor: Color(0xFFFFC20E),
        backgroundColor: Color(0xFFFFF8D8),
        icon: Icons.local_grocery_store,
      );
    }

    if (normalizedName.contains('real canadian superstore') ||
        normalizedName.contains('superstore')) {
      return const StoreBranding(
        displayName: 'Real Canadian Superstore',
        primaryColor: Color(0xFFFFB81C),
        backgroundColor: Color(0xFFFFF7DD),
        icon: Icons.store,
      );
    }

    if (normalizedName.contains('metro')) {
      return const StoreBranding(
        displayName: 'Metro',
        primaryColor: Color(0xFFE2231A),
        backgroundColor: Color(0xFFFFECEA),
        icon: Icons.store_mall_directory,
      );
    }

    if (normalizedName.contains('sobeys')) {
      return const StoreBranding(
        displayName: 'Sobeys',
        primaryColor: Color(0xFF007A33),
        backgroundColor: Color(0xFFEAF6EF),
        icon: Icons.shopping_basket,
      );
    }

    if (normalizedName.contains('foodland')) {
      return const StoreBranding(
        displayName: 'Foodland',
        primaryColor: Color(0xFFCE1126),
        backgroundColor: Color(0xFFFFECEF),
        icon: Icons.local_mall,
      );
    }

    if (normalizedName.contains('giant tiger')) {
      return const StoreBranding(
        displayName: 'Giant Tiger',
        primaryColor: Color(0xFFFFD100),
        backgroundColor: Color(0xFFFFFADE),
        icon: Icons.storefront,
      );
    }

    if (normalizedName.contains('loblaws')) {
      return const StoreBranding(
        displayName: 'Loblaws',
        primaryColor: Color(0xFFE31837),
        backgroundColor: Color(0xFFFFECEF),
        icon: Icons.store,
      );
    }

    if (normalizedName.contains('zehrs')) {
      return const StoreBranding(
        displayName: 'Zehrs',
        primaryColor: Color(0xFFE31837),
        backgroundColor: Color(0xFFFFECEF),
        icon: Icons.shopping_bag,
      );
    }

    if (normalizedName.contains('independent')) {
      return const StoreBranding(
        displayName: 'Independent',
        primaryColor: Color(0xFFE31837),
        backgroundColor: Color(0xFFFFECEF),
        icon: Icons.storefront,
      );
    }

    if (normalizedName.contains('farm boy')) {
      return const StoreBranding(
        displayName: 'Farm Boy',
        primaryColor: Color(0xFF7A9A01),
        backgroundColor: Color(0xFFF2F7E5),
        icon: Icons.grass,
      );
    }

    return StoreBranding(
      displayName: storeName.trim().isEmpty
          ? 'Unknown Store'
          : storeName.trim(),
      primaryColor: Colors.grey.shade700,
      backgroundColor: Colors.grey.shade100,
      icon: Icons.store,
    );
  }
}
