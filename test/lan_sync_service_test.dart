import 'package:flutter_test/flutter_test.dart';
import 'package:work_experience_library/services/lan_sync_service.dart';

void main() {
  group('LAN sync transport policy', () {
    test('defaults an address without a scheme to HTTPS', () {
      final service = LanSyncService(
        baseUrl: '192.168.1.8:8732/',
        token: 'test-token',
      );
      expect(service.baseUrl, 'https://192.168.1.8:8732');
    });

    test('rejects plain HTTP to another device', () {
      expect(
        () => LanSyncService(
          baseUrl: 'http://192.168.1.8:8732',
          token: 'test-token',
        ),
        throwsFormatException,
      );
    });

    test('allows HTTP only for local development', () {
      final service = LanSyncService(
        baseUrl: 'http://127.0.0.1:8732/',
        token: 'test-token',
      );
      expect(service.baseUrl, 'http://127.0.0.1:8732');
    });
  });
}
