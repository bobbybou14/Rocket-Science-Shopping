import 'package:flutter/material.dart';

import '../core/constants/product_categories.dart';
import '../models/product.dart';
import '../models/product_suggestion.dart';
import '../service/product_learning_service.dart';

class CreateProductDialog extends StatefulWidget {
  final ProductSuggestion suggestion;
  final String receiptItemName;

  const CreateProductDialog({
    super.key,
    required this.suggestion,
    required this.receiptItemName,
  });

  static Future<Product?> show({
    required BuildContext context,
    required ProductSuggestion suggestion,
    required String receiptItemName,
  }) {
    return showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return CreateProductDialog(
          suggestion: suggestion,
          receiptItemName: receiptItemName,
        );
      },
    );
  }

  @override
  State<CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<CreateProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;

  late String _selectedCategory;
  late final TextEditingController _sizeController;

  late bool _taxable;
  bool _isSaving = false;
  String? _errorMessage;

  ProductSuggestion get _originalSuggestion => widget.suggestion;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: _originalSuggestion.name);

    _brandController = TextEditingController(text: _originalSuggestion.brand);

    _selectedCategory = ProductCategories.normalize(
      _originalSuggestion.category,
    );

    _barcodeController = TextEditingController(
      text: _originalSuggestion.barcode,
    );

    _sizeController = TextEditingController(text: _originalSuggestion.size);

    _taxable = _originalSuggestion.taxable;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _sizeController.dispose();

    super.dispose();
  }

  String? _validateRequiredText(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }

    return null;
  }

  String? _validateBarcode(String? value) {
    final barcode = value?.trim() ?? '';

    if (barcode.isEmpty) {
      return 'Barcode is required.';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(barcode)) {
      return 'Barcode must contain numbers only.';
    }

    if (barcode.length < 6) {
      return 'Barcode must contain at least 6 digits.';
    }

    return null;
  }

  ProductSuggestion _buildUpdatedSuggestion() {
    return _originalSuggestion.copyWith(
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      category: _selectedCategory,
      barcode: _barcodeController.text.trim(),
      size: _sizeController.text.trim(),
      taxable: _taxable,
    );
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;

    final formIsValid = _formKey.currentState?.validate() ?? false;

    if (!formIsValid) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final updatedSuggestion = _buildUpdatedSuggestion();

    final result = await ProductLearningService.saveSuggestion(
      suggestion: updatedSuggestion,
      receiptItemName: widget.receiptItemName,
    );

    if (!mounted) return;

    if (!result.success || result.product == null) {
      setState(() {
        _isSaving = false;
        _errorMessage = result.message;
      });

      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message),
          duration: const Duration(seconds: 3),
        ),
      );

    Navigator.pop(context, result.product);
  }

  void _cancel() {
    if (_isSaving) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = _originalSuggestion.confidenceScore.clamp(0, 100);

    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        titlePadding: EdgeInsets.zero,
        contentPadding: EdgeInsets.zero,
        actionsPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: _buildHeader(theme, confidence.toDouble()),
        content: SizedBox(
          width: 620,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildReceiptSourceCard(theme),
                    const SizedBox(height: 20),
                    Text(
                      'Product details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review the suggested information before saving it to '
                      'the SmartCart catalogue.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSaving,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                        hintText: 'Example: Drumstick Caramel Dip',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        return _validateRequiredText(value, 'Product name');
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _brandController,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        hintText: 'Example: Nestlé',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
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
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value == null) return;

                              setState(() {
                                _selectedCategory = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _barcodeController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Barcode',
                        hintText: 'Enter the UPC or EAN barcode',
                        prefixIcon: Icon(Icons.qr_code),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateBarcode,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sizeController,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Package size',
                        hintText: 'Example: 500 g, 1 L, or 12 pack',
                        prefixIcon: Icon(Icons.straighten),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      value: _taxable,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                _taxable = value;
                              });
                            },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      secondary: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Taxable product'),
                      subtitle: Text(
                        _taxable
                            ? 'Sales tax normally applies to this product.'
                            : 'This product is normally tax exempt.',
                      ),
                    ),
                    if (_originalSuggestion.reasons.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSuggestionReasons(theme),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      _buildErrorMessage(theme),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      _buildErrorMessage(theme),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: _isSaving ? null : _cancel,
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProduct,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_business_outlined),
                  label: Text(_isSaving ? 'Saving Product...' : 'Save Product'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, double confidence) {
    final confidenceColor = confidence >= 85
        ? Colors.green
        : confidence >= 70
        ? Colors.orange
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Icon(Icons.add_shopping_cart),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Catalogue Product',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Add this product and teach SmartCart how to recognize it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: confidenceColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${confidence.toStringAsFixed(0)}%',
              style: TextStyle(
                color: confidenceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _isSaving ? null : _cancel,
            tooltip: 'Close',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptSourceCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.receipt_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receipt wording', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  widget.receiptItemName.trim().isEmpty
                      ? _originalSuggestion.sourceReceiptName
                      : widget.receiptItemName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionReasons(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Why SmartCart suggested this',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._originalSuggestion.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(reason)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
