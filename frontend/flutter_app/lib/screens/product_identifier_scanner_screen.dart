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
  final Set<String> _seenPayloads = {};

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_completed) return;
    for (final barcode in capture.barcodes) {
      final identifier = ProductIdentifier.tryCreate(
        barcode.rawValue ?? '',
        format: barcode.format.name,
      );
      if (identifier != null) {
        if (!_seenPayloads.add(identifier.value)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This code was already scanned.')),
          );
          return;
        }
        await _confirmAndReturn(identifier);
        return;
      }
    }
  }

  Future<void> _confirmAndReturn(ProductIdentifier identifier) async {
    final controllers = <String, TextEditingController>{
      for (final entry in identifier.parsedFields.entries)
        if (!entry.key.endsWith('_check_digit_valid'))
          entry.key: TextEditingController(text: entry.value),
    };
    final confirmed = await showDialog<ProductIdentifier>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review scanned code'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Format: ${identifier.format}'),
                const SizedBox(height: 12),
                if (controllers.isEmpty)
                  const Text(
                    'No supported structured fields were recognized. The full code will still be kept for review.',
                  )
                else ...[
                  const Text('Recognized fields (editable; not verified)'),
                  const SizedBox(height: 8),
                  for (final entry in controllers.entries) ...[
                    TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: _fieldLabel(entry.key),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                if (identifier.parsedFields['gtin_check_digit_valid'] ==
                    'false')
                  const Text(
                    'The GTIN check digit does not match. Review the code carefully.',
                    style: TextStyle(color: Colors.orange),
                  ),
                if (identifier.unparsedData.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Unparsed content (retained)'),
                  SelectableText(identifier.unparsedData),
                ],
                const SizedBox(height: 12),
                const Text('Original decoded value (retained unchanged)'),
                SelectableText(identifier.value),
                const SizedBox(height: 8),
                const Text(
                  'A decoded code identifies data only. It does not authenticate the physical medicine.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Scan again'),
          ),
          FilledButton(
            onPressed: () {
              final fields = <String, String>{
                for (final entry in controllers.entries)
                  entry.key: entry.value.text.trim(),
              };
              final correctedFields = <String>{
                ...identifier.correctedFields,
                for (final entry in fields.entries)
                  if (entry.value != identifier.parsedFields[entry.key])
                    entry.key,
              };
              if (identifier.parsedFields.containsKey(
                'gtin_check_digit_valid',
              )) {
                fields['gtin_check_digit_valid'] =
                    identifier.parsedFields['gtin_check_digit_valid']!;
              }
              Navigator.pop(
                dialogContext,
                identifier.copyWith(
                  parsedFields: fields,
                  correctedFields: correctedFields,
                ),
              );
            },
            child: const Text('Use these details'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (!mounted) return;
    if (confirmed == null) {
      _seenPayloads.remove(identifier.value);
      return;
    }
    _completed = true;
    Navigator.of(context).pop(confirmed);
  }

  static String _fieldLabel(String key) => switch (key) {
    'gtin' => 'GTIN / product identifier',
    'contained_gtin' => 'Contained product GTIN',
    'batch_number' => 'Batch / lot number',
    'manufacturing_date' => 'Manufacturing date',
    'packaging_date' => 'Packaging date',
    'expiry_date' => 'Expiry date',
    'best_before_date' => 'Best-before date',
    'serial_number' => 'Serial number',
    'sscc' => 'Serial shipping container code',
    'product_variant' => 'Product variant',
    'count' => 'Count',
    'additional_product_id' => 'Additional product identifier',
    'customer_part_number' => 'Customer part number',
    'country_of_origin' => 'Country of origin',
    _ => key.replaceAll('_', ' ').toUpperCase(),
  };

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
    await _confirmAndReturn(result);
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
