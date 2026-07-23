import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../service/ocr_service.dart';

class OcrTestScreen extends StatefulWidget {
  const OcrTestScreen({super.key});

  @override
  State<OcrTestScreen> createState() => _OcrTestScreenState();
}

class _OcrTestScreenState extends State<OcrTestScreen> {
  final ImagePicker picker = ImagePicker();

  String extractedText = '';
  bool isProcessing = false;

  Future<void> pickAndReadImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      isProcessing = true;
      extractedText = '';
    });

    try {
      final text = await OcrService.extractTextFromImage(image.path);

      if (!mounted) return;

      setState(() {
        extractedText = text.isEmpty ? 'No text found.' : text;
        isProcessing = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        extractedText = 'OCR failed: $error';
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR Test')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'OCR Test Screen',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose a receipt image and SmartCart will attempt to read the text.',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: isProcessing ? null : pickAndReadImage,
            icon: const Icon(Icons.document_scanner),
            label: Text(isProcessing ? 'Reading...' : 'Choose Receipt Image'),
          ),
          const SizedBox(height: 24),
          if (isProcessing)
            const Center(child: CircularProgressIndicator())
          else if (extractedText.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  extractedText,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
