import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';

/// Side-by-side packaging photo comparison tool with interactive zoom & pan
class PhotoComparisonScreen extends StatefulWidget {
  final StorageService storage;

  const PhotoComparisonScreen({super.key, required this.storage});

  @override
  State<PhotoComparisonScreen> createState() => _PhotoComparisonScreenState();
}

class _PhotoComparisonScreenState extends State<PhotoComparisonScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _notesCtrl = TextEditingController();

  File? _imageA;
  File? _imageB;
  String _labelA = 'Reference Sample (A)';
  String _labelB = 'Suspect Sample (B)';

  final Map<String, bool> _comparisonObservations = {
    'Printing font and spacing match': false,
    'Color saturation and hue consistent': false,
    'Seal pattern and crimping match': false,
    'Batch number font and depth consistent': false,
    'Logo sharp and correctly aligned': false,
    'Security mark / hologram appears intact': false,
  };

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isA, ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (file != null) {
      setState(() {
        if (isA) {
          _imageA = File(file.path);
        } else {
          _imageB = File(file.path);
        }
      });
    }
  }

  void _chooseFromHistoryOrProfiles(bool isA) {
    final history = widget.storage.getScanHistory();
    final profiles = widget.storage.getMedicineProfiles();

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Select ${isA ? "Reference" : "Suspect"} Photo Source',
              style: Theme.of(ctx).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Capture with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(isA, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Photo Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(isA, ImageSource.gallery);
              },
            ),
            if (profiles.isNotEmpty) ...[
              const Divider(),
              Text(
                'From Saved Medicine Profiles',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...profiles
                  .where(
                    (p) =>
                        p.packagingImagePath != null &&
                        File(p.packagingImagePath!).existsSync(),
                  )
                  .take(5)
                  .map((p) {
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(p.packagingImagePath!),
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(p.medicineName),
                      subtitle: Text(p.strength),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          if (isA) {
                            _imageA = File(p.packagingImagePath!);
                            _labelA = p.medicineName;
                          } else {
                            _imageB = File(p.packagingImagePath!);
                            _labelB = p.medicineName;
                          }
                        });
                      },
                    );
                  }),
            ],
            if (history.isNotEmpty) ...[
              const Divider(),
              Text(
                'From Scan History Records',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...history
                  .where(
                    (h) =>
                        h.imagePath != null && File(h.imagePath!).existsSync(),
                  )
                  .take(5)
                  .map((h) {
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(h.imagePath!),
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(h.medicineName ?? h.sampleId),
                      subtitle: Text(h.verdictDisplay),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          if (isA) {
                            _imageA = File(h.imagePath!);
                            _labelA = h.medicineName ?? h.sampleId;
                          } else {
                            _imageB = File(h.imagePath!);
                            _labelB = h.medicineName ?? h.sampleId;
                          }
                        });
                      },
                    );
                  }),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pharmaTokens;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Packaging Photo Comparison'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Safety Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.zoom_in, size: 20, color: tokens.tealAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Visual Comparison Notice: Pinch or double-tap each panel to zoom into printing, batch stamps, and seals. Visible visual similarity does NOT prove chemical authenticity or active ingredient purity.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Side-by-Side Dual Viewport
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel A
              Expanded(
                child: _buildComparisonPanel(
                  true,
                  _imageA,
                  _labelA,
                  tokens,
                  theme,
                ),
              ),
              const SizedBox(width: 10),
              // Panel B
              Expanded(
                child: _buildComparisonPanel(
                  false,
                  _imageB,
                  _labelB,
                  tokens,
                  theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Observation Criteria Checklist
          PharmaCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Physical Packaging Observations',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ..._comparisonObservations.keys.map((key) {
                  final val = _comparisonObservations[key] ?? false;
                  return Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                      value: val,
                      activeColor: tokens.tealAccent,
                      onChanged: (newVal) {
                        setState(() {
                          _comparisonObservations[key] = newVal ?? false;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Notes
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Comparison Observations & Notes',
              hintText: 'Record noticed differences in blister pocket depth, foil thickness, font variations...',
            ),
          ),
          const SizedBox(height: 16),

          // Action
          PharmaPrimaryButton(
            label: 'Copy Comparison Summary',
            icon: Icons.copy,
            onPressed: () async {
              final observations = _comparisonObservations.entries
                  .where((e) => e.value)
                  .map((e) => '• ${e.key}')
                  .join('\n');
              final summary =
                  'PHARMAASSIST PACKAGING COMPARISON\n'
                  'Panel A: $_labelA\n'
                  'Panel B: $_labelB\n\n'
                  'Observations:\n$observations\n\n'
                  'Notes: ${_notesCtrl.text.trim()}\n\n'
                  'Disclaimer: Visual similarity does not guarantee pharmaceutical authenticity.';
              await Clipboard.setData(ClipboardData(text: summary));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Comparison summary copied to clipboard.'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildComparisonPanel(
    bool isA,
    File? file,
    String label,
    PharmaThemeTokens tokens,
    ThemeData theme,
  ) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: tokens.surfaceSubtle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.deepBlue,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _chooseFromHistoryOrProfiles(isA),
                  child: Icon(
                    Icons.add_photo_alternate,
                    size: 16,
                    color: tokens.tealAccent,
                  ),
                ),
              ],
            ),
          ),

          // Interactive Zoom Image or Placeholder
          Expanded(
            child: file != null && file.existsSync()
                ? InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  )
                : InkWell(
                    onTap: () => _chooseFromHistoryOrProfiles(isA),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 32,
                            color: tokens.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select Image ${isA ? "A" : "B"}',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
