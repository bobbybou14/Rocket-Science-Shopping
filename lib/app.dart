import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/cart_provider.dart';
import 'screens/admin_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/product_catalog_screen.dart';
import 'screens/receipt_upload_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/store_selection_screen.dart';
import 'service/shopping_session_service.dart';

class SmartCartCanadaApp extends StatelessWidget {
  const SmartCartCanadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CartProvider>(
      create: (_) => CartProvider(),
      child: const _SmartCartApp(),
    );
  }
}

class _SmartCartApp extends StatefulWidget {
  const _SmartCartApp();

  @override
  State<_SmartCartApp> createState() => _SmartCartAppState();
}

class _SmartCartAppState extends State<_SmartCartApp> {
  int selectedIndex = 0;

  void handleStoreSelected() {
    setState(() {});
  }

  Widget buildScanScreen() {
    if (!ShoppingSessionService.hasActiveSession) {
      return StoreSelectionScreen(onStoreSelected: handleStoreSelected);
    }

    return const ScanScreen();
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const DashboardScreen(),
      buildScanScreen(),
      const ProductCatalogScreen(),
      const CartScreen(),
      const ReceiptUploadScreen(),
      const AdminScreen(),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartCart Canada',
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: IndexedStack(index: selectedIndex, children: screens),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.red,
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Receipts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
            ),
          ],
        ),
      ),
    );
  }
}
