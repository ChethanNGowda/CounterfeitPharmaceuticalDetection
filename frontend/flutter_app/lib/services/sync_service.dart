import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/services/credential_service.dart';
import 'package:pharma_assist/services/storage_service.dart';

class SyncException implements Exception {
  final String message;
  final int? statusCode;
  const SyncException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class SyncResponse {
  final String serverRecordId;
  final DateTime synchronizedAt;
  final bool duplicate;
  final bool imageStored;
  const SyncResponse({
    required this.serverRecordId,
    required this.synchronizedAt,
    required this.duplicate,
    required this.imageStored,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    final id = json['server_record_id']?.toString();
    final timestamp = DateTime.tryParse(
      json['synchronized_at']?.toString() ?? '',
    );
    if (id == null || timestamp == null || json['duplicate'] is! bool) {
      throw const FormatException('Malformed synchronization response');
    }
    return SyncResponse(
      serverRecordId: id,
      synchronizedAt: timestamp,
      duplicate: json['duplicate'] as bool,
      imageStored: json['image_stored'] == true,
    );
  }
}

class SyncService {
  final StorageService storage;
  final SyncCredentialStore credentials;
  final http.Client client;
  bool _processing = false;

  SyncService(
    this.storage, {
    SyncCredentialStore? credentials,
    http.Client? client,
  }) : credentials = credentials ?? CredentialService(),
       client = client ?? http.Client();

  static bool isSecureEndpoint(String value) {
    final uri = Uri.tryParse(StorageService.normalizeUrl(value));
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    return uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' ||
            uri.host == 'localhost' ||
            uri.host == '10.0.2.2');
  }

  Map<String, dynamic> buildPayload(ScanHistoryItem item) => {
    'api_version': 'v1',
    'client_record_id': item.id,
    'client_created_at': item.timestamp.toUtc().toIso8601String(),
    'operating_mode': item.operatingMode,
    'provider': item.provider,
    'sync_status': item.syncStatus,
    'screening_metadata': {
      'sample_id': item.sampleId,
      'medicine_name': item.medicineName,
      'final_result': item.finalResult,
      'prediction': item.prediction,
      'confidence': item.confidence,
      'primary_model': item.primaryModel,
      'needs_human_verification': item.needsHumanVerification,
      'full_response': item.fullResponse?.toJson(),
    },
    'notes': item.notes,
    'image_upload_consent': false,
  };

  Future<SyncResponse> synchronize(ScanHistoryItem item) async {
    final token = await credentials.readToken();
    if (token == null || token.trim().isEmpty) {
      throw const SyncException('Sync credentials are not configured.');
    }
    final baseUrl = storage.getBackendUrl();
    if (!isSecureEndpoint(baseUrl)) {
      throw const SyncException(
        'Synchronization requires HTTPS except for localhost development endpoints.',
      );
    }
    final uri = Uri.parse(
      '${StorageService.normalizeUrl(baseUrl)}/sync/records',
    );
    final response = await client
        .post(
          uri,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(buildPayload(item)),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      throw const SyncException(
        'Synchronization credentials were rejected or revoked.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 409) {
      throw const SyncException(
        'This record conflicts with a server record and requires inspection.',
        statusCode: 409,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncException(
        'Synchronization failed with server response ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    try {
      return SyncResponse.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const SyncException('Server returned an invalid sync response.');
    }
  }

  Future<void> processQueue() async {
    if (_processing ||
        !storage.getSyncConsent() ||
        storage.getOperatingMode() == AppConstants.operatingModeOffline) {
      return;
    }
    _processing = true;
    try {
      final now = DateTime.now();
      for (final queueItem in storage.getSyncQueue()) {
        if (queueItem.status == AppConstants.syncStatusConflict ||
            queueItem.status == AppConstants.syncStatusFailed ||
            (queueItem.nextRetryAt != null &&
                queueItem.nextRetryAt!.isAfter(now))) {
          continue;
        }
        final record = storage
            .getScanHistory()
            .where((item) => item.id == queueItem.recordId)
            .firstOrNull;
        if (record == null ||
            record.operatingMode == AppConstants.operatingModeOffline ||
            record.provider == AppConstants.providerUnavailable) {
          await storage.updateScanSyncStatus(
            queueItem.recordId,
            AppConstants.syncStatusBlocked,
          );
          continue;
        }
        await storage.updateScanSyncStatus(
          record.id,
          AppConstants.syncStatusSyncing,
        );
        try {
          final result = await synchronize(record);
          await storage.markSynced(
            record.id,
            serverRecordId: result.serverRecordId,
            synchronizedAt: result.synchronizedAt,
          );
        } on SyncException catch (error) {
          if (error.statusCode == 401 ||
              error.statusCode == 409 ||
              error.message.contains('credentials') ||
              error.message.contains('HTTPS')) {
            await storage.updateScanSyncStatus(
              record.id,
              error.statusCode == 409
                  ? AppConstants.syncStatusConflict
                  : AppConstants.syncStatusBlocked,
            );
          } else {
            await storage.recordSyncAttempt(
              record.id,
              failureReason: error.message,
            );
          }
        } on TimeoutException catch (_) {
          await storage.recordSyncAttempt(
            record.id,
            failureReason: 'Synchronization request timed out.',
          );
        } on SocketException catch (_) {
          await storage.recordSyncAttempt(
            record.id,
            failureReason: 'Backend could not be reached.',
          );
        }
      }
    } finally {
      _processing = false;
    }
  }
}
