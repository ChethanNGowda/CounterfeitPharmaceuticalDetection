class QualityMetrics {
  final bool isValid;
  final String? reason;
  final double blurScore;
  final double brightnessMean;
  final List<int> dimensions;
  final double? aspectRatio;
  final double? contrast;
  final String colorMode;
  final String? exposureStatus;
  final String? sharpnessStatus;
  final String? suitability;

  QualityMetrics({
    required this.isValid,
    this.reason,
    required this.blurScore,
    required this.brightnessMean,
    required this.dimensions,
    this.aspectRatio,
    this.contrast,
    this.colorMode = 'RGB',
    this.exposureStatus,
    this.sharpnessStatus,
    this.suitability,
  });

  factory QualityMetrics.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return QualityMetrics(
        isValid: true,
        blurScore: 0.0,
        brightnessMean: 0.0,
        dimensions: const [0, 0],
      );
    }
    List<int> dims = [];
    if (json['dimensions'] is List) {
      dims = (json['dimensions'] as List)
          .map((e) => (e as num?)?.toInt() ?? 0)
          .toList();
    }
    return QualityMetrics(
      isValid: json['is_valid'] == true,
      reason: json['reason']?.toString(),
      blurScore: (json['blur_score'] as num?)?.toDouble() ?? 0.0,
      brightnessMean: (json['brightness_mean'] as num?)?.toDouble() ?? 0.0,
      dimensions: dims.isNotEmpty ? dims : const [0, 0],
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble(),
      contrast: (json['contrast'] as num?)?.toDouble(),
      colorMode: json['color_mode']?.toString() ?? 'RGB',
      exposureStatus: json['exposure_status']?.toString(),
      sharpnessStatus: json['sharpness_status']?.toString(),
      suitability: json['suitability']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'is_valid': isValid,
    'reason': reason,
    'blur_score': blurScore,
    'brightness_mean': brightnessMean,
    'dimensions': dimensions,
    'aspect_ratio': aspectRatio,
    'contrast': contrast,
    'color_mode': colorMode,
    'exposure_status': exposureStatus,
    'sharpness_status': sharpnessStatus,
    'suitability': suitability,
  };
}

class QwenReviewDetails {
  final bool available;
  final String? status;
  final String assessment;
  final dynamic rawConfidence;
  final List<String> reasoning;
  final bool needsHumanVerification;
  final String? warning;
  final String? error;
  final String? imageQuality;
  final String? recommendation;
  final String? modelName;
  final String? rawText;
  final String? tabletShape;
  final String? tabletColor;
  final String? tabletSurface;
  final String? tabletMarkings;
  final String? tabletEdges;
  final List<String> observationsList;
  final List<String> concernsList;
  final String? finalExplanation;

  QwenReviewDetails({
    required this.available,
    this.status,
    this.assessment = 'UNCERTAIN',
    this.rawConfidence,
    this.reasoning = const [],
    this.needsHumanVerification = true,
    this.warning,
    this.error,
    this.imageQuality,
    this.recommendation,
    this.modelName,
    this.rawText,
    this.tabletShape,
    this.tabletColor,
    this.tabletSurface,
    this.tabletMarkings,
    this.tabletEdges,
    this.observationsList = const [],
    this.concernsList = const [],
    this.finalExplanation,
  });

  factory QwenReviewDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return QwenReviewDetails(available: false);
    }
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    return QwenReviewDetails(
      available: json['available'] == true,
      status: json['status']?.toString(),
      assessment: json['assessment']?.toString() ?? 'UNCERTAIN',
      rawConfidence: json['confidence'],
      reasoning: parseList(json['reasoning']),
      needsHumanVerification: json['needs_human_verification'] == true,
      warning: json['warning']?.toString(),
      error: json['error']?.toString(),
      imageQuality: json['image_quality']?.toString(),
      recommendation: json['recommendation']?.toString(),
      modelName: json['model_name']?.toString(),
      rawText: json['raw_text']?.toString(),
      tabletShape: json['tablet_shape']?.toString(),
      tabletColor: json['tablet_color']?.toString(),
      tabletSurface: json['tablet_surface']?.toString(),
      tabletMarkings: json['tablet_markings']?.toString(),
      tabletEdges: json['tablet_edges']?.toString(),
      observationsList: parseList(json['observations_list']),
      concernsList: parseList(json['concerns_list']),
      finalExplanation: json['final_explanation']?.toString(),
    );
  }

  String get confidenceDisplay {
    if (rawConfidence == null) return 'N/A';
    if (rawConfidence is num) {
      final double val = (rawConfidence as num).toDouble();
      if (val <= 1.0) {
        return '${(val * 100).toStringAsFixed(1)}%';
      }
      return '${val.toStringAsFixed(1)}%';
    }
    return rawConfidence.toString();
  }

  Map<String, dynamic> toJson() => {
    'available': available,
    'status': status,
    'assessment': assessment,
    'confidence': rawConfidence,
    'reasoning': reasoning,
    'needs_human_verification': needsHumanVerification,
    'warning': warning,
    'error': error,
    'image_quality': imageQuality,
    'recommendation': recommendation,
    'model_name': modelName,
    'raw_text': rawText,
    'tablet_shape': tabletShape,
    'tablet_color': tabletColor,
    'tablet_surface': tabletSurface,
    'tablet_markings': tabletMarkings,
    'tablet_edges': tabletEdges,
    'observations_list': observationsList,
    'concerns_list': concernsList,
    'final_explanation': finalExplanation,
  };
}

