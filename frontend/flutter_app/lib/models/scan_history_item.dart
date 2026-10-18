import 'dart:convert';
import 'package:pharma_assist/models/prediction_response.dart';

class ScanHistoryItem {
  final String id;
  final String sampleId;
  final String? medicineName;
  final String? notes;
  final String? imagePath;
  final DateTime timestamp;
  final String finalResult;
  final String prediction;
  final double confidence;
  final String primaryModel;
  final bool needsHumanVerification;
  final String? fileName;
  final PredictionResponse? fullResponse;

  ScanHistoryItem({
    required this.id,
    required this.sampleId,
    this.medicineName,
    this.notes,
    this.imagePath,
    required this.timestamp,
    required this.finalResult,
    required this.prediction,
    required this.confidence,
    required this.primaryModel,
    required this.needsHumanVerification,
    this.fileName,
    this.fullResponse,
  });

  factory ScanHistoryItem.fromPrediction(
    PredictionResponse response, {
    String? sampleId,
    String? medicineName,
    String? notes,
    String? imagePath,
    String? fileName,
  }) {
    final now = DateTime.now();
    final defaultSampleId = 'SMP-${now.year}${(now.month).toString().padLeft(2, '0')}${(now.day).toString().padLeft(2, '0')}-${now.microsecondsSinceEpoch.toString().substring(10)}';
    final sid = (sampleId != null && sampleId.trim().isNotEmpty) ? sampleId.trim() : defaultSampleId;

    return ScanHistoryItem(
      id: '${now.microsecondsSinceEpoch}_$sid',
      sampleId: sid,
      medicineName: (medicineName != null && medicineName.trim().isNotEmpty) ? medicineName.trim() : null,
      notes: (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      imagePath: imagePath,
      timestamp: now,
      finalResult: response.finalResult,
      prediction: response.prediction,
      confidence: response.confidence,
      primaryModel: response.primaryModel,
      needsHumanVerification: response.needsHumanVerification,
      fileName: fileName,
      fullResponse: response,
    );
  }

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    PredictionResponse? full;
    if (json['full_response'] != null) {
      try {
        final dynamic raw = json['full_response'];
        final Map<String, dynamic> map = raw is String
            ? jsonDecode(raw) as Map<String, dynamic>
            : raw as Map<String, dynamic>;
        full = PredictionResponse.fromJson(map);
      } catch (_) {
        full = null;
      }
    }

    final String fallbackId = json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final String fallbackSampleId = json['sample_id']?.toString() ??
        'SMP-${fallbackId.length > 6 ? fallbackId.substring(fallbackId.length - 6) : fallbackId}';

    return ScanHistoryItem(
      id: fallbackId,
      sampleId: fallbackSampleId,
      medicineName: json['medicine_name']?.toString(),
      notes: json['notes']?.toString(),
      imagePath: json['image_path']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      finalResult: json['final_result']?.toString() ?? 'SUSPICIOUS / NEEDS VERIFICATION',
      prediction: json['prediction']?.toString() ?? 'UNKNOWN',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      primaryModel: json['primary_model']?.toString() ?? 'efficientnet_b0',
      needsHumanVerification: json['needs_human_verification'] == true,
      fileName: json['file_name']?.toString(),
      fullResponse: full,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sample_id': sampleId,
    'medicine_name': medicineName,
    'notes': notes,
    'image_path': imagePath,
    'timestamp': timestamp.toIso8601String(),
    'final_result': finalResult,
    'prediction': prediction,
    'confidence': confidence,
    'primary_model': primaryModel,
    'needs_human_verification': needsHumanVerification,
    'file_name': fileName,
    'full_response': fullResponse?.toJson(),
  };

  bool get isLikelyAuthentic =>
      finalResult.toUpperCase().contains('AUTHENTIC') && !isSuspicious;

  bool get isLikelyCounterfeit =>
      finalResult.toUpperCase().contains('COUNTERFEIT') && !isSuspicious;

  bool get isSuspicious =>
      finalResult.toUpperCase().contains('SUSPICIOUS') ||
      finalResult.toUpperCase().contains('VERIFICATION');

  String get modelName => primaryModel;

  String? get qwenAssessment => fullResponse?.qwen.assessment;

  PredictionResponse? toPredictionResponse() => fullResponse;
}
