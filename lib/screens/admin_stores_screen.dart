import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminStoresScreen extends StatefulWidget {
  const AdminStoresScreen({super.key});

  @override
  State<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends State<AdminStoresScreen> {
  static const Color smartCartRed = Color(0xFFD6001C);

  final nameController = TextEditingController();
  final provinceController = TextEditingController(text: 'Ontario');
  final cityController = TextEditingController();

  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    provinceController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> saveStore() async {
    if (nameController.text.trim().isEmpty ||
        provinceController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    await Supabase.instance.client.from('stores').insert({
      'name': nameController.text.trim(),
      'province': provinceController.text.trim(),
      'city': cityController.text.trim(),
    });

    setState(() {
      isSaving = false;
      nameController.clear();
      provinceController.text = 'Ontario';
      cityController.clear();
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Store saved successfully!')));
  }

  Widget buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
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
        title: const Text('Admin - Stores'),
        backgroundColor: smartCartRed,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            buildField('Store Name', nameController),
            buildField('Province', provinceController),
            buildField('City', cityController),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveStore,
                icon: const Icon(Icons.save),
                label: Text(isSaving ? 'Saving...' : 'Save Store'),
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
