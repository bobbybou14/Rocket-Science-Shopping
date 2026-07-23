import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/shopping_trip.dart';
import '../core/theme/app_colors.dart';
import '../models/receipt.dart';
import '../models/store.dart';
import '../service/receipt_processor_service.dart';
import '../service/receipt_service.dart';
import '../service/store_service.dart';
import 'receipt_history_screen.dart';
import 'receipt_review_screen.dart';

class ReceiptUploadScreen extends StatefulWidget {
  const ReceiptUploadScreen({super.key});

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _receiptImage;
  Uint8List? _imageBytes;

  List<Store> stores = [];
  Store? selectedStore;
  DateTime purchaseDate = DateTime.now();

  bool loadingStores = true;
  bool isSaving = false;
  String? processingMessage;

  @override
  void initState() {
    super.initState();
    loadStores();
  }

  Future<void> loadStores() async {
    final results = await StoreService.getStores();

    if (!mounted) return;

    setState(() {
      stores = results;
      loadingStores = false;
    });
  }

  Future<void> pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    setState(() {
      _receiptImage = image;
      _imageBytes = bytes;
      processingMessage = null;
    });
  }

  Future<void> selectPurchaseDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) return;

    setState(() {
      purchaseDate = selectedDate;
    });
  }

  Future<void> uploadReceipt() async {
    if (_receiptImage == null || selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a receipt image and store before uploading.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
      processingMessage = 'Saving receipt...';
    });

    try {
      final savedReceipt = await ReceiptService.saveReceipt(
        Receipt(
          id: '',
          storeId: selectedStore!.id,
          storeName: selectedStore!.name,
          province: selectedStore!.province,
          city: selectedStore!.city,
          purchaseDate: purchaseDate,
          source: 'receipt',
          processingStatus: 'pending',
          personalDataRedacted: true,
          rawImageStored: false,
          notes: 'Receipt image selected for OCR processing.',
        ),
      );

      final draft = await ReceiptProcessorService.prepareReceipt(
        receipt: savedReceipt,
        imagePath: _receiptImage!.path,
        storeId: selectedStore!.id,
        storeName: selectedStore!.name,
        city: selectedStore!.city,
        province: selectedStore!.province,
      );

      if (!mounted) return;

      final reviewedTrip = await Navigator.push<ShoppingTrip>(
        context,
        MaterialPageRoute(builder: (_) => ReceiptReviewScreen(draft: draft)),
      );

      if (!mounted) return;

      if (reviewedTrip == null) {
        setState(() {
          isSaving = false;
          processingMessage = 'Receipt review was cancelled.';
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        _receiptImage = null;
        _imageBytes = null;
        selectedStore = null;
        purchaseDate = DateTime.now();
        isSaving = false;
        processingMessage = 'Receipt review completed.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt review completed.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        processingMessage = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Receipt save failed: $error')));
    }
  }

  void openReceiptHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptHistoryScreen()),
    );
  }

  String formattedDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Widget preview() {
    if (_imageBytes == null) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Center(
          child: Icon(Icons.receipt_long, size: 120, color: AppColors.primary),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        _imageBytes!,
        height: 260,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget processingCard() {
    if (processingMessage == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(processingMessage!, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget privacyNotice() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Privacy Notice\n\n'
          'SmartCart only stores grocery-related information.\n\n'
          'At this stage, the receipt image is not uploaded or stored. '
          'Only a receipt processing record is saved.\n\n'
          'Credit card numbers, loyalty numbers, authorization codes, and other '
          'personal payment information will never be intentionally stored.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _receiptImage != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Receipt'),
        actions: [
          IconButton(
            onPressed: openReceiptHistory,
            icon: const Icon(Icons.history),
            tooltip: 'Receipt History',
          ),
        ],
      ),
      body: loadingStores
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Receipt Upload',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the store, date, and receipt image.',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 25),
                DropdownButtonFormField<Store>(
                  initialValue: selectedStore,
                  decoration: const InputDecoration(
                    labelText: 'Store',
                    border: OutlineInputBorder(),
                  ),
                  items: stores.map((store) {
                    return DropdownMenuItem<Store>(
                      value: store,
                      child: Text('${store.name} - ${store.city}'),
                    );
                  }).toList(),
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setState(() {
                            selectedStore = value;
                          });
                        },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : selectPurchaseDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Purchase Date: ${formattedDate(purchaseDate)}'),
                ),
                const SizedBox(height: 25),
                preview(),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () => pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Take Photo'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () => pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose From Device'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: openReceiptHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('View Receipt History'),
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: !hasImage || isSaving ? null : uploadReceipt,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(isSaving ? 'Saving...' : 'Upload Receipt'),
                ),
                const SizedBox(height: 16),
                processingCard(),
                const SizedBox(height: 40),
                privacyNotice(),
              ],
            ),
    );
  }
}
