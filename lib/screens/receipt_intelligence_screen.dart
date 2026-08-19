import 'package:flutter/material.dart';

import '../models/store.dart';
import '../service/price_update_service.dart';
import '../service/receipt_intelligence_service.dart';
import '../service/shopping_trip_builder_service.dart';
import '../service/shopping_trip_service.dart';
import '../service/store_service.dart';

class ReceiptIntelligenceScreen extends StatefulWidget {
  const ReceiptIntelligenceScreen({super.key});

  @override
  State<ReceiptIntelligenceScreen> createState() =>
      _ReceiptIntelligenceScreenState();
}

class _ReceiptIntelligenceScreenState extends State<ReceiptIntelligenceScreen> {
  final TextEditingController textController = TextEditingController();

  ReceiptIntelligenceResult? result;

  List<Store> stores = [];
  Store? selectedStore;

  bool isLoading = false;
  bool isSaving = false;
  bool isLoadingStores = true;

  @override
  void initState() {
    super.initState();
    loadStores();
  }

  Future<void> loadStores() async {
    try {
      final loadedStores = await StoreService.getStores();

      if (!mounted) return;

      setState(() {
        stores = loadedStores;
        isLoadingStores = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoadingStores = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load stores: $error')));
    }
  }

  Future<void> processReceipt() async {
    if (textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter or load receipt text first.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      result = null;
    });

    try {
      final processed = await ReceiptIntelligenceService.processRawText(
        textController.text.trim(),
      );

      if (!mounted) return;

      Store? detectedStore;

      final detectedStoreName = processed.parsedReceipt.storeName
          .trim()
          .toLowerCase();

      if (detectedStoreName.isNotEmpty) {
        for (final store in stores) {
          if (store.name.trim().toLowerCase() == detectedStoreName) {
            detectedStore = store;
            break;
          }
        }
      }

      setState(() {
        result = processed;
        selectedStore = detectedStore ?? selectedStore;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt processing failed: $error')),
      );
    }
  }

  Future<void> saveShoppingTrip() async {
    final intelligenceResult = result;
    final store = selectedStore;

    if (intelligenceResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Process a receipt before saving a shopping trip.'),
        ),
      );
      return;
    }

    if (store == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the store before saving.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final shoppingTrip =
          ShoppingTripBuilderService.buildFromReceiptIntelligence(
            intelligenceResult: intelligenceResult,
            storeId: store.id,
            storeName: store.name,
            city: store.city,
            province: store.province,
          );

      final savedTrip = await ShoppingTripService.saveShoppingTrip(
        shoppingTrip,
      );

      PriceUpdateResult? priceResult;
      String? priceUpdateError;

      try {
        priceResult = await PriceUpdateService.updatePricesFromShoppingTrip(
          savedTrip,
        );
      } catch (error) {
        priceUpdateError = error.toString();
      }

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      if (priceUpdateError != null) {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Shopping Trip Saved'),
              content: Text(
                'The shopping trip and ${savedTrip.items.length} items '
                'were saved successfully.\n\n'
                'The automatic price update could not be completed:\n\n'
                '$priceUpdateError',
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );

        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Shopping Trip Saved'),
            content: Text(
              'Shopping trip created successfully.\n\n'
              'Trip items saved: ${savedTrip.items.length}\n'
              'Prices added: ${priceResult?.inserted ?? 0}\n'
              'Items skipped: ${priceResult?.skipped ?? 0}',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      setState(() {
        result = null;
        selectedStore = null;
        textController.clear();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shopping trip could not be saved: $error')),
      );
    }
  }

  void loadSampleText() {
    setState(() {
      result = null;
    });

    textController.text =
        'WALMART\n'
        '2026-07-09\n'
        'MLK HOMO 2L 5.49\n'
        'WHT BRD 3.29\n'
        'BNNS 1.264 KG 2.73\n'
        'EGGS 4.99\n'
        'SUBTOTAL 16.50\n'
        'HST 0.65\n'
        'TOTAL 17.15\n'
        'VISA CARD ****1234\n'
        'AUTH 123456';
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Not found';

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Color confidenceColour(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 55) return Colors.orange;

    return Colors.red;
  }

  Widget storeSelector() {
    if (isLoadingStores) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading stores...'),
            ],
          ),
        ),
      );
    }

    if (stores.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No stores are available. Add a store through the Admin '
            'screen before saving a shopping trip.',
          ),
        ),
      );
    }

    return DropdownButtonFormField<Store>(
      key: ValueKey(selectedStore?.id ?? 'no-store'),
      initialValue: selectedStore,
      decoration: const InputDecoration(
        labelText: 'Store',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.store),
      ),
      items: stores.map((store) {
        final location = [
          store.city,
          store.province,
        ].where((value) => value.trim().isNotEmpty).join(', ');

        return DropdownMenuItem<Store>(
          value: store,
          child: Text(
            location.isEmpty ? store.name : '${store.name} — $location',
          ),
        );
      }).toList(),
      onChanged: isSaving
          ? null
          : (store) {
              setState(() {
                selectedStore = store;
              });
            },
    );
  }

  Widget resultCard() {
    final data = result;

    if (data == null) {
      return const SizedBox.shrink();
    }

    final receipt = data.parsedReceipt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Receipt Intelligence Result',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Text(
                  'Detected store: '
                  '${receipt.storeName.isEmpty ? "Not found" : receipt.storeName}',
                ),
                Text('Purchase date: ${formatDate(receipt.purchaseDate)}'),
                Text('Subtotal: \$${receipt.subtotal.toStringAsFixed(2)}'),
                Text('Tax: \$${receipt.tax.toStringAsFixed(2)}'),
                Text('Total: \$${receipt.total.toStringAsFixed(2)}'),
                const Divider(height: 28),
                Text('Items found: ${receipt.items.length}'),
                Text(
                  'High-confidence matches: '
                  '${data.highConfidenceMatches}',
                ),
                Text('Review required: ${data.reviewRequired}'),
                Text(
                  'Sensitive lines ignored: '
                  '${receipt.ignoredSensitiveLines.length}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        storeSelector(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Product Matches',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (data.productMatches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No receipt items were found.'),
                  )
                else
                  ...data.productMatches.map((match) {
                    final product = match.product;

                    final matchedName = product == null
                        ? 'No product match found'
                        : [
                            product.brand,
                            product.name,
                            product.size,
                          ].where((value) => value.trim().isNotEmpty).join(' ');

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        product == null
                            ? Icons.warning_amber
                            : match.confidenceScore >= 75
                            ? Icons.check_circle
                            : Icons.help_outline,
                        color: confidenceColour(match.confidenceScore),
                      ),
                      title: Text(match.receiptItem.name),
                      subtitle: Text(
                        '$matchedName\n'
                        'Receipt price: '
                        '\$${match.receiptItem.price.toStringAsFixed(2)}\n'
                        '${match.reason}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        '${match.confidenceScore.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: confidenceColour(match.confidenceScore),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isSaving ? null : saveShoppingTrip,
          icon: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(
            isSaving ? 'Saving Shopping Trip...' : 'Save Shopping Trip',
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Intelligence')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Receipt Intelligence',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Paste raw receipt text and Rocket Science Shopping will parse it, '
            'match products, identify items requiring review, create '
            'a shopping trip, and update verified prices.',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: textController,
            minLines: 10,
            maxLines: 18,
            enabled: !isLoading && !isSaving,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Raw receipt text',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLoading || isSaving ? null : loadSampleText,
            icon: const Icon(Icons.text_snippet),
            label: const Text('Load Sample Receipt Text'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isLoading || isSaving ? null : processReceipt,
            icon: const Icon(Icons.auto_awesome),
            label: Text(isLoading ? 'Processing...' : 'Process Receipt'),
          ),
          const SizedBox(height: 20),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else
            resultCard(),
        ],
      ),
    );
  }
}
