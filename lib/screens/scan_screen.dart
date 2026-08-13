import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../models/measurement_unit.dart';
import '../models/product_suggestion.dart';
import '../providers/cart_provider.dart';
import '../service/price_service.dart';
import '../service/product_service.dart';
import '../service/shopping_session_service.dart';
import '../service/supabase_product_service.dart';
import '../service/upc_lookup_service.dart';
import '../widgets/create_product_dialog.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const Color smartCartRed = Color(0xFFD6001C);

  final TextEditingController barcodeController = TextEditingController();

  final MobileScannerController scannerController = MobileScannerController();

  CartItem? scannedItem;

  String message = 'Point your camera at a barcode or type one below.';

  bool hasScanned = false;
  bool isLoading = false;

  String? lastBarcode;
  DateTime? lastScanTime;

  bool isDuplicateScan(String barcode) {
    final previousTime = lastScanTime;

    if (lastBarcode != barcode || previousTime == null) {
      return false;
    }

    return DateTime.now().difference(previousTime).inMilliseconds < 1500;
  }

  Future<double?> requestVariableMeasurement({
    required String productName,
    required MeasurementUnit unit,
    required double unitPrice,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enter Package Weight'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text('\$${unitPrice.toStringAsFixed(2)} / ${unit.symbol}'),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Package weight',
                      suffixText: unit.symbol,
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      final value = double.tryParse(controller.text.trim());

                      if (value == null || value <= 0) {
                        setDialogState(() {
                          errorText = 'Enter a valid weight.';
                        });
                        return;
                      }

                      Navigator.pop(dialogContext, value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());

                    if (value == null || value <= 0) {
                      setDialogState(() {
                        errorText = 'Enter a valid weight.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, value);
                  },
                  child: const Text('Add to Cart'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    return result;
  }

  Future<void> lookupBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();

    if (cleanBarcode.isEmpty || isLoading || isDuplicateScan(cleanBarcode)) {
      return;
    }

    lastBarcode = cleanBarcode;
    lastScanTime = DateTime.now();
    scannerController.stop();

    setState(() {
      hasScanned = true;
      isLoading = true;
      scannedItem = null;
      message = 'Looking up product...\n\nBarcode:\n$cleanBarcode';
    });

    CartItem? product = await SupabaseProductService.findByBarcode(
      cleanBarcode,
    );

    product ??= await ProductService.findByBarcode(cleanBarcode);

    if (product == null) {
      product = await UpcLookupService.lookup(cleanBarcode);

      if (product != null) {
        await SupabaseProductService.saveProduct(product.product);
      }
    }

    if (!mounted) return;

    if (product == null) {
      setState(() {
        scannedItem = null;
        isLoading = false;
        message = 'Product not found.\n\nBarcode:\n$cleanBarcode';
      });

      return;
    }

    final storeId = ShoppingSessionService.currentStoreId.trim();

    final storePrice = storeId.isEmpty
        ? null
        : await PriceService.getLatestPriceForStore(
            barcode: cleanBarcode,
            storeId: storeId,
          );

    if (!mounted) return;

    double finalPrice = storePrice?.price ?? product.price;

    final isVariableWeightProduct =
        product.product.variableMeasurement &&
        product.product.isWeight &&
        storePrice != null &&
        storePrice.advertisedUnit.isWeight;

    if (isVariableWeightProduct) {
      final enteredWeight = await requestVariableMeasurement(
        productName: product.name,
        unit: storePrice.advertisedUnit,
        unitPrice: storePrice.price,
      );

      if (!mounted) return;

      if (enteredWeight == null) {
        setState(() {
          scannedItem = null;
          isLoading = false;
          message = 'Package weight entry cancelled.';
        });

        resetScanner();
        return;
      }

      finalPrice = storePrice.price * enteredWeight;
    }

    final pricedProduct = CartItem(
      product: product.product,
      price: finalPrice,
      quantity: product.quantity,
    );

    context.read<CartProvider>().addItem(pricedProduct);

    HapticFeedback.mediumImpact();

    setState(() {
      scannedItem = pricedProduct;
      isLoading = false;
      message = '';
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text('${pricedProduct.name} added to cart'),
        ),
      );

    await Future.delayed(const Duration(milliseconds: 750));

    if (!mounted) return;

    resetScanner();
  }

  Future<void> createMissingProduct() async {
    final barcode = barcodeController.text.trim();

    if (barcode.isEmpty || isLoading) {
      return;
    }

    final suggestion = ProductSuggestion(
      sourceReceiptName: barcode,
      barcode: barcode,
      name: '',
      confidenceScore: 35,
      reasons: const [
        'The barcode was scanned during a live shopping trip.',
        'Review and complete the product details before saving.',
      ],
    );

    final createdProduct = await CreateProductDialog.show(
      context: context,
      suggestion: suggestion,
      receiptItemName: barcode,
    );

    if (!mounted || createdProduct == null) {
      return;
    }

    lastBarcode = null;
    lastScanTime = null;

    await lookupBarcode(createdProduct.barcode);
  }

  void resetScanner() {
    setState(() {
      hasScanned = false;
      scannedItem = null;
      isLoading = false;
      message = 'Point your camera at a barcode or type one below.';
      barcodeController.clear();
    });
    scannerController.start();
  }

  @override
  void dispose() {
    barcodeController.dispose();
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final storeName = ShoppingSessionService.currentStoreName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Shopping'),
        backgroundColor: smartCartRed,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _shoppingSummary(
            storeName: storeName,
            itemCount: cart.itemCount,
            total: cart.total,
          ),
          Expanded(
            flex: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: scannerController,
                  onDetect: (capture) {
                    if (hasScanned || capture.barcodes.isEmpty) {
                      return;
                    }

                    final barcode = capture.barcodes.first.rawValue;

                    if (barcode == null || barcode.isEmpty) {
                      return;
                    }

                    barcodeController.text = barcode;
                    lookupBarcode(barcode);
                  },
                ),
                Center(
                  child: Container(
                    width: 270,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Place the barcode inside the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: barcodeController,
                    keyboardType: TextInputType.number,
                    onSubmitted: lookupBarcode,
                    decoration: const InputDecoration(
                      labelText: 'Enter barcode manually',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => lookupBarcode(barcodeController.text.trim()),
                      style: FilledButton.styleFrom(
                        backgroundColor: smartCartRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.search),
                      label: const Text('Lookup Barcode'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isLoading)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Finding product...',
                          style: TextStyle(fontSize: 17),
                        ),
                      ],
                    )
                  else if (scannedItem != null)
                    _successfulScan(scannedItem!)
                  else
                    Column(
                      children: [
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 17),
                        ),
                        if (hasScanned) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: createMissingProduct,
                              icon: const Icon(Icons.add_business_outlined),
                              label: const Text('Create This Product'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: resetScanner,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Skip and Scan Another Item'),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shoppingSummary({
    required String storeName,
    required int itemCount,
    required double total,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.storefront, color: smartCartRed, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName.isEmpty ? 'Current Store' : storeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$itemCount '
                  '${itemCount == 1 ? "item" : "items"}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Estimated Total',
                style: TextStyle(color: Colors.grey),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: smartCartRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _successfulScan(CartItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 42, color: Colors.green.shade700),
          const SizedBox(height: 8),
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            item.price == 0
                ? 'Price not available yet'
                : '\$${item.price.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(item.taxable ? 'Ontario HST applies' : 'No HST'),
          const SizedBox(height: 8),
          const Text(
            'Added to cart — ready for next scan',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
          ),
        ],
      ),
    );
  }
}
