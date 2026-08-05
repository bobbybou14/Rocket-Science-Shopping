import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/product.dart';
import '../../models/product_import_result.dart';
import '../../service/product_csv_import_service.dart';
import '../../service/supabase_product_service.dart';

class ImportCatalogueScreen extends StatefulWidget {
  const ImportCatalogueScreen({super.key});

  @override
  State<ImportCatalogueScreen> createState() => _ImportCatalogueScreenState();
}

class _ImportCatalogueScreenState extends State<ImportCatalogueScreen> {
  static const String _catalogueAssetPath =
      'assets/catalogues/smartcart_canada_seed_500.csv';

  List<Product> _parsedProducts = const [];
  List<ProductImportError> _parseErrors = const [];

  ProductImportResult? _previewResult;
  ProductImportResult? _importResult;

  bool _isLoadingFile = false;
  bool _isPreviewing = false;
  bool _isImporting = false;

  String? _errorMessage;

  bool get _isBusy {
    return _isLoadingFile || _isPreviewing || _isImporting;
  }

  bool get _hasParsedProducts {
    return _parsedProducts.isNotEmpty;
  }

  bool get _canPreview {
    return _hasParsedProducts && !_isBusy;
  }

  bool get _canImport {
    final preview = _previewResult;

    return preview != null &&
        preview.failed == 0 &&
        preview.validRows > 0 &&
        !_isBusy;
  }

  @override
  void initState() {
    super.initState();

    _loadCatalogue();
  }

  Future<void> _loadCatalogue() async {
    if (_isBusy) return;

    setState(() {
      _isLoadingFile = true;
      _errorMessage = null;
      _parsedProducts = const [];
      _parseErrors = const [];
      _previewResult = null;
      _importResult = null;
    });

    try {
      final csvText = await rootBundle.loadString(_catalogueAssetPath);

      final parseResult = ProductCsvImportService.parseCsv(csvText);

      if (!mounted) return;

      setState(() {
        _parsedProducts = parseResult.products;
        _parseErrors = parseResult.errors;
        _isLoadingFile = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingFile = false;
        _errorMessage = 'The catalogue file could not be loaded: $error';
      });
    }
  }

  Future<void> _previewImport() async {
    if (!_canPreview) return;

    setState(() {
      _isPreviewing = true;
      _errorMessage = null;
      _previewResult = null;
      _importResult = null;
    });

    try {
      final preview = await SupabaseProductService.previewProductImport(
        _parsedProducts,
      );

      if (!mounted) return;

      setState(() {
        _previewResult = preview;
        _isPreviewing = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isPreviewing = false;
        _errorMessage = 'Catalogue preview failed: $error';
      });
    }
  }

  Future<void> _confirmImport() async {
    if (!_canImport) return;

    final preview = _previewResult!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import Product Catalogue?'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This will write catalogue products to Supabase.'),
                const SizedBox(height: 16),
                _ConfirmationRow(
                  label: 'Products to add',
                  value: preview.added,
                ),
                _ConfirmationRow(
                  label: 'Products to update',
                  value: preview.updated,
                ),
                _ConfirmationRow(
                  label: 'Products to skip',
                  value: preview.skipped,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Existing products with matching barcodes may be '
                  'updated with the values from this catalogue.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Import Catalogue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _runImport();
  }

  Future<void> _runImport() async {
    if (!_canImport) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
      _importResult = null;
    });

    try {
      final result = await SupabaseProductService.importProducts(
        _parsedProducts,
      );

      if (!mounted) return;

      setState(() {
        _importResult = result;
        _isImporting = false;
      });

      final messenger = ScaffoldMessenger.of(context);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.failed == 0
                  ? 'Catalogue import completed successfully.'
                  : 'Catalogue import completed with '
                        '${result.failed} failure(s).',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isImporting = false;
        _errorMessage = 'Catalogue import failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Product Catalogue'),
        actions: [
          IconButton(
            onPressed: _isBusy ? null : _loadCatalogue,
            tooltip: 'Reload catalogue',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSourceCard(),
          const SizedBox(height: 16),
          _buildParseSummary(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorCard(),
          ],
          if (_previewResult != null) ...[
            const SizedBox(height: 16),
            _buildResultCard(
              title: 'Import Preview',
              subtitle: 'No database changes have been made.',
              result: _previewResult!,
              preview: true,
            ),
          ],
          if (_importResult != null) ...[
            const SizedBox(height: 16),
            _buildResultCard(
              title: 'Import Complete',
              subtitle: 'These results reflect the completed database import.',
              result: _importResult!,
              preview: false,
            ),
          ],
          if (_parseErrors.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildErrorsCard(title: 'CSV Parse Errors', errors: _parseErrors),
          ],
          if (_previewResult?.errors.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _buildErrorsCard(
              title: 'Preview Errors',
              errors: _previewResult!.errors,
            ),
          ],
          if (_importResult?.errors.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _buildErrorsCard(
              title: 'Import Errors',
              errors: _importResult!.errors,
            ),
          ],
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSourceCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.table_view_outlined,
                color: theme.colorScheme.onPrimaryContainer,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SmartCart Canada Seed Catalogue',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(_catalogueAssetPath),
                  SizedBox(height: 8),
                  Text(
                    'Preview the catalogue before importing it into '
                    'Supabase. Existing barcodes may be updated.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParseSummary() {
    if (_isLoadingFile) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Loading and validating catalogue...'),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CSV Validation',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ImportMetric(
                  label: 'Products parsed',
                  value: _parsedProducts.length,
                  icon: Icons.inventory_2_outlined,
                ),
                _ImportMetric(
                  label: 'Parse errors',
                  value: _parseErrors.length,
                  icon: Icons.error_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String subtitle,
    required ProductImportResult result,
    required bool preview,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  preview
                      ? Icons.visibility_outlined
                      : Icons.cloud_done_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(subtitle),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ImportMetric(
                  label: preview ? 'Would add' : 'Added',
                  value: result.added,
                  icon: Icons.add_circle_outline,
                ),
                _ImportMetric(
                  label: preview ? 'Would update' : 'Updated',
                  value: result.updated,
                  icon: Icons.update,
                ),
                _ImportMetric(
                  label: preview ? 'Would skip' : 'Skipped',
                  value: result.skipped,
                  icon: Icons.skip_next_outlined,
                ),
                _ImportMetric(
                  label: preview ? 'Would fail' : 'Failed',
                  value: result.failed,
                  icon: Icons.error_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsCard({
    required String title,
    required List<ProductImportError> errors,
  }) {
    final visibleErrors = errors.take(20).toList();

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.warning_amber_rounded),
        title: Text(
          '$title (${errors.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Expand to review the first 20 errors.'),
        children: [
          for (final error in visibleErrors)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                child: Text(
                  error.rowNumber.toString(),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              title: Text(error.message),
              subtitle: error.rowData.isEmpty
                  ? null
                  : Text(
                      error.rowData.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          if (errors.length > visibleErrors.length)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${errors.length - visibleErrors.length} additional '
                'error(s) are not displayed.',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
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
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _canPreview ? _previewImport : null,
          icon: _isPreviewing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.visibility_outlined),
          label: Text(
            _isPreviewing ? 'Comparing With Supabase...' : 'Preview Import',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _canImport ? _confirmImport : null,
          icon: _isImporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(
            _isImporting ? 'Importing Catalogue...' : 'Import Catalogue',
          ),
        ),
        if (_previewResult == null) ...[
          const SizedBox(height: 10),
          const Text(
            'Run a successful preview before importing.',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ImportMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _ImportMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 7),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  final String label;
  final int value;

  const _ConfirmationRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
