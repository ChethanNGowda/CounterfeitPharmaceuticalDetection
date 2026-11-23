import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Copies picker-owned source images into the app's private document directory
/// without resizing, recompressing, or changing the original file bytes.
class MedicineImageStorageService {
  static const int maxImageBytes = 15 * 1024 * 1024;
  static const String _directoryName = 'medicine_package_photos';

  static Future<String> preserveOriginal(
    String sourcePath, {
    Directory? documentsDirectory,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('The selected photo is unavailable.');
    }
    final size = await source.length();
    if (size == 0 || size > maxImageBytes) {
      throw const FileSystemException(
        'Choose a non-empty image no larger than 15 MB.',
      );
    }
    final extension = _safeExtension(sourcePath);
    final directory =
        documentsDirectory ?? await getApplicationDocumentsDirectory();
    final photoDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}$_directoryName',
    );
    await photoDirectory.create(recursive: true);
    final name = 'package_${DateTime.now().microsecondsSinceEpoch}$extension';
    final destination = File(
      '${photoDirectory.path}${Platform.pathSeparator}$name',
    );
    await source.copy(destination.path);
    return destination.path;
  }

  /// Deletes only app-owned package-photo copies; never deletes gallery files
  /// or older records whose paths point outside this directory.
  static Future<void> deleteIfAppOwned(
    String path, {
    Directory? documentsDirectory,
  }) async {
    final appDirectory =
        documentsDirectory ?? await getApplicationDocumentsDirectory();
    final ownedDirectory = Directory(
      '${appDirectory.path}${Platform.pathSeparator}$_directoryName',
    ).absolute.path;
    final candidate = File(path).absolute.path;
    final prefix = '$ownedDirectory${Platform.pathSeparator}';
    if (!candidate.startsWith(prefix)) return;
    final file = File(candidate);
    if (await file.exists()) await file.delete();
  }

  static String _safeExtension(String path) {
    final extension = path.contains('.') ? path.split('.').last : '';
    return switch (extension.toLowerCase()) {
      'jpg' || 'jpeg' => '.jpg',
      'png' => '.png',
      'webp' => '.webp',
      'bmp' => '.bmp',
      _ => '.img',
    };
  }
}
