import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Opens a live camera barcode scanner dialog.
/// Returns the scanned barcode string (SKU/EAN-13/UPC), or null if closed.
Future<String?> showBarcodeScannerDialog(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _BarcodeScannerSheet(),
  );
}

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  late MobileScannerController _controller;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.qrCode,
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        setState(() => _hasScanned = true);
        Navigator.of(context).pop(code);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scanWindowSize = media.size.width * 0.75;

    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Scan Product Barcode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Camera Preview & Scanning Box Overlay
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),

              // Scanning Box Guide Overlay
              Container(
                width: scanWindowSize,
                height: scanWindowSize * 0.6,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.tealAccent, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),

              // Subtitle instruction
              Positioned(
                bottom: 30,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Align barcode inside frame to scan',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Camera Controls Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: Colors.grey.shade900,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Flashlight toggle button
              IconButton(
                icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                onPressed: () => _controller.toggleTorch(),
              ),

              // Camera switch button
              IconButton(
                icon: const Icon(Icons.cameraswitch_rounded,
                    color: Colors.white),
                onPressed: () => _controller.switchCamera(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
