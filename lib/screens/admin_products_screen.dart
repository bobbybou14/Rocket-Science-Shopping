import 'package:flutter/material.dart';

import '../core/constants/product_categories.dart';
import '../models/product.dart';
import '../service/supabase_product_service.dart';
import 'barcode_capture_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  static const Color primaryRed = Color(0xFFD6001C);

  final barcodeController = TextEditingController();
  final nameController = TextEditingController();
  final brandController = TextEditingController();
  final sizeController = TextEditingController();
  final imageUrlController = TextEditingController();

  String selectedCategory = ProductCategories.other;

  bool taxable = false;
  bool isSaving = false;

  @override
  void dispose() {
    barcodeController.dispose();
    nameController.dispose();
    brandController.dispose();
    sizeController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }

  Future<void> scanBarcode() async {
    FocusScope.of(context).unfocus();

    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeCaptureScreen()),
    );

    if (!mounted || barcode == null || barcode.trim().isEmpty) {
      return;
    }

    setState(() {
      barcodeController.text = barcode.trim();
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Barcode captured. Complete the product details.'),
        ),
      );
  }

  Future<void> saveProduct() async {
    if (barcodeController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode and product name are required')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final product = Product(
      barcode: barcodeController.text.trim(),
      name: nameController.text.trim(),
      brand: brandController.text.trim(),
      category: selectedCategory,
      size: sizeController.text.trim(),
      imageUrl: imageUrlController.text.trim(),
      taxable: taxable,
    );

    await SupabaseProductService.saveProduct(product);

    if (!mounted) return;

    setState(() {
      isSaving = false;
      barcodeController.clear();
      nameController.clear();
      brandController.clear();
      sizeController.clear();
      imageUrlController.clear();
      selectedCategory = ProductCategories.other;
      taxable = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Product saved to Supabase')));
  }

  Widget textField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: !isSaving,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Products'),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: barcodeController,
              enabled: !isSaving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Barcode',
                hintText: 'Scan or enter UPC / EAN',
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  tooltip: 'Scan barcode',
                  onPressed: isSaving ? null : scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner, color: primaryRed),
                ),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: isSaving ? null : scanBarcode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Product Barcode'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 14),

            textField(controller: nameController, label: 'Product Name'),

            textField(controller: brandController, label: 'Brand'),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: ProductCategories.all.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        selectedCategory = value;
                      });
                    },
            ),

            const SizedBox(height: 14),

            textField(controller: sizeController, label: 'Size'),

            textField(controller: imageUrlController, label: 'Image URL'),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ontario HST applies'),
              value: taxable,
              activeThumbColor: primaryRed,
              onChanged: isSaving
                  ? null
                  : (value) {
                      setState(() {
                        taxable = value;
                      });
                    },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveProduct,
                icon: const Icon(Icons.save),
                label: Text(isSaving ? 'Saving...' : 'Save Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
