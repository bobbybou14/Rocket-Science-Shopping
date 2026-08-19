import 'package:flutter/material.dart';

import '../core/constants/product_categories.dart';
import '../models/measurement_type.dart';
import '../models/measurement_unit.dart';
import '../models/product.dart';
import '../service/product_service.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  static const Color primaryRed = Color(0xFFD6001C);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController brandController;
  late final TextEditingController sizeController;

  late String selectedCategory;
  late final TextEditingController imageUrlController;
  late final TextEditingController packageQuantityController;

  bool taxable = false;
  bool variableMeasurement = false;
  bool isSaving = false;

  late MeasurementType measurementType;
  late MeasurementUnit baseUnit;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.product.name);

    brandController = TextEditingController(text: widget.product.brand);

    selectedCategory = ProductCategories.normalize(widget.product.category);

    sizeController = TextEditingController(text: widget.product.size);

    imageUrlController = TextEditingController(text: widget.product.imageUrl);

    packageQuantityController = TextEditingController(
      text: widget.product.packageQuantity?.toString() ?? '',
    );

    taxable = widget.product.taxable;
    variableMeasurement = widget.product.variableMeasurement;
    measurementType = widget.product.measurementType;
    baseUnit = widget.product.baseUnit;

    if (!availableBaseUnits.contains(baseUnit)) {
      baseUnit = availableBaseUnits.first;
    }
  }

  List<MeasurementUnit> get availableBaseUnits {
    switch (measurementType) {
      case MeasurementType.weight:
        return const [
          MeasurementUnit.pound,
          MeasurementUnit.kilogram,
          MeasurementUnit.ounce,
          MeasurementUnit.gram,
        ];

      case MeasurementType.volume:
        return const [MeasurementUnit.litre, MeasurementUnit.millilitre];

      case MeasurementType.each:
        return const [MeasurementUnit.each, MeasurementUnit.package];
    }
  }

  String unitLabel(MeasurementUnit unit) {
    switch (unit) {
      case MeasurementUnit.each:
        return 'Each';
      case MeasurementUnit.package:
        return 'Package';
      case MeasurementUnit.gram:
        return 'Gram (g)';
      case MeasurementUnit.kilogram:
        return 'Kilogram (kg)';
      case MeasurementUnit.ounce:
        return 'Ounce (oz)';
      case MeasurementUnit.pound:
        return 'Pound (lb)';
      case MeasurementUnit.millilitre:
        return 'Millilitre (mL)';
      case MeasurementUnit.litre:
        return 'Litre (L)';
    }
  }

  void changeMeasurementType(MeasurementType? value) {
    if (value == null) {
      return;
    }

    setState(() {
      measurementType = value;
      baseUnit = availableBaseUnits.first;

      if (measurementType == MeasurementType.each) {
        variableMeasurement = false;
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    brandController.dispose();
    sizeController.dispose();
    imageUrlController.dispose();
    packageQuantityController.dispose();

    super.dispose();
  }

  Future<void> saveProduct() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() || isSaving) {
      return;
    }

    final packageQuantityText = packageQuantityController.text.trim();

    final packageQuantity = packageQuantityText.isEmpty
        ? null
        : double.tryParse(packageQuantityText);

    if (packageQuantityText.isNotEmpty &&
        (packageQuantity == null || packageQuantity <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid package quantity or leave it blank.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final updatedProduct = Product(
        barcode: widget.product.barcode,
        name: nameController.text.trim(),
        brand: brandController.text.trim(),
        category: selectedCategory,
        size: sizeController.text.trim(),
        imageUrl: imageUrlController.text.trim(),
        taxable: taxable,
        measurementType: measurementType,
        baseUnit: baseUnit,
        packageQuantity: packageQuantity,
        variableMeasurement: variableMeasurement,
      );

      final savedProduct = await ProductService.updateProduct(updatedProduct);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, savedProduct);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product could not be updated: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Widget buildField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !isSaving,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required.';
                }

                return null;
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                initialValue: widget.product.barcode,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  helperText:
                      'Barcode cannot be changed because prices and history '
                      'may already be linked to it.',
                  prefixIcon: Icon(Icons.qr_code),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              buildField(
                label: 'Product Name',
                controller: nameController,
                required: true,
              ),

              buildField(label: 'Brand', controller: brandController),

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

              const SizedBox(height: 16),

              buildField(
                label: 'Size',
                controller: sizeController,
                hintText: 'Example: 750 g, 2 L, 12 pack',
              ),

              buildField(
                label: 'Image URL',
                controller: imageUrlController,
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 4),

              DropdownButtonFormField<MeasurementType>(
                initialValue: measurementType,
                decoration: const InputDecoration(
                  labelText: 'Measurement Type',
                  border: OutlineInputBorder(),
                ),
                items: MeasurementType.values.map((type) {
                  return DropdownMenuItem<MeasurementType>(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: isSaving ? null : changeMeasurementType,
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<MeasurementUnit>(
                key: ValueKey(
                  '${measurementType.databaseValue}-${baseUnit.databaseValue}',
                ),
                initialValue: baseUnit,
                decoration: const InputDecoration(
                  labelText: 'Base Unit',
                  border: OutlineInputBorder(),
                ),
                items: availableBaseUnits.map((unit) {
                  return DropdownMenuItem<MeasurementUnit>(
                    value: unit,
                    child: Text(unitLabel(unit)),
                  );
                }).toList(),
                onChanged: isSaving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          baseUnit = value;
                        });
                      },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: packageQuantityController,
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Package Quantity',
                  hintText: variableMeasurement
                      ? 'Leave blank for variable-weight products'
                      : 'Example: 1, 750, 2',
                  suffixText: baseUnit.symbol,
                  helperText: variableMeasurement
                      ? 'For products such as meat or produce where each '
                            'package can have a different weight, leave this blank.'
                      : 'Optional fixed amount contained in the package.',
                  border: const OutlineInputBorder(),
                ),
              ),

              if (measurementType != MeasurementType.each) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Variable Measurement',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    variableMeasurement
                        ? 'The actual weight or volume can vary for each item.'
                        : 'The product has a fixed measurement.',
                  ),
                  value: variableMeasurement,
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setState(() {
                            variableMeasurement = value;

                            if (value) {
                              packageQuantityController.clear();
                            }
                          });
                        },
                ),
              ],

              const Divider(height: 32),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Ontario HST applies',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  taxable
                      ? 'This product is currently taxable.'
                      : 'This product is currently not taxable.',
                ),
                value: taxable,
                onChanged: isSaving
                    ? null
                    : (value) {
                        setState(() {
                          taxable = value;
                        });
                      },
              ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: isSaving ? null : saveProduct,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  isSaving ? 'Saving...' : 'Save Changes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