class VisualColorAnalysis {
  final String? dominantColor;
  final List<double>? averageRgb;
  final String? consistency;
  final String? visibleVariation;

  VisualColorAnalysis({
    this.dominantColor,
    this.averageRgb,
    this.consistency,
    this.visibleVariation,
  });

  factory VisualColorAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VisualColorAnalysis();
    List<double>? rgb;
    if (json['average_rgb'] is List) {
      rgb = (json['average_rgb'] as List)
          .map((e) => (e as num?)?.toDouble() ?? 0.0)
          .toList();
    }
    return VisualColorAnalysis(
      dominantColor: json['dominant_color']?.toString(),
      averageRgb: rgb,
      consistency: json['consistency']?.toString(),
      visibleVariation: json['visible_variation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'dominant_color': dominantColor,
    'average_rgb': averageRgb,
    'consistency': consistency,
    'visible_variation': visibleVariation,
  };
}

class VisualShapeAnalysis {
  final String? objectDetected;
  final String? shapeType;
  final double? circularity;
  final double? aspectRatio;
  final String? symmetry;

  VisualShapeAnalysis({
    this.objectDetected,
    this.shapeType,
    this.circularity,
    this.aspectRatio,
    this.symmetry,
  });

  factory VisualShapeAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VisualShapeAnalysis();
    return VisualShapeAnalysis(
      objectDetected: json['object_detected']?.toString(),
      shapeType: json['shape_type']?.toString(),
      circularity: (json['circularity'] as num?)?.toDouble(),
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble(),
      symmetry: json['symmetry']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'object_detected': objectDetected,
    'shape_type': shapeType,
    'circularity': circularity,
    'aspect_ratio': aspectRatio,
    'symmetry': symmetry,
  };
}

class VisualSizeAnalysis {
  final String? boundingBox;
  final String? pixelArea;
  final double? aspectRatio;
  final String? physicalScaleNote;

  VisualSizeAnalysis({
    this.boundingBox,
    this.pixelArea,
    this.aspectRatio,
    this.physicalScaleNote,
  });

  factory VisualSizeAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VisualSizeAnalysis();
    return VisualSizeAnalysis(
      boundingBox: json['bounding_box']?.toString(),
      pixelArea: json['pixel_area']?.toString(),
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble(),
      physicalScaleNote: json['physical_scale_note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'bounding_box': boundingBox,
    'pixel_area': pixelArea,
    'aspect_ratio': aspectRatio,
    'physical_scale_note': physicalScaleNote,
  };
}

class VisualSurfaceAnalysis {
  final String? textureVariation;
  final String? surfaceUniformity;
  final String? visibleSpots;
  final String? surfaceIrregularities;

  VisualSurfaceAnalysis({
    this.textureVariation,
    this.surfaceUniformity,
    this.visibleSpots,
    this.surfaceIrregularities,
  });

  factory VisualSurfaceAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VisualSurfaceAnalysis();
    return VisualSurfaceAnalysis(
      textureVariation: json['texture_variation']?.toString(),
      surfaceUniformity: json['surface_uniformity']?.toString(),
      visibleSpots: json['visible_spots']?.toString(),
      surfaceIrregularities: json['surface_irregularities']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'texture_variation': textureVariation,
    'surface_uniformity': surfaceUniformity,
    'visible_spots': visibleSpots,
    'surface_irregularities': surfaceIrregularities,
  };
}

class VisualMarkingsAnalysis {
  final String? markingsVisible;
  final String? imprintType;
  final String? textRecognition;
  final String? legibility;

