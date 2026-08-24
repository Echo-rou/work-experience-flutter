import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service worker refreshes the offline app shell', () async {
    final source = await File('assets/pwa/sw.js').readAsString();

    expect(source, contains("const CACHE = 'work-experience-pwa-v8'"));
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

  test('mobile navigation respects iPhone safe areas', () async {
    final source = await File('assets/pwa/index.html').readAsString();

    expect(source, contains('viewport-fit=cover'));
    expect(source, contains('left:0;right:0;bottom:0'));
    expect(source, contains('max(5px,env(safe-area-inset-bottom))'));
    expect(source, contains('border-radius:0;overflow:hidden'));
    expect(source, contains('margin-top:0'));
    expect(source, contains('env(safe-area-inset-top,0px)'));
    expect(source, contains('height:calc(58px + var(--safe-top))'));
    expect(source, contains('@media (max-width:1000px)'));
    expect(source, contains('html.apple-phone'));
    expect(source, contains('height:100dvh'));
  });

  test('mobile has reliable new record entry points', () async {
    final source = await File('assets/pwa/index.html').readAsString();

    expect(source, contains('id="btn-new-top" aria-label="Add a new record"'));
    expect(source, contains('id="quick-new" aria-label="Add a new record"'));
    expect(source, contains('touch-action:manipulation'));
    expect(source, contains('list="category-options"'));
    expect(source, contains('Choose or enter a new category'));
  });

  test('Home Screen PWA can pair its isolated iPhone storage', () async {
    final manifest =
        await File('assets/pwa/manifest.webmanifest').readAsString();
    final page = await File('assets/pwa/index.html').readAsString();
    final host =
        await File('lib/services/lan_host_service.dart').readAsString();

    expect(manifest, contains('"start_url": "/pair"'));
    expect(page, contains('if(!Storage.key&&navigator.onLine)'));
    expect(page, contains('location.replace("/pair")'));
    expect(page, contains('Pair This App'));
    expect(host, contains("path == '/api/session'"));
    expect(host, contains("localStorage.setItem('fk_key',data.token)"));
  });
}
