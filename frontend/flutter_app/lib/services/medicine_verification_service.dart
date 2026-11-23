import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pharma_assist/models/medicine_profile.dart';
import 'package:pharma_assist/models/medicine_verification_record.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/services/sync_service.dart';

class MedicineVerificationService {
  final StorageService storage;
  final http.Client _client;

  MedicineVerificationService(this.storage, [http.Client? client])
    : _client = client ?? http.Client();

  Future<MedicineVerificationRecord> checkOfficialAlerts(
    MedicineProfile profile,
  ) async {
    if (profile.batchNumber.trim().isEmpty) {
      throw const FormatException('A batch number is required for this check.');
    }
    final baseUrl = StorageService.normalizeUrl(storage.getBackendUrl());
    if (!SyncService.isSecureEndpoint(baseUrl)) {
      throw const FormatException(
        'Use HTTPS for this check. A private debug address can be used only in debug builds.',
      );
    }

    final uri = Uri.parse('$baseUrl/verification/official-alerts');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'medicine_name': profile.medicineName,
            'manufacturer': profile.manufacturer,
            'batch_number': profile.batchNumber,
            'manufacturing_date': profile.manufacturingDate,
            'expiry_date': profile.expiryDate,
            'strength': profile.strength,
            'product_identifier': profile.productIdentifier,
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw http.ClientException(
        'The configured backend could not complete the official-source check.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The backend returned an invalid report.');
    }
    final report = MedicineVerificationRecord.fromJson({
      ...decoded,
      'checked_at': DateTime.now().toIso8601String(),
    });
    if (!const {
      'officially_verified',
      'potential_concern',
      'inconsistency_detected',
      'unable_to_verify',
    }.contains(report.status)) {
      throw const FormatException(
        'The backend returned an unknown report status.',
      );
    }
    return report;
  }
}
