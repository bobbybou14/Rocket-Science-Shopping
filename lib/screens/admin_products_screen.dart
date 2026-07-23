import 'package:flutter/material.dart';

import '../models/product.dart';
import '../service/supabase_product_service.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  static const Color smartCartRed = Color(0xFFD6001C);

  final barcodeController = TextEditingController();
  final nameController = TextEditingController();
  final brandController = TextEditingController();
  final categoryController = TextEditingController();
  final sizeController = TextEditingController();
  final imageUrlController = TextEditingController();

  bool taxable = false;
  bool isSaving = false;

  @override
  void dispose() {
    barcodeController.dispose();
    nameController.dispose();
    brandController.dispose();
    categoryController.dispose();
    sizeController.dispose();
    imageUrlController.dispose();
    super.dispose();
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
      category: categoryController.text.trim(),
      size: sizeController.text.trim(),
      imageUrl: imageUrlController.text.trim(),
      taxable: taxable,
    );

    await SupabaseProductService.saveProduct(product);

    setState(() {
      isSaving = false;
      barcodeController.clear();
      nameController.clear();
      brandController.clear();
      categoryController.clear();
      sizeController.clear();
      imageUrlController.clear();
      taxable = false;
    });

    if (!mounted) return;

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
        backgroundColor: smartCartRed,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            textField(
              controller: barcodeController,
              label: 'Barcode',
              keyboardType: TextInputType.number,
            ),
            textField(controller: nameController, label: 'Product Name'),
            textField(controller: brandController, label: 'Brand'),
            textField(controller: categoryController, label: 'Category'),
            textField(controller: sizeController, label: 'Size'),
            textField(controller: imageUrlController, label: 'Image URL'),
            SwitchListTile(
              title: const Text('Ontario HST applies'),
              value: taxable,
              activeThumbColor: smartCartRed,
              onChanged: (value) {
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
                  backgroundColor: smartCartRed,
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
