import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_assist/models/product_identifier.dart';

/// Reads a QR/barcode payload for manual review. It does not authenticate it
/// or open a URL contained in the payload.
class ProductIdentifierScannerScreen extends StatefulWidget {
  const ProductIdentifierScannerScreen({super.key});

  @override
  State<ProductIdentifierScannerScreen> createState() =>
      _ProductIdentifierScannerScreenState();
}

class _ProductIdentifierScannerScreenState
    extends State<ProductIdentifierScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.all],
  );
  bool _completed = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_completed) return;
    for (final barcode in capture.barcodes) {
      final identifier = ProductIdentifier.tryCreate(
        barcode.rawValue ?? '',
        format: barcode.format.name,
      );
      if (identifier != null) {
        _completed = true;
        Navigator.of(context).pop(identifier);
        return;
      }
    }
  }

  Future<void> _enterManually() async {
    final result = await showDialog<ProductIdentifier>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Enter product code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 2048,
                  decoration: InputDecoration(
                    labelText: 'QR or barcode value',
                    errorText: error,
                  ),
                ),
                const Text(
                  'The code will be saved for review. It is not proof that the package is genuine.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final identifier = ProductIdentifier.tryCreate(
                    controller.text,
                  );
                  if (identifier == null) {
                    setDialogState(() => error = 'Enter a valid code.');
                    return;
                  }
                  Navigator.pop(dialogContext, identifier);
                },
                child: const Text('Use code'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || result == null) return;
    _completed = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan product code'),
        actions: [
          IconButton(
            tooltip: 'Toggle flash',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission is needed to scan a code. You can still enter it manually.'
                            : 'The camera scanner is unavailable. You can enter the code manually.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 280,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Center a QR code or barcode in the frame. A decoded code identifies information only; it does not authenticate the physical medicine.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _enterManually,
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: const Text('Enter code manually'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
