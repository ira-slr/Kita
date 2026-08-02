import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../inventory/inventory_provider.dart';
import 'receipt_parser.dart';
import 'review_screen.dart';

/// Entry point for the receipt scanning flow.
/// Shows source selection (camera / gallery), runs OCR, then navigates
/// to the ReviewScreen.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _pickAndScan(ImageSource source) async {
    final picker = ImagePicker();
    XFile? photo;

    try {
      photo = await picker.pickImage(
        source: source,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      if (mounted) {
        _showError('Could not access camera/gallery. Please grant permission.');
      }
      return;
    }

    if (photo == null || !mounted) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Reading receipt text…';
    });

    try {
      // --- Run ML Kit OCR ---
      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final rawText = recognizedText.text;

      if (rawText.trim().isEmpty) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError(
              'Could not read any text from the image.\n\nTry taking a clearer, well-lit photo of the receipt.');
        }
        return;
      }

      setState(() => _statusMessage = 'Matching products…');

      // --- Parse & fuzzy-match against inventory with spatial line sorting ---
      final productsAsync = ref.read(inventoryProvider);
      final existingProducts = productsAsync.valueOrNull ?? [];

      final parsedItems =
          ReceiptParser.parseRecognizedText(recognizedText, existingProducts);

      if (!mounted) return;

      if (parsedItems.isEmpty) {
        setState(() => _isProcessing = false);
        _showError(
            'No product lines could be extracted from the receipt.\n\nYou can add items manually after closing this screen.');
        return;
      }

      // --- Navigate to ReviewScreen ---
      setState(() => _isProcessing = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReviewScreen(
            imagePath: photo!.path,
            items: parsedItems,
          ),
        ),
      );

      // Pop scanner screen too once done
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('An error occurred while processing the image.\n\n$e');
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 40),
        title: const Text('Could Not Read Receipt'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        centerTitle: true,
      ),
      body: _isProcessing
          ? _buildProcessingView()
          : _buildSelectionView(colorScheme),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds…',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionView(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // Hero illustration
          Icon(
            Icons.receipt_long,
            size: 100,
            color: colorScheme.primary.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 24),

          Text(
            'Scan a Supplier Receipt',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Point your camera at a printed receipt or invoice.\n'
            'We\'ll extract the products, quantities, and prices automatically.',
            style: TextStyle(color: Colors.grey[600], height: 1.5),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Camera button
          _SourceButton(
            icon: Icons.camera_alt_rounded,
            label: 'Take a Photo',
            subtitle: 'Use your camera to photograph a receipt',
            color: colorScheme.primary,
            onTap: () => _pickAndScan(ImageSource.camera),
          ),
          const SizedBox(height: 16),

          // Gallery button
          _SourceButton(
            icon: Icons.photo_library_rounded,
            label: 'Import from Gallery',
            subtitle: 'Choose an existing photo from your phone',
            color: colorScheme.secondary,
            onTap: () => _pickAndScan(ImageSource.gallery),
          ),

          const Spacer(),
          Text(
            '💡 Tip: Make sure the receipt is flat, well-lit, and fully visible in the frame.',
            style: TextStyle(
                color: Colors.grey[500], fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
