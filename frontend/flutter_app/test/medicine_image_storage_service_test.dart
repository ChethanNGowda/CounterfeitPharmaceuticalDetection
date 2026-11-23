import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/services/medicine_image_storage_service.dart';

void main() {
  test('copies original image bytes into private app storage', () async {
    final root = await Directory.systemTemp.createTemp('pharma-images-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}${Platform.pathSeparator}source.jpg');
    final original = List<int>.generate(256, (index) => index);
    await source.writeAsBytes(original);

    final savedPath = await MedicineImageStorageService.preserveOriginal(
      source.path,
      documentsDirectory: root,
    );

    expect(await File(savedPath).readAsBytes(), original);
    expect(await source.readAsBytes(), original);
    expect(savedPath, contains('medicine_package_photos'));
    await MedicineImageStorageService.deleteIfAppOwned(
      savedPath,
      documentsDirectory: root,
    );
    expect(await File(savedPath).exists(), isFalse);
  });

  test('does not delete a gallery or arbitrary external file', () async {
    final root = await Directory.systemTemp.createTemp('pharma-images-');
    addTearDown(() => root.delete(recursive: true));
    final external = File('${root.path}${Platform.pathSeparator}external.jpg');
    await external.writeAsBytes([1, 2, 3]);

    await MedicineImageStorageService.deleteIfAppOwned(
      external.path,
      documentsDirectory: root,
    );

    expect(await external.exists(), isTrue);
  });

  test('rejects empty and over-limit source files without copying', () async {
    final root = await Directory.systemTemp.createTemp('pharma-images-');
    addTearDown(() => root.delete(recursive: true));
    final empty = File('${root.path}${Platform.pathSeparator}empty.jpg');
    await empty.writeAsBytes([]);
    await expectLater(
      MedicineImageStorageService.preserveOriginal(
        empty.path,
        documentsDirectory: root,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      Directory('${root.path}${Platform.pathSeparator}medicine_package_photos')
          .existsSync(),
      isFalse,
    );
  });
}