  VisualMarkingsAnalysis({
    this.markingsVisible,
    this.imprintType,
    this.textRecognition,
    this.legibility,
  });

  factory VisualMarkingsAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VisualMarkingsAnalysis();
    return VisualMarkingsAnalysis(
      markingsVisible: json['markings_visible']?.toString(),
      imprintType: json['imprint_type']?.toString(),
      textRecognition: json['text_recognition']?.toString(),
      legibility: json['legibility']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'markings_visible': markingsVisible,
    'imprint_type': imprintType,
    'text_recognition': textRecognition,
    'legibility': legibility,
  };
}

class VisualEdgeAnalysis {
  final String? edgeIntegrity;
  final String? cracks;
  final String? chipping;
  final String? contour;

  VisualEdgeAnalysis({
    this.edgeIntegrity,
    this.cracks,
    this.chipping,
    this.contour,
  });

  factory VisualEdgeAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VisualEdgeAnalysis();
    return VisualEdgeAnalysis(
      edgeIntegrity: json['edge_integrity']?.toString(),
      cracks: json['cracks']?.toString(),
      chipping: json['chipping']?.toString(),
      contour: json['contour']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'edge_integrity': edgeIntegrity,
    'cracks': cracks,
    'chipping': chipping,
    'contour': contour,
  };
}

class VisualPackagingAnalysis {
  final String? status;
  final String? packagingType;
  final String? condition;

  VisualPackagingAnalysis({
    this.status,
    this.packagingType,
    this.condition,
  });

  factory VisualPackagingAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VisualPackagingAnalysis();
    return VisualPackagingAnalysis(
      status: json['status']?.toString(),
      packagingType: json['packaging_type']?.toString(),
      condition: json['condition']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'packaging_type': packagingType,
    'condition': condition,
  };
}

class VisualAnalysisReport {
  final VisualColorAnalysis? color;
  final VisualShapeAnalysis? shape;
  final VisualSizeAnalysis? size;
  final VisualSurfaceAnalysis? surface;
  final VisualMarkingsAnalysis? markings;
  final VisualEdgeAnalysis? edges;
  final VisualPackagingAnalysis? packaging;
  final String? error;

  VisualAnalysisReport({
    this.color,
    this.shape,
    this.size,
    this.surface,
    this.markings,
    this.edges,
    this.packaging,
    this.error,
  });

  factory VisualAnalysisReport.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VisualAnalysisReport();
    return VisualAnalysisReport(
      color: json['color'] != null ? VisualColorAnalysis.fromJson(json['color']) : null,
      shape: json['shape'] != null ? VisualShapeAnalysis.fromJson(json['shape']) : null,
      size: json['size'] != null ? VisualSizeAnalysis.fromJson(json['size']) : null,
      surface: json['surface'] != null ? VisualSurfaceAnalysis.fromJson(json['surface']) : null,
      markings: json['markings'] != null ? VisualMarkingsAnalysis.fromJson(json['markings']) : null,
      edges: json['edges'] != null ? VisualEdgeAnalysis.fromJson(json['edges']) : null,
      packaging: json['packaging'] != null ? VisualPackagingAnalysis.fromJson(json['packaging']) : null,
      error: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'color': color?.toJson(),
    'shape': shape?.toJson(),
    'size': size?.toJson(),
    'surface': surface?.toJson(),
    'markings': markings?.toJson(),
    'edges': edges?.toJson(),
    'packaging': packaging?.toJson(),
    'error': error,
  };
}

class PredictionResponse {
  final String primaryModel;
  final String prediction;
  final double confidence;
  final QwenReviewDetails qwen;
  final String finalResult;
  final bool needsHumanVerification;
  final String? warning;
  final String disclaimer;
  final bool secondaryExecuted;
  final String? secondaryReason;
  final List<String> reasons;
  final bool disagreement;
  final String? primaryPrediction;
  final double? primaryConfidence;
  final VisualAnalysisReport? visualAnalysis;
  final String status;
  final String? reason;
  final String modelName;
  final double threshold;
  final double authenticProbability;
  final double counterfeitProbability;
  final QualityMetrics? quality;

