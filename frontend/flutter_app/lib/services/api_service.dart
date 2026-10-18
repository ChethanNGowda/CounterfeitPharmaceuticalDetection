import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/models/health_response.dart';
import 'package:pharma_assist/models/prediction_response.dart';
import 'package:pharma_assist/services/storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? detail;

  ApiException(this.message, {this.statusCode, this.detail});

  @override
  String toString() => message;
}

class ApiService {
  final StorageService _storage;
  final http.Client _client;

  ApiService(this._storage, [http.Client? client])
    : _client = client ?? http.Client();

  String get _baseUrl => _storage.getBackendUrl();

  /// Check connectivity with the backend server via GET /health or GET /
  Future<HealthResponse> checkHealth({String? customBaseUrl}) async {
    final String targetUrl = StorageService.normalizeUrl(
      customBaseUrl ?? _baseUrl,
    );
    final Uri uri = Uri.parse('$targetUrl/health');

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return HealthResponse.fromJson(decoded);
        }
        return HealthResponse(status: 'ok', version: '1.0.0');
      } else {
        // Fallback to GET / root info endpoint if /health gives non-200
        final rootUri = Uri.parse('$targetUrl/');
        final rootResponse = await _client
            .get(rootUri)
            .timeout(const Duration(seconds: 6));
        if (rootResponse.statusCode == 200) {
          final dynamic rootDecoded = jsonDecode(rootResponse.body);
          if (rootDecoded is Map<String, dynamic>) {
            return HealthResponse.fromJson(rootDecoded);
          }
        }
        throw ApiException(
          'Server returned HTTP ${response.statusCode}: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Unable to connect to $targetUrl.\n'
        '• If using an Android Emulator, use http://10.0.2.2:8000\n'
        '• If using a physical phone, ensure phone and laptop are on the same Wi-Fi and use your laptop\'s LAN IP.\n'
        'Error: ${e.message}',
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out while reaching $targetUrl after 8 seconds.',
      );
    } on FormatException catch (e) {
      throw ApiException('Invalid response format from server: ${e.message}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error connecting to $targetUrl: $e');
    }
  }

  /// Submit a pharmaceutical tablet image for primary ML screening & secondary AI review
  Future<PredictionResponse> predictImage({
    required File imageFile,
    double? threshold,
    String? model,
    bool? enableQwen,
    String? visionMode,
  }) async {
    final String targetUrl = _baseUrl;
    final Uri uri = Uri.parse('$targetUrl/predict');

    // 1. Client-side file validation
    if (!await imageFile.exists()) {
      throw ApiException('Selected image file does not exist on device.');
    }

    final int fileSize = await imageFile.length();
    if (fileSize == 0) {
      throw ApiException('Selected image file is empty (0 bytes).');
    }

    if (fileSize > AppConstants.maxFileSizeBytes) {
      final double mb = fileSize / (1024 * 1024);
      throw ApiException(
        'Image file size (${mb.toStringAsFixed(1)} MB) exceeds the maximum allowed limit of 15 MB.',
      );
    }

    // 2. Determine mime type
    final String pathLower = imageFile.path.toLowerCase();
    MediaType mediaType = MediaType('image', 'jpeg');
    if (pathLower.endsWith('.png')) {
      mediaType = MediaType('image', 'png');
    } else if (pathLower.endsWith('.webp')) {
      mediaType = MediaType('image', 'webp');
    } else if (pathLower.endsWith('.bmp')) {
      mediaType = MediaType('image', 'bmp');
    }

    // 3. Assemble multipart request
    final request = http.MultipartRequest('POST', uri);

    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
      contentType: mediaType,
    );
    request.files.add(multipartFile);

    // Form fields
    final double effThreshold = threshold ?? _storage.getThreshold();
    final String effModel = model ?? _storage.getModelName();
    final bool effEnableQwen = enableQwen ?? _storage.getEnableQwen();
    final String effVisionMode = visionMode ?? _storage.getVisionMode();

    request.fields['threshold'] = effThreshold.toString();
    request.fields['model'] = effModel;
    request.fields['enable_qwen'] = effEnableQwen.toString();
    request.fields['vision_mode'] = effVisionMode;

    // 4. Send request with timeout
    try {
      final streamedResponse = await _client
          .send(request)
          // Qwen Vision uses the backend's 180-second Ollama timeout. Allow
          // enough time for a cold model load on CPU before calling it a failure.
          .timeout(const Duration(seconds: 240));

      final response = await http.Response.fromStream(streamedResponse);

      // Handle successful screening (200 OK)
      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic>) {
          return PredictionResponse.fromJson(body);
        }
        throw ApiException('Malformed JSON response from server.');
      }

      // Handle error responses (400, 413, 415, 500, 503)
      String errorDetail = '';
      try {
        final dynamic errBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (errBody is Map<String, dynamic> && errBody.containsKey('detail')) {
          errorDetail = errBody['detail'].toString();
        } else {
          errorDetail = response.body;
        }
      } catch (_) {
        errorDetail = response.body;
      }

      switch (response.statusCode) {
        case 413:
          throw ApiException(
            errorDetail.isNotEmpty ? errorDetail : 'Upload rejected: Image exceeds maximum allowed size of 15 MB.',
            statusCode: 413,
            detail: errorDetail,
          );
        case 415:
          throw ApiException(
            errorDetail.isNotEmpty ? errorDetail : 'Upload rejected: Unsupported image format. Allowed: JPEG, PNG, WEBP, BMP.',
            statusCode: 415,
            detail: errorDetail,
          );
        case 400:
          throw ApiException(
            errorDetail.isNotEmpty
                ? errorDetail
                : 'Bad request sent to screening API.',
            statusCode: 400,
            detail: errorDetail,
          );
        case 503:
          throw ApiException(
            errorDetail.isNotEmpty
                ? errorDetail
                : 'Model checkpoint unavailable on the backend.',
            statusCode: 503,
            detail: errorDetail,
          );
        default:
          throw ApiException(
            'Server error (${response.statusCode}): ${errorDetail.isNotEmpty ? errorDetail : response.reasonPhrase}',
            statusCode: response.statusCode,
            detail: errorDetail,
          );
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Unable to connect to backend at $targetUrl.\n'
        '• Ensure FastAPI is running (e.g. uvicorn backend.app.main:app --host 0.0.0.0 --port 8000)\n'
        '• If using a physical phone, ensure both devices are on the same Wi-Fi.\n'
        'Details: ${e.message}',
      );
    } on TimeoutException {
      throw ApiException(
        'Screening request timed out after 4 minutes. Check that the backend and its AI review service are responding, then try again.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Unexpected screening error: $e');
    }
  }

  /// Fetch model registry status from GET /models endpoint
  Future<Map<String, dynamic>> fetchModels({String? customBaseUrl}) async {
    final targetUrl = StorageService.normalizeUrl(customBaseUrl ?? _baseUrl);
    final Uri uri = Uri.parse('$targetUrl/models');
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        throw ApiException('Unexpected /models response format.');
      }
      throw ApiException(
        'GET /models failed: HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw ApiException('Cannot connect to backend for model registry.');
    } on TimeoutException {
      throw ApiException('Model registry request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching model registry: $e');
    }
  }

  /// Fetch Qwen secondary AI diagnostic status from GET /health/qwen
  Future<Map<String, dynamic>> fetchQwenStatus({String? customBaseUrl}) async {
    final targetUrl = StorageService.normalizeUrl(customBaseUrl ?? _baseUrl);
    final Uri uri = Uri.parse('$targetUrl/health/qwen');
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        throw ApiException('Unexpected /health/qwen response format.');
      }
      throw ApiException(
        'GET /health/qwen failed: HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw ApiException('Cannot connect to backend for Qwen status.');
    } on TimeoutException {
      throw ApiException('Qwen status check timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching Qwen status: $e');
    }
  }
}
