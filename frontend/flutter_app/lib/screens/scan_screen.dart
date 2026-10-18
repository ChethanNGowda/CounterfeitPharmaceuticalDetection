import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/prediction_response.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/disclaimer_banner.dart';

class ScanScreen extends StatefulWidget {
  final StorageService storage;
  final ApiService apiService;
  final VoidCallback? onScanComplete;

  const ScanScreen({
    super.key,
    required this.storage,
    required this.apiService,
    this.onScanComplete,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _sampleIdController = TextEditingController();
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  File? _selectedImage;
  String? _imageFileName;
  int? _imageFileSize;
  int? _imageWidth;
  int? _imageHeight;

  // Real-time quality preview status calculated upon image selection
  bool _isQualityValid = true;
  String? _qualityIssue;

  bool _isAnalyzing = false;
  String? _errorMessage;
  int _analysisStep = 0; // 0..4

  // Advanced options collapsible
  bool _showAdvancedOptions = false;
  late double _threshold;
  late String _modelName;
  late String _visionMode;
  late bool _enableQwen;

  final List<String> _models = [
    'efficientnet_b0',
    'mobilenet_v3_large',
    'baseline_cnn',
    'goldformer'
  ];
  final List<String> _visionModes = ['auto', 'always', 'never'];

  @override
  void initState() {
    super.initState();
    _generateDefaultSampleId();
    _threshold = widget.storage.getThreshold();
    _modelName = widget.storage.getModelName();
    _visionMode = widget.storage.getVisionMode();
    _enableQwen = widget.storage.getEnableQwen();
  }

  @override
  void dispose() {
    _sampleIdController.dispose();
    _medicineNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generateDefaultSampleId() {
    final now = DateTime.now();
    final y = now.year.toString().substring(2);
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final suffix = now.millisecondsSinceEpoch.toString().substring(9);
    _sampleIdController.text = 'SMP-$y$m$d-$suffix';
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isAnalyzing) return;
    setState(() => _errorMessage = null);

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 95,
      );

      if (pickedFile == null) return;

      final File file = File(pickedFile.path);
      final int size = await file.length();
      final String name = pickedFile.name;

      int? width;
      int? height;
      bool valid = true;
      String? issue;

      try {
        final decodedImage = await decodeImageFromList(await file.readAsBytes());
        width = decodedImage.width;
        height = decodedImage.height;

        // Pre-flight client checks aligned with ml.config QUALITY_CONFIG (min 64x64, max 15MB)
        if (width < 64 || height < 64) {
          valid = false;
          issue = 'Image resolution ($width×$height px) is below minimum 64×64 requirement.';
        } else if (size > 15 * 1024 * 1024) {
          valid = false;
          issue = 'File size (${(size / (1024 * 1024)).toStringAsFixed(1)} MB) exceeds 15 MB limit.';
        }
      } catch (_) {}

      setState(() {
        _selectedImage = file;
        _imageFileName = name;
        _imageFileSize = size;
        _imageWidth = width;
        _imageHeight = height;
        _isQualityValid = valid;
        _qualityIssue = issue;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not acquire image: $e');
    }
  }

  void _clearImage() {
    if (_isAnalyzing) return;
    setState(() {
      _selectedImage = null;
      _imageFileName = null;
      _imageFileSize = null;
      _imageWidth = null;
      _imageHeight = null;
      _isQualityValid = true;
      _qualityIssue = null;
      _errorMessage = null;
      _analysisStep = 0;
    });
  }

  Future<void> _analyzeMedicine() async {
    if (_selectedImage == null || _isAnalyzing) return;
    if (!_isQualityValid) {
      setState(() => _errorMessage = _qualityIssue ?? 'Please fix the image quality issue before screening.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysisStep = 1;
    });

    try {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _isAnalyzing) setState(() => _analysisStep = 2);
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _isAnalyzing) setState(() => _analysisStep = 3);
      });

      final PredictionResponse result = await widget.apiService.predictImage(
        imageFile: _selectedImage!,
        model: _modelName,
        threshold: _threshold,
        visionMode: _visionMode,
        enableQwen: _enableQwen,
      );

      if (mounted) setState(() => _analysisStep = 4);

      final String currentSampleId = _sampleIdController.text.trim().isNotEmpty
          ? _sampleIdController.text.trim()
          : 'SMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final String? currentMedicine = _medicineNameController.text.trim().isNotEmpty
          ? _medicineNameController.text.trim()
          : null;
      final String? currentNotes = _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null;

      final historyItem = ScanHistoryItem.fromPrediction(
        result,
        sampleId: currentSampleId,
        medicineName: currentMedicine,
        notes: currentNotes,
        imagePath: _selectedImage?.path,
        fileName: _imageFileName,
      );
      await widget.storage.addScanHistoryItem(historyItem);

