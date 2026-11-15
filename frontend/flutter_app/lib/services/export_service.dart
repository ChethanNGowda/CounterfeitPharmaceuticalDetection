import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/services/history_csv_exporter.dart';
import 'package:pharma_assist/services/report_service.dart';
import 'package:pharma_assist/services/simple_pdf_report_generator.dart';
import 'package:share_plus/share_plus.dart';

/// Structured outcome of a report export operation
class ExportResult {
  final bool success;
  final String filePath;
  final String? publicDownloadsPath;
  final String? errorMessage;

  const ExportResult({
    required this.success,
    required this.filePath,
    this.publicDownloadsPath,
    this.errorMessage,
  });
}

/// Service managing PDF, TXT, and CSV export, saving to Android-accessible storage
/// and triggering the native Android Share/Save sheet.
class ExportService {
  /// Resolves the primary directory for saving user-visible files
  static Future<Directory> _getAccessibleStorageDir() async {
    if (Platform.isAndroid) {
      // Primary public Download directory on Android devices
      final publicDownload = Directory(
        '/storage/emulated/0/Download/PharmaAssist',
      );
      try {
        if (!publicDownload.existsSync()) {
          publicDownload.createSync(recursive: true);
        }
        return publicDownload;
      } catch (_) {
        // Fallback to app documents or external storage directory
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) return extDir;
        } catch (_) {}
      }
    }

    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Exports a single inspection record as a standard PDF report.
  /// Saves to accessible phone storage and opens the Android native Share Sheet.
  static Future<ExportResult> exportPdfReport(ScanHistoryItem item) async {
    try {
      final bytes = SimplePdfReportGenerator.generateReportPdf(item);
      final targetDir = await _getAccessibleStorageDir();
      final sanitizedId = item.sampleId.replaceAll(RegExp(r'[^\w\-]'), '_');
      final fileName = 'pharma_report_$sanitizedId.pdf';
      final file = File('${targetDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Open Android Share / Save Sheet so user can choose destination (Drive, Files, WhatsApp, etc.)
      try {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
          text: 'PharmaAssist Inspection Report — ${item.sampleId}',
          subject: 'PharmaAssist Report: ${item.sampleId}',
        );
      } catch (_) {
        // Sharing might not be supported in headless tests or desktop
      }

      return ExportResult(
        success: true,
        filePath: file.path,
        publicDownloadsPath: targetDir.path.contains('Download')
            ? file.path
            : null,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        filePath: '',
        errorMessage: e.toString(),
      );
    }
  }

  /// Exports a single inspection record as a formatted plain-text report.
  /// Copies to clipboard, writes to accessible phone storage, and opens Share Sheet.
  static Future<ExportResult> exportTxtReport(ScanHistoryItem item) async {
    try {
      final reportText = ReportService.generateReportFromHistory(item);
      await Clipboard.setData(ClipboardData(text: reportText));

      final targetDir = await _getAccessibleStorageDir();
      final sanitizedId = item.sampleId.replaceAll(RegExp(r'[^\w\-]'), '_');
      final fileName = 'pharma_report_$sanitizedId.txt';
      final file = File('${targetDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(reportText, flush: true);

      try {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/plain', name: fileName)],
          text: 'PharmaAssist Text Report — ${item.sampleId}',
          subject: 'PharmaAssist Text Report: ${item.sampleId}',
        );
      } catch (_) {}

      return ExportResult(
        success: true,
        filePath: file.path,
        publicDownloadsPath: targetDir.path.contains('Download')
            ? file.path
            : null,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        filePath: '',
        errorMessage: e.toString(),
      );
    }
  }

  /// Exports an entire list of inspection records as a structured CSV dataset.
  static Future<ExportResult> exportHistoryCsv(
    List<ScanHistoryItem> items,
  ) async {
    try {
      final csv = HistoryCsvExporter.encode(items);
      await Clipboard.setData(ClipboardData(text: csv));

      final targetDir = await _getAccessibleStorageDir();
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'pharma_inspections_$timeStamp.csv';
      final file = File('${targetDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(csv, flush: true);

      try {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv', name: fileName)],
          text:
              'PharmaAssist Inspection Records Dataset (${items.length} records)',
          subject: 'PharmaAssist Inspection Dataset',
        );
      } catch (_) {}

      return ExportResult(
        success: true,
        filePath: file.path,
        publicDownloadsPath: targetDir.path.contains('Download')
            ? file.path
            : null,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        filePath: '',
        errorMessage: e.toString(),
      );
    }
  }
}
