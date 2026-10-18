class HealthResponse {
  final String status;
  final String version;
  final String? device;
  final String? defaultModel;
  final List<String> availableModels;
  final String? secondaryAiModel;
  final String? secondaryAiEndpoint;

  HealthResponse({
    required this.status,
    required this.version,
    this.device,
    this.defaultModel,
    this.availableModels = const [],
    this.secondaryAiModel,
    this.secondaryAiEndpoint,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    List<String> models = [];
    if (json['available_models'] is List) {
      models = (json['available_models'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (json['supported_models'] is List) {
      models = (json['supported_models'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return HealthResponse(
      status: json['status']?.toString() ?? 'unknown',
      version: json['version']?.toString() ?? '1.0.0',
      device: json['device']?.toString(),
      defaultModel: json['default_model']?.toString(),
      availableModels: models,
      secondaryAiModel: json['secondary_ai_model']?.toString(),
      secondaryAiEndpoint: json['secondary_ai_endpoint']?.toString(),
    );
  }
}
