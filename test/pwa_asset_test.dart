import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service worker refreshes the offline app shell', () async {
    final source = await File('assets/pwa/sw.js').readAsString();

    expect(source, contains("const CACHE = 'work-experience-pwa-v4'"));
    expect(source, contains("cache.put('/app-shell', response.clone())"));
    expect(source, contains('self.skipWaiting()'));
    expect(source, contains('self.clients.claim()'));
  });

  test('PWA persists sync time and bypasses cached worker updates', () async {
    final source = await File('assets/pwa/index.html').readAsString();

    expect(source, contains('{key:"lastSyncAt",value:this.lastSyncAt}'));
    expect(source, contains('updateViaCache:"none"'));
    expect(source,
        contains('Storage.lastSyncAt=Number(savedSync&&savedSync.value)||0'));
  });
}
