import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeCaptureScreen extends StatefulWidget {
  const BarcodeCaptureScreen({super.key});

  @override
  State<BarcodeCaptureScreen> createState() => _BarcodeCaptureScreenState();
}

class _BarcodeCaptureScreenState extends State<BarcodeCaptureScreen> {
  static const Color smartCartRed = Color(0xFFD6001C);

  final MobileScannerController scannerController = MobileScannerController();

  bool hasScanned = false;

  void captureBarcode(BarcodeCapture capture) {
    if (hasScanned || capture.barcodes.isEmpty) {
      return;
    }

    final barcode = capture.barcodes.first.rawValue?.trim();

    if (barcode == null || barcode.isEmpty) {
      return;
    }

    hasScanned = true;

    HapticFeedback.mediumImpact();

    scannerController.stop();

    Navigator.pop(context, barcode);
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product Barcode'),
        backgroundColor: smartCartRed,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: captureBarcode,
          ),
          Center(
            child: Container(
              width: 290,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Place the product barcode inside the frame.\n'
                'SmartCart will copy it into the Add Product form.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
