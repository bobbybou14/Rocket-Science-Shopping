import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'admin_prices_screen.dart';
import 'admin_products_screen.dart';
import 'admin_stores_screen.dart';
import 'ocr_test_screen.dart';
import 'product_catalog_screen.dart';
import 'product_matcher_test_screen.dart';
import 'receipt_intelligence_screen.dart';
import 'receipt_parser_test_screen.dart';
import 'shopping_trip_history_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rocket Science Shopping Admin')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Database Management',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 25),

          _adminButton(
            context,
            Icons.inventory_2,
            'Add Product',
            'Create a new product',
            const AdminProductsScreen(),
          ),

          _adminButton(
            context,
            Icons.list_alt,
            'Product Catalog',
            'Browse all products',
            const ProductCatalogScreen(),
          ),

          _adminButton(
            context,
            Icons.store,
            'Stores',
            'Manage Canadian stores',
            const AdminStoresScreen(),
          ),

          _adminButton(
            context,
            Icons.attach_money,
            'Prices',
            'Add product prices',
            const AdminPricesScreen(),
          ),

          _adminButton(
            context,
            Icons.document_scanner,
            'OCR Test',
            'Test receipt text extraction',
            const OcrTestScreen(),
          ),

          _adminButton(
            context,
            Icons.receipt_long,
            'Receipt Parser Test',
            'Parse receipt text into structured data',
            const ReceiptParserTestScreen(),
          ),

          _adminButton(
            context,
            Icons.psychology,
            'Product Matcher Test',
            'Match receipt items to your Rocket Science Shopping products',
            const ProductMatcherTestScreen(),
          ),

          _adminButton(
            context,
            Icons.auto_awesome,
            'Receipt Intelligence',
            'Run the complete receipt processing pipeline',
            const ReceiptIntelligenceScreen(),
          ),

          _adminButton(
            context,
            Icons.history,
            'Shopping Trip History',
            'View saved shopping trips',
            const ShoppingTripHistoryScreen(),
          ),
        ],
      ),
    );
  }

  Widget _adminButton(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget screen,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 34),
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
      ),
    );
  }
}
