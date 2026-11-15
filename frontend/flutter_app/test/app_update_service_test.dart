import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/services/app_update_service.dart';

void main() {
  group('AppUpdateService version comparison', () {
    test('detects a newer semantic version', () {
      expect(AppUpdateService.isNewerVersion('1.2.1', '1.2.0'), isTrue);
    });

    test('does not report the same version as an update', () {
      expect(AppUpdateService.isNewerVersion('1.2.1', '1.2.1'), isFalse);
    });

    test('does not downgrade installed versions', () {
      expect(AppUpdateService.isNewerVersion('1.1.9', '1.2.0'), isFalse);
    });

    test('ignores build metadata when comparing user-facing versions', () {
      expect(AppUpdateService.isNewerVersion('1.2.1+8', '1.2.1+2'), isFalse);
    });

    test('accepts release tags prefixed with v', () {
      expect(AppUpdateService.isNewerVersion('v1.3.0', '1.2.9'), isTrue);
    });
  });
}