      widget.onScanComplete?.call();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            result: result,
            imageFile: _selectedImage,
            sampleId: currentSampleId,
            medicineName: currentMedicine,
            notes: currentNotes,
          ),
        ),
      );

      _generateDefaultSampleId();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisStep = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.secondaryBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.document_scanner_outlined, color: AppTheme.primaryCyan, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Scan Medicine', style: AppTheme.headingSmall()),
                Text(
                  'Multi-stage neural verification',
                  style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Image Acquisition
              _buildSectionHeader('1. IMAGE ACQUISITION', Icons.camera_alt_outlined),
              const SizedBox(height: 8),
              _buildImageAcquisitionCard(),

              const SizedBox(height: 18),

              // Section 2: Image Quality Assessment
              _buildSectionHeader('2. OPTICAL QUALITY GATE', Icons.high_quality_outlined),
              const SizedBox(height: 8),
              _buildQualityAssessmentCard(),

              const SizedBox(height: 18),

              // Section 3: Sample Specification & Identification
              _buildSectionHeader('3. SAMPLE SPECIFICATION', Icons.assignment_outlined),
              const SizedBox(height: 8),
              _buildSampleMetadataCard(),

              const SizedBox(height: 18),

              // Section 4: Screening Options (Advanced)
              _buildSectionHeader('4. SCREENING PARAMETERS', Icons.tune_outlined),
              const SizedBox(height: 8),
              _buildScreeningOptionsCard(),

              const SizedBox(height: 22),

              // Error banner if any
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 16),
              ],

              // Section 5: Run Screening Action
              _buildExecuteButton(),

              if (_isAnalyzing) ...[
                const SizedBox(height: 14),
                _buildAnalysisProgressBar(),
              ],

              const SizedBox(height: 20),
              const DisclaimerBanner(compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.primaryCyan),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            color: AppTheme.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildImageAcquisitionCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedImage != null)
            _buildActiveImagePreview()
          else
            _buildEmptyCaptureArea(),
          Container(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: Text(
                      _selectedImage != null ? 'Retake' : 'Camera Capture',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: Text(
                      _selectedImage != null ? 'Replace' : 'Import Photo',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isAnalyzing ? null : _clearImage,
                    icon: const Icon(Icons.close, color: AppTheme.error, size: 18),
                    tooltip: 'Remove Image',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCaptureArea() {
    return InkWell(
      onTap: () => _pickImage(ImageSource.camera),
      child: Container(
        height: 180,
        color: AppTheme.secondaryBackground,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.elevatedCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(
                Icons.center_focus_strong_outlined,
                size: 26,
                color: AppTheme.primaryCyan,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No Sample Photo Loaded',
              style: AppTheme.headingSmall(),
            ),
            const SizedBox(height: 4),
            Text(
              'Align tablet on a clean, solid, matte background',
              style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveImagePreview() {
    final String sizeStr = _imageFileSize != null
        ? '${(_imageFileSize! / 1024).toStringAsFixed(1)} KB'
        : '';
    final String dimStr = (_imageWidth != null && _imageHeight != null)
        ? '$_imageWidth×$_imageHeight px'
        : '';

    return Column(
      children: [
        Stack(
          children: [
            Image.file(
              _selectedImage!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              bottom: 8,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isQualityValid ? AppTheme.primaryCyan : AppTheme.error,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isQualityValid ? Icons.check_circle : Icons.warning_amber_rounded,
                      size: 12,
                      color: _isQualityValid ? AppTheme.primaryCyan : AppTheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isQualityValid ? 'OPTICAL INPUT READY' : 'QUALITY WARNING',
                      style: TextStyle(
                        color: _isQualityValid ? AppTheme.primaryCyan : AppTheme.error,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: AppTheme.secondaryBackground,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _imageFileName ?? 'sample.jpg',
                  style: AppTheme.bodyText(fontSize: 11.5, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                [dimStr, sizeStr].where((s) => s.isNotEmpty).join(' · '),
                style: AppTheme.monoNumeric(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityAssessmentCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pre-Screening Optical Status', style: AppTheme.headingSmall()),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _selectedImage == null
                      ? AppTheme.secondaryBackground
                      : (_isQualityValid ? AppTheme.authenticBg : AppTheme.counterfeitBg),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _selectedImage == null
                        ? AppTheme.border
                        : (_isQualityValid ? AppTheme.success : AppTheme.error),
                  ),
                ),
                child: Text(
                  _selectedImage == null
                      ? 'WAITING IMAGE'
                      : (_isQualityValid ? 'PASSED PRE-CHECK' : 'RETAKE SUGGESTED'),
                  style: TextStyle(
                    color: _selectedImage == null
                        ? AppTheme.textMuted
                        : (_isQualityValid ? AppTheme.success : AppTheme.error),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _qualityRequirementRow(
            'Resolution Gate',
            _imageWidth != null ? '$_imageWidth×$_imageHeight px' : 'Pending',
            _imageWidth != null && _imageWidth! >= 64 && _imageHeight! >= 64,
            requirement: '≥ 64×64 px',
          ),
          const SizedBox(height: 6),
          _qualityRequirementRow(
            'File Size Constraint',
            _imageFileSize != null ? '${(_imageFileSize! / 1024).toStringAsFixed(0)} KB' : 'Pending',
            _imageFileSize != null && _imageFileSize! <= 15 * 1024 * 1024,
            requirement: '≤ 15 MB',
          ),
          const SizedBox(height: 6),
          _qualityRequirementRow(
            'OpenCV Sharpness & Exposure',
            'Evaluated on submit',
            true,
            requirement: 'Laplacian var ≥ 50, mean 15–245',
          ),
          if (_qualityIssue != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.counterfeitBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _qualityIssue!,
                      style: AppTheme.bodyText(color: AppTheme.error, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qualityRequirementRow(String label, String value, bool valid, {required String requirement}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              _selectedImage == null
                  ? Icons.circle_outlined
                  : (valid ? Icons.check_circle_outline : Icons.cancel_outlined),
              size: 14,
              color: _selectedImage == null
                  ? AppTheme.textMuted
                  : (valid ? AppTheme.success : AppTheme.error),
            ),
            const SizedBox(width: 6),
            Text(label, style: AppTheme.bodyText(fontSize: 12)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: AppTheme.monoNumeric(
                fontSize: 11.5,
                color: _selectedImage == null ? AppTheme.textMuted : AppTheme.textPrimary,
              ),
            ),
            Text(
              requirement,
              style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 9.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSampleMetadataCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sampleIdController,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Sample / Lot ID *',
                    hintText: 'e.g. SMP-261018-01',
                    prefixIcon: Icon(Icons.tag, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.shuffle, size: 18, color: AppTheme.primaryCyan),
                tooltip: 'Generate Fresh Sample ID',
                onPressed: _generateDefaultSampleId,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _medicineNameController,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Medicine / Brand Name (Optional)',
              hintText: 'e.g. Amoxicillin 500mg',
              prefixIcon: Icon(Icons.medication_outlined, size: 16),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Field Inspection Notes (Optional)',
              hintText: 'e.g. Suspected packaging wear, pharmacy batch inspection',
              prefixIcon: Icon(Icons.edit_note, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showAdvancedOptions = !_showAdvancedOptions),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 16, color: AppTheme.primaryCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pipeline Parameters', style: AppTheme.headingSmall()),
                        Text(
                          'Model: $_modelName · Threshold: ${(_threshold * 100).toInt()}% · Vision: $_visionMode',
                          style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showAdvancedOptions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvancedOptions) ...[
            Container(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Primary Classifier Model', style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11.5)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _models.contains(_modelName) ? _modelName : _models.first,
                    dropdownColor: AppTheme.elevatedCard,
                    items: _models.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          m == 'efficientnet_b0' ? '$m (Production Fine-Tuned)' : m,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _modelName = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Confidence Threshold', style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11.5)),
                      Text(
                        '${(_threshold * 100).toInt()}%',
                        style: AppTheme.monoNumeric(color: AppTheme.primaryCyan, fontSize: 13),
                      ),
                    ],
                  ),
                  Slider(
                    value: _threshold,
                    min: 0.50,
                    max: 0.95,
                    divisions: 9,
                    onChanged: (v) => setState(() => _threshold = v),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Enable Secondary Qwen3-VL Review', style: AppTheme.headingSmall()),
                    subtitle: Text(
                      'Ollama vision verification for borderline samples [70%, 90%)',
                      style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 10.5),
                    ),
                    value: _enableQwen,
                    activeThumbColor: AppTheme.primaryCyan,
                    onChanged: (val) => setState(() => _enableQwen = val),
                  ),
                  const SizedBox(height: 6),
                  Text('Vision Mode Policy', style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11.5)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _visionModes.contains(_visionMode) ? _visionMode : _visionModes.first,
                    dropdownColor: AppTheme.elevatedCard,
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('auto — conditional gating [0.70, 0.90)', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'always', child: Text('always — force secondary on all samples', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'never', child: Text('never — fast path, skip Qwen', style: TextStyle(fontSize: 11.5))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _visionMode = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.counterfeitBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SCREENING ERROR',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: AppTheme.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecuteButton() {
    final bool ready = _selectedImage != null && !_isAnalyzing && _isQualityValid;

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: ready ? _analyzeMedicine : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryCyan,
          disabledBackgroundColor: AppTheme.elevatedCard,
          foregroundColor: const Color(0xFF0B1020),
          disabledForegroundColor: AppTheme.textMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isAnalyzing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B1020)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'SCREENING IN PROGRESS...',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.biotech, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'RUN PHARMACEUTICAL SCREENING',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAnalysisProgressBar() {
    final steps = [
      '1. Transmitting Image Bytes',
      '2. OpenCV Blur & Exposure Gate',
      '3. EfficientNet-B0 Neural Inference',
      '4. Multi-Model Safety Synthesis',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PIPELINE EXECUTION PROGRESS ($_analysisStep/4)',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: AppTheme.primaryCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryCyan),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_analysisStep / 4).clamp(0.1, 1.0),
            backgroundColor: AppTheme.elevatedCard,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryCyan),
            minHeight: 4,
          ),
          const SizedBox(height: 8),
          Text(
            _analysisStep > 0 && _analysisStep <= steps.length
                ? steps[_analysisStep - 1]
                : 'Processing...',
            style: AppTheme.bodyText(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
