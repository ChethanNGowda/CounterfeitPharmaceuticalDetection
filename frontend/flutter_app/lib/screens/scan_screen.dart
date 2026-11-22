import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pharma_assist/screens/guided_camera_screen.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/prediction_response.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/services/sync_service.dart';
import 'package:pharma_assist/widgets/disclaimer_banner.dart';
import 'package:pharma_assist/widgets/medicine_photo_guide.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';

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
  State<ScanScreen> createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen> {
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

  final List<String> _visionModes = ['auto', 'always', 'never'];

  @override
  void initState() {
    super.initState();
    _generateDefaultSampleId();
    _threshold = widget.storage.getThreshold();
    _modelName = AppConstants.defaultModel;
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
    _sampleIdController.text = widget.storage.peekNextSampleId();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isAnalyzing) return;
    setState(() => _errorMessage = null);

    try {
      // Keep the original pixels; compression can remove packaging detail used by the model.
      final XFile? pickedFile = source == ImageSource.camera
          ? await Navigator.of(context).push<XFile>(
              MaterialPageRoute(builder: (_) => const GuidedCameraScreen()),
            )
          : await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final size = await file.length();
      final name = pickedFile.name;
      final extension = name.split('.').last.toLowerCase();
      int? width;
      int? height;
      var valid = {'jpg', 'jpeg', 'png', 'webp', 'bmp'}.contains(extension);
      String? issue = valid
          ? null
          : 'Unsupported image type. Choose JPEG, PNG, WEBP, or BMP.';

      if (size > 15 * 1024 * 1024) {
        valid = false;
        issue = 'Image exceeds the 15 MB upload limit.';
      }
      if (size == 0) {
        valid = false;
        issue = 'Selected image file is empty.';
      } else if (size <= 15 * 1024 * 1024) {
        try {
          final decoded = await decodeImageFromList(await file.readAsBytes());
          width = decoded.width;
          height = decoded.height;
          if (valid && (width < 64 || height < 64)) {
            valid = false;
            issue =
                'Image resolution ($width x $height px) is below minimum 64 x 64 requirement.';
          }
        } catch (_) {
          valid = false;
          issue = 'This image cannot be opened. Choose a readable JPEG, PNG, WEBP, or BMP image.';
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedImage = file;
        _imageFileName = name;
        _imageFileSize = size;
        _imageWidth = width;
        _imageHeight = height;
        _isQualityValid = valid;
        _qualityIssue = issue;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
        setState(
          () => _errorMessage = source == ImageSource.camera
              ? 'Camera access was denied. Allow camera access in Android settings to take a photo.'
              : 'Photo access was denied. Choose an image using the system photo picker or allow access in Android settings.',
        );
      } else if (e.code != 'already_active' && e.code != 'user_cancelled') {
        setState(
          () => _errorMessage =
              'Could not open ${source == ImageSource.camera ? 'camera' : 'photo picker'}: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not acquire the image. Check the selected source and try again.',
        );
      }
    }
  }

  Future<void> chooseFromGallery() => _pickImage(ImageSource.gallery);
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
      setState(
        () => _errorMessage =
            _qualityIssue ??
            'Please fix the image quality issue before screening.',
      );
      return;
    }
    if (widget.storage.getOperatingMode() ==
        AppConstants.operatingModeOffline) {
      setState(
        () => _errorMessage =
            'Offline-only mode is active. Local records and reports are available, '
            'but AI screening is unavailable because no validated on-device model '
            'is installed. Choose Automatic or Backend preferred in Settings to use FastAPI.',
      );
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

      final String generatedId = widget.storage.peekNextSampleId();
      final String currentSampleId = _sampleIdController.text.trim().isNotEmpty
          ? _sampleIdController.text.trim()
          : generatedId;
      if (currentSampleId == generatedId) {
        await widget.storage.getNextSampleId();
      }
      final String? currentMedicine =
          _medicineNameController.text.trim().isNotEmpty
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
        operatingMode: widget.storage.getOperatingMode(),
        provider: AppConstants.providerBackend,
      );
      await widget.storage.addScanHistoryItem(historyItem);
      if (widget.storage.getSyncConsent() &&
          widget.storage.getOperatingMode() !=
              AppConstants.operatingModeOffline) {
        await widget.storage.enqueueSync(historyItem.id);
        await SyncService(widget.storage).processQueue();
      }

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
      if (!mounted) return;
      setState(
        () => _errorMessage = e is ApiException
            ? e.message
            : 'The screening request failed. No result was saved; try again.',
      );
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
              child: Icon(
                Icons.document_scanner_outlined,
                color: AppTheme.primaryCyan,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scan medicine',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headingSmall(),
                  ),
                  Text(
                    'One guided screening process',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyText(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SafeArea(
        child: PharmaContentFrame(
          maxWidth: 960,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Image Acquisition
                _buildSectionHeader(
                  '1. CHOOSE A PHOTO',
                  Icons.camera_alt_outlined,
                ),
                const SizedBox(height: 8),
                const MedicinePhotoGuide(),
                const SizedBox(height: 10),
                _buildImageAcquisitionCard(),
                const SizedBox(height: 8),
                Text(
                  'Camera and photo picker open only when selected. Images stay on this device unless you submit them to your configured screening server.',
                  style: AppTheme.bodyText(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 18),

                // Section 2: Image Quality Assessment
                _buildSectionHeader(
                  '2. CHECK THE PHOTO',
                  Icons.high_quality_outlined,
                ),
                const SizedBox(height: 8),
                _buildQualityAssessmentCard(),

                const SizedBox(height: 18),

                // Section 3: Sample Specification & Identification
                _buildSectionHeader(
                  '3. OPTIONAL DETAILS',
                  Icons.assignment_outlined,
                ),
                const SizedBox(height: 8),
                _buildSampleMetadataCard(),

                const SizedBox(height: 18),

                // Section 4: One combined screening pipeline
                _buildSectionHeader(
                  '4. HOW SCREENING WORKS',
                  Icons.tune_outlined,
                ),
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return PharmaSectionHeader(title: title, icon: icon);
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
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.camera),
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
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
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
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.error,
                      size: 18,
                    ),
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
        height: 200,
        color: AppTheme.secondaryBackground,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.secondaryTeal, width: 2.5),
                    left: BorderSide(color: AppTheme.secondaryTeal, width: 2.5),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.secondaryTeal, width: 2.5),
                    right: BorderSide(
                      color: AppTheme.secondaryTeal,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.secondaryTeal,
                      width: 2.5,
                    ),
                    left: BorderSide(color: AppTheme.secondaryTeal, width: 2.5),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.secondaryTeal,
                      width: 2.5,
                    ),
                    right: BorderSide(
                      color: AppTheme.secondaryTeal,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.elevatedCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Icon(
                    Icons.center_focus_strong_outlined,
                    size: 26,
                    color: AppTheme.secondaryTeal,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tap to Capture Medicine Photo',
                  style: AppTheme.headingSmall(),
                ),
                const SizedBox(height: 3),
                Text(
                  'Center tablet or blister pack on a plain, matte surface',
                  style: AppTheme.bodyText(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showImageFullScreen() {
    final imageFile = _selectedImage;
    if (imageFile == null) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.file(
                      imageFile,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Close enlarged photo',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      'Pinch to zoom • Drag to inspect details',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveImagePreview() {
    final String sizeStr = _imageFileSize != null
        ? _imageFileSize! >= 1024 * 1024
              ? '${(_imageFileSize! / (1024 * 1024)).toStringAsFixed(2)} MB'
              : '${(_imageFileSize! / 1024).toStringAsFixed(1)} KB'
        : '';
    final String dimStr = (_imageWidth != null && _imageHeight != null)
        ? '$_imageWidth x $_imageHeight px'
        : '';

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _showImageFullScreen,
              child: Container(
                width: double.infinity,
                height: 320,
                color: AppTheme.secondaryBackground,
                alignment: Alignment.center,
                child: Image.file(
                  _selectedImage!,
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
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
                    color: _isQualityValid
                        ? AppTheme.primaryCyan
                        : AppTheme.error,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isQualityValid
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      size: 12,
                      color: _isQualityValid
                          ? AppTheme.primaryCyan
                          : AppTheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isQualityValid
                          ? 'PHOTO SELECTED'
                          : 'PHOTO NEEDS ATTENTION',
                      style: TextStyle(
                        color: _isQualityValid
                            ? AppTheme.primaryCyan
                            : AppTheme.error,
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
                  style: AppTheme.bodyText(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                [dimStr, sizeStr].where((s) => s.isNotEmpty).join(' | '),
                style: AppTheme.monoNumeric(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 380 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final status = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _selectedImage == null
                      ? AppTheme.secondaryBackground
                      : (_isQualityValid
                            ? AppTheme.authenticBg
                            : AppTheme.counterfeitBg),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedImage == null
                        ? AppTheme.border
                        : (_isQualityValid ? AppTheme.success : AppTheme.error),
                  ),
                ),
                child: Text(
                  _selectedImage == null
                      ? 'Select an image'
                      : (_isQualityValid
                            ? 'Basic checks passed'
                            : 'Check photo'),
                  style: TextStyle(
                    color: _selectedImage == null
                        ? AppTheme.textMuted
                        : (_isQualityValid ? AppTheme.success : AppTheme.error),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Photo check', style: AppTheme.headingSmall()),
                        const SizedBox(height: 6),
                        status,
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Photo check', style: AppTheme.headingSmall()),
                        status,
                      ],
                    );
            },
          ),
          const SizedBox(height: 10),
          _qualityRequirementRow(
            context,
            'Image size',
            _imageWidth != null ? '$_imageWidth x $_imageHeight px' : 'Pending',
            _imageWidth != null && _imageWidth! >= 64 && _imageHeight! >= 64,
            requirement: 'Minimum 64 x 64 px',
          ),
          const SizedBox(height: 6),
          _qualityRequirementRow(
            context,
            'Upload size',
            _imageFileSize != null
                ? '${(_imageFileSize! / 1024).toStringAsFixed(0)} KB'
                : 'Pending',
            _imageFileSize != null && _imageFileSize! <= 15 * 1024 * 1024,
            requirement: 'Maximum 15 MB',
          ),
          const SizedBox(height: 6),
          _qualityRequirementRow(
            context,
            'Focus and lighting',
            _selectedImage == null
                ? 'Checked by the server'
                : 'Final check during screening',
            true,
            requirement: 'The report explains if a retake is needed',
          ),
          if (_qualityIssue != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.counterfeitBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _qualityIssue!,
                      style: AppTheme.bodyText(
                        color: AppTheme.error,
                        fontSize: 11,
                      ),
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

  Widget _qualityRequirementRow(
    BuildContext context,
    String label,
    String value,
    bool valid, {
    required String requirement,
  }) {
    final compact =
        MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
        MediaQuery.sizeOf(context).width < 400;
    final icon = Icon(
      _selectedImage == null
          ? Icons.circle_outlined
          : (valid ? Icons.check_circle_outline : Icons.cancel_outlined),
      size: 18,
      color: _selectedImage == null
          ? AppTheme.textMuted
          : (valid ? AppTheme.success : AppTheme.error),
    );
    final labelWidget = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTheme.bodyText(fontSize: 12),
    );
    final valueWidget = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTheme.monoNumeric(
        fontSize: 12,
        color: _selectedImage == null
            ? AppTheme.textMuted
            : AppTheme.textPrimary,
      ),
    );
    final requirementWidget = Text(
      requirement,
      style: AppTheme.bodyText(color: AppTheme.textMuted, fontSize: 11),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Expanded(child: labelWidget),
              const SizedBox(width: 8),
              Flexible(child: valueWidget),
            ],
          ),
          Align(alignment: Alignment.centerRight, child: requirementWidget),
        ],
      );
    }

    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(child: labelWidget),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [valueWidget, requirementWidget],
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
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Sample / Lot ID *',
                    hintText: 'e.g. PA-2026-0001',
                    prefixIcon: Icon(Icons.tag, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  size: 18,
                  color: AppTheme.primaryCyan,
                ),
                tooltip: 'Generate Fresh Sample ID',
                onPressed: _generateDefaultSampleId,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _medicineNameController,
            style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
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
            style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Field Inspection Notes (Optional)',
              hintText:
                  'e.g. Suspected packaging wear, pharmacy batch inspection',
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
            onTap: () =>
                setState(() => _showAdvancedOptions = !_showAdvancedOptions),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 16, color: AppTheme.primaryCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'One screening process',
                          style: AppTheme.headingSmall(),
                        ),
                        Text(
                          'Main model + image checks + optional AI review',
                          style: AppTheme.bodyText(
                            color: AppTheme.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showAdvancedOptions
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      'This app uses its available fine-tuned EfficientNet-B0 classifier as the main screen. Image quality and visible features are included in the same report. Optional Qwen visual review runs only when the review policy requests it.',
                      style: AppTheme.bodyText(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Authentic-Probability Cutoff',
                        style: AppTheme.bodyText(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        '${(_threshold * 100).toInt()}%',
                        style: AppTheme.monoNumeric(
                          color: AppTheme.primaryCyan,
                          fontSize: 13,
                        ),
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
                  Text(
                    'Below 50% authentic: counterfeit indication. 50% through this cutoff: manual review. Above the cutoff: authentic indication.',
                    style: AppTheme.bodyText(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Use an additional AI photo review',
                        style: AppTheme.headingSmall(),
                      ),
                      subtitle: Text(
                        'The backend can ask its vision model to review uncertain photos.',
                        style: AppTheme.bodyText(
                          color: AppTheme.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                      value: _enableQwen,
                      activeThumbColor: AppTheme.primaryCyan,
                      onChanged: (val) => setState(() => _enableQwen = val),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When should the additional review run?',
                    style: AppTheme.bodyText(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _visionModes.contains(_visionMode)
                        ? _visionMode
                        : _visionModes.first,
                    dropdownColor: AppTheme.elevatedCard,
                    items: const [
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text(
                          AppConstants.visionModeAutoLabel,
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'always',
                        child: Text(
                          AppConstants.visionModeAlwaysLabel,
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'never',
                        child: Text(
                          AppConstants.visionModeNeverLabel,
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
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
    return PharmaErrorPanel(
      title: 'Screening could not run',
      message: message,
      retryLabel: 'Retry screening',
      onRetry: _selectedImage != null && !_isAnalyzing
          ? _analyzeMedicine
          : null,
    );
  }

  Widget _buildExecuteButton() {
    final bool ready =
        _selectedImage != null && !_isAnalyzing && _isQualityValid;

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: ready ? _analyzeMedicine : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryCyan,
          disabledBackgroundColor: AppTheme.elevatedCard,
          foregroundColor: const Color(0xFF0B1020),
          disabledForegroundColor: AppTheme.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0B1020),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'SCREENING IN PROGRESS...',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.biotech, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'RUN PHARMACEUTICAL SCREENING',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
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
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: AppTheme.primaryCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppTheme.primaryCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_analysisStep / 4).clamp(0.1, 1.0),
            backgroundColor: AppTheme.elevatedCard,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryCyan),
            minHeight: 4,
          ),
          const SizedBox(height: 8),
          Text(
            _analysisStep > 0 && _analysisStep <= steps.length
                ? steps[_analysisStep - 1]
                : 'Processing...',
            style: AppTheme.bodyText(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
