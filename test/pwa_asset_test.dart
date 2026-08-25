import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service worker refreshes the offline app shell', () async {
    final source = await File('assets/pwa/sw.js').readAsString();

    expect(source, contains("const CACHE = 'work-experience-pwa-v11'"));
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
    expect(source, contains('max(3px,calc(var(--safe-bottom) - 12px))'));
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
    expect(
        source,
        contains(
            'input:not([type="file"]),textarea,select{font-size:16px!important}'));
    expect(source, contains('window.visualViewport'));
    expect(source, contains('root.classList.toggle("keyboard-open",open)'));
    expect(source, contains('focusForTyping(next)'));
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

  test('PWA merges sync responses atomically and keeps deletion tombstones',
      () async {
    final source = await File('assets/pwa/index.html').readAsString();

    expect(source, contains('_mergeRemoteEntry(remote)'));
    expect(source, contains('this.db.transaction("entries","readwrite")'));
    expect(source, contains('this._version(remote)>this._version(current)'));
    expect(source, contains('for(const e of list) await purgeEntry(e.id)'));
    expect(source, isNot(contains('for(const e of list) await Storage.del')));
  });

  test('PWA stores and synchronizes binary attachments separately', () async {
    final source = await File('assets/pwa/index.html').readAsString();
    final host =
        await File('lib/services/lan_host_service.dart').readAsString();

    expect(source, contains('DB_VER=3'));
    expect(source, contains('createObjectStore("attachments"'));
    expect(source, contains('_syncAttachments()'));
    expect(source, contains('X-Attachment-Meta'));
    expect(source, contains('id="attachment-input"'));
    expect(host, contains("s[1] == 'attachments'"));
    expect(host, contains('25 * 1024 * 1024'));
  });
  test('LAN host serializes mutations and rotates one-time pairing codes',
      () async {
    final host =
        await File('lib/services/lan_host_service.dart').readAsString();

    expect(host, contains('_serializeMutation(() => _sync(r))'));
    expect(host,
        contains('await writeBatch(acceptedEntries, acceptedCategories)'));
    expect(host, contains('Timer.periodic('));
    expect(host, contains('const Duration(minutes: 10)'));
    expect(host, contains("script-src 'self' 'nonce-\$_cspNonce'"));
    expect(host, isNot(contains("script-src 'self' 'unsafe-inline'")));
  });
}