  PredictionResponse({
    required this.primaryModel,
    required this.prediction,
    required this.confidence,
    required this.qwen,
    required this.finalResult,
    required this.needsHumanVerification,
    this.warning,
    required this.disclaimer,
    required this.secondaryExecuted,
    this.secondaryReason,
    this.reasons = const [],
    required this.disagreement,
    this.primaryPrediction,
    this.primaryConfidence,
    this.visualAnalysis,
    required this.status,
    this.reason,
    required this.modelName,
    required this.threshold,
    required this.authenticProbability,
    required this.counterfeitProbability,
    this.quality,
  });

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    return PredictionResponse(
      primaryModel: json['primary_model']?.toString() ?? 'efficientnet_b0',
      prediction: json['prediction']?.toString() ?? 'UNKNOWN',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      qwen: QwenReviewDetails.fromJson(json['qwen'] as Map<String, dynamic>?),
      finalResult: json['final_result']?.toString() ?? 'SUSPICIOUS / NEEDS VERIFICATION',
      needsHumanVerification: json['needs_human_verification'] == true,
      warning: json['warning']?.toString(),
      disclaimer: json['disclaimer']?.toString() ??
          'AI-assisted preliminary screening only. Does not replace laboratory testing.',
      secondaryExecuted: json['secondary_executed'] == true,
      secondaryReason: json['secondary_reason']?.toString(),
      reasons: parseList(json['reasons']),
      disagreement: json['disagreement'] == true,
      primaryPrediction: json['primary_prediction']?.toString(),
      primaryConfidence: (json['primary_confidence'] as num?)?.toDouble(),
      visualAnalysis: json['visual_analysis'] != null
          ? VisualAnalysisReport.fromJson(json['visual_analysis'] as Map<String, dynamic>?)
          : null,
      status: json['status']?.toString() ?? 'NEEDS MANUAL REVIEW',
      reason: json['reason']?.toString(),
      modelName: json['model_name']?.toString() ?? 'efficientnet_b0',
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.70,
      authenticProbability: (json['authentic_probability'] as num?)?.toDouble() ?? 0.0,
      counterfeitProbability: (json['counterfeit_probability'] as num?)?.toDouble() ?? 0.0,
      quality: json['quality'] != null
          ? QualityMetrics.fromJson(json['quality'] as Map<String, dynamic>?)
          : null,
    );
  }

  bool get imageQualityAccepted => quality?.isValid != false && prediction.toUpperCase() != 'UNKNOWN';

  bool get isLikelyAuthentic =>
      imageQualityAccepted && finalResult.toUpperCase().contains('AUTHENTIC') && !isSuspicious;

  bool get isLikelyCounterfeit =>
      imageQualityAccepted && finalResult.toUpperCase().contains('COUNTERFEIT') && !isSuspicious;

  bool get isSuspicious =>
      finalResult.toUpperCase().contains('SUSPICIOUS') ||
      finalResult.toUpperCase().contains('VERIFICATION');

  String get confidenceDisplay {
    if (!imageQualityAccepted) return 'N/A';
    final double normalized = confidence <= 1.0 ? confidence * 100.0 : confidence;
    return '${normalized.toStringAsFixed(1)}%';
  }

  String get authenticProbDisplay {
    final double normalized = authenticProbability <= 1.0
        ? authenticProbability * 100.0
        : authenticProbability;
    return '${normalized.toStringAsFixed(1)}%';
  }

  String get counterfeitProbDisplay {
    final double normalized = counterfeitProbability <= 1.0
        ? counterfeitProbability * 100.0
        : counterfeitProbability;
    return '${normalized.toStringAsFixed(1)}%';
  }

  Map<String, dynamic> toJson() => {
    'primary_model': primaryModel,
    'prediction': prediction,
    'confidence': confidence,
    'qwen': qwen.toJson(),
    'final_result': finalResult,
    'needs_human_verification': needsHumanVerification,
    'warning': warning,
    'disclaimer': disclaimer,
    'secondary_executed': secondaryExecuted,
    'secondary_reason': secondaryReason,
    'reasons': reasons,
    'disagreement': disagreement,
    'primary_prediction': primaryPrediction,
    'primary_confidence': primaryConfidence,
    'visual_analysis': visualAnalysis?.toJson(),
    'status': status,
    'reason': reason,
    'model_name': modelName,
    'threshold': threshold,
    'authentic_probability': authenticProbability,
    'counterfeit_probability': counterfeitProbability,
    'quality': quality?.toJson(),
  };
}
