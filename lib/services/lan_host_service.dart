import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/attachment_record.dart';
import 'apple_mobileconfig.dart';
import 'local_certificate_service.dart';

typedef StoreReader = List<Map<String, dynamic>> Function(String store);
typedef StoreWriter = Future<void> Function(
    String store, Map<String, dynamic> value);
typedef StoreDelete = Future<void> Function(String store, String key);
typedef StoreClear = Future<void> Function(String store);
typedef StoreBatchWriter = Future<void> Function(
    List<Map<String, dynamic>> entries, List<Map<String, dynamic>> categories);
typedef AttachmentManifestReader = Future<List<Map<String, dynamic>>>
    Function();
typedef AttachmentReader = Future<AttachmentPayload?> Function(String id);
typedef AttachmentWriter = Future<void> Function(
    Map<String, dynamic> metadata, List<int> bytes);
typedef AttachmentDelete = Future<void> Function(String id, int updatedAt);

class LanHostService {
  LanHostService(
      {required this.token,
      required this.readStore,
      required this.writeStore,
      required this.deleteStoreValue,
      required this.clearStore,
      required this.writeBatch,
      required this.readAttachmentManifest,
      required this.readAttachment,
      required this.writeAttachment,
      required this.deleteAttachment,
      this.onPairingCodeChanged,
      this.port = 8732,
      this.setupPort = 8731});
  final String token;
  final StoreReader readStore;
  final StoreWriter writeStore;
  final StoreDelete deleteStoreValue;
  final StoreClear clearStore;
  final StoreBatchWriter writeBatch;
  final AttachmentManifestReader readAttachmentManifest;
  final AttachmentReader readAttachment;
  final AttachmentWriter writeAttachment;
  final AttachmentDelete deleteAttachment;
  final void Function()? onPairingCodeChanged;
  final int port, setupPort;
  HttpServer? _server, _setupServer;
  String _html = '', _manifest = '', _serviceWorker = '';
  List<int> _icon = const [], _rootCertificate = const [];
  String _rootCertificateThumbprint = '';
  final String _cspNonce = base64
      .encode(List<int>.generate(18, (_) => Random.secure().nextInt(256)));
  final Map<String, List<int>> _pairFailures = {}, _authFailures = {};
  Future<void> _mutationQueue = Future<void>.value();
  Timer? _pairingCodeTimer;
  String? address, setupAddress;
  String pairingCode = '';
  bool get running => _server != null;

  Future<String> start() async {
    if (_server != null) return address!;
    _html = await rootBundle.loadString('assets/pwa/index.html');
    _manifest = await rootBundle.loadString('assets/pwa/manifest.webmanifest');
    _serviceWorker = await rootBundle.loadString('assets/pwa/sw.js');
    final icon = await rootBundle.load('assets/pwa/pwa-icon.png');
    _icon = icon.buffer.asUint8List(icon.offsetInBytes, icon.lengthInBytes);
    _rotatePairingCode();
    _pairingCodeTimer = Timer.periodic(
        const Duration(minutes: 10), (_) => _rotatePairingCode());
    final ip = await _findLanAddress();
    final certificateService = LocalCertificateService();
    final cert = await certificateService.prepare(ip);
    _rootCertificate = await File(cert.rootCertificatePath).readAsBytes();
    _rootCertificateThumbprint = cert.rootCertificateThumbprint;
    final context = SecurityContext(withTrustedRoots: false);
    try {
      context.useCertificateChain(cert.pfxPath, password: cert.pfxPassword);
      context.usePrivateKey(cert.pfxPath, password: cert.pfxPassword);
    } finally {
      final pfx = File(cert.pfxPath);
      if (await pfx.exists()) await pfx.delete();
      await certificateService.cleanupServerCertificates();
    }
    _server =
        await HttpServer.bindSecure(InternetAddress.anyIPv4, port, context);
    _server!.listen((r) => unawaited(_handleSecure(r)));
    _setupServer = await HttpServer.bind(InternetAddress.anyIPv4, setupPort);
    _setupServer!.listen((r) => unawaited(_handleSetup(r, ip)));
    address = 'https://$ip:$port/pair';
    setupAddress = 'http://$ip:$setupPort/setup';
    return address!;
  }

  Future<void> stop() async {
    final secure = _server, setup = _setupServer;
    _server = null;
    _setupServer = null;
    address = null;
    setupAddress = null;
    pairingCode = '';
    _pairingCodeTimer?.cancel();
    _pairingCodeTimer = null;
    _pairFailures.clear();
    _authFailures.clear();
    await Future.wait([
      secure?.close(force: true) ?? Future.value(),
      setup?.close(force: true) ?? Future.value()
    ]);
  }

  Future<void> _handleSetup(HttpRequest r, String ip) async {
    try {
      if (r.method == 'GET' &&
          r.uri.path == '/work-experience-root.mobileconfig') {
        final profile = buildAppleRootCertificateProfile(
          certificateBytes: _rootCertificate,
          certificateThumbprint: _rootCertificateThumbprint,
          computerName: Platform.localHostname,
        );
        r.response.headers.set('content-disposition',
            'attachment; filename="work-experience-root.mobileconfig"');
        return await _text(r, profile,
            type: ContentType('application', 'x-apple-aspen-config',
                charset: 'utf-8'));
      }
      if (r.method == 'GET' && r.uri.path == '/work-experience-root.cer') {
        _applyHeaders(r.response);
        r.response.headers.contentType =
            ContentType('application', 'x-x509-ca-cert');
        r.response.headers.set('content-disposition',
            'attachment; filename="work-experience-root.cer"');
        r.response.add(_rootCertificate);
        return await r.response.close();
      }
      if (r.method != 'GET' || r.uri.path != '/setup') {
        return await _json(r, {'error': 'not found'}, status: 404);
      }
      final profileUrl =
          'http://$ip:$setupPort/work-experience-root.mobileconfig';
      final pairUrl = 'https://$ip:$port/pair';
      final page =
          '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>Work Experience Library Setup</title><style>body{font-family:-apple-system,sans-serif;max-width:680px;margin:0 auto;padding:max(28px,env(safe-area-inset-top)) max(22px,env(safe-area-inset-right)) max(28px,env(safe-area-inset-bottom)) max(22px,env(safe-area-inset-left));color:#202838;line-height:1.7}.card{border:1px solid #ddd6c8;border-radius:14px;padding:18px;margin:16px 0}a{display:block;text-align:center;background:#1b2740;color:white;padding:12px;border-radius:10px;text-decoration:none;margin:12px 0}.muted{color:#6f7784;font-size:13px}.step{color:#a97832;font-weight:700}</style></head><body><h1>Work Experience Library · iPhone Setup</h1><div class="card"><div class="step">Step 1 · Download and install the Apple profile</div><a href="$profileUrl">Download Certificate Profile (.mobileconfig)</a><p>Tap <b>Allow</b>. Within 8 minutes, open <b>Settings → Profile Downloaded</b> (or <b>General → VPN &amp; Device Management</b>), open the Work Experience Library profile, and tap <b>Install</b>.</p><p class="muted">The profile contains only this computer's public root certificate. It contains no VPN, MDM, account, or private key.</p></div><div class="card"><div class="step">Step 2 · Enable full certificate trust</div><p>Open <b>Settings → General → About → Certificate Trust Settings</b>, then enable full trust for <b>Work Experience Library Local Root</b>. If the switch is missing, Step 1 was not installed.</p></div><div class="card"><div class="step">Step 3 · Pair over trusted HTTPS</div><a href="$pairUrl">Open Secure Pairing</a><p>The pairing page must open <b>without</b> a “Not Private” warning. Enter the 8-digit code shown in the desktop app, then use Safari <b>Share → Add to Home Screen</b>.</p></div><p class="muted">Use Safari on a trusted private Wi-Fi. Do not choose “Visit Website” to bypass a certificate warning.</p></body></html>''';
      return await _text(r, page, type: ContentType.html);
    } catch (e) {
      try {
        await _json(r, {'error': 'setup failed'}, status: 500);
      } catch (_) {
        await r.response.close();
      }
    }
  }

  String get _pairPage =>
      '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>Secure Pairing</title><style>body{font-family:-apple-system,sans-serif;max-width:520px;margin:0 auto;padding:max(38px,env(safe-area-inset-top)) max(22px,env(safe-area-inset-right)) max(38px,env(safe-area-inset-bottom)) max(22px,env(safe-area-inset-left));color:#202838}.card{border:1px solid #ddd6c8;border-radius:14px;padding:22px}input,button{box-sizing:border-box;width:100%;padding:13px;margin-top:12px;border-radius:9px;font-size:17px}input{border:1px solid #ccc;letter-spacing:4px;text-align:center}button{border:0;background:#1b2740;color:#fff}#msg{min-height:24px;color:#a33;margin-top:12px}.muted{color:#6f7784;font-size:13px;line-height:1.5}</style></head><body><div class="card"><h2>Pair This Home Screen App</h2><p class="muted">Safari and an iPhone Home Screen web app keep separate local storage. Pair once inside this app so it can securely sync its own offline data.</p><div id="checking">Checking existing pairing…</div><div id="form" hidden><p>Enter the current 8-digit code displayed in the desktop app.</p><input id="code" inputmode="numeric" pattern="[0-9]*" maxlength="8" autocomplete="one-time-code"><button id="pair">Pair and Sync This App</button></div><div id="msg"></div></div><script>const form=document.getElementById('form'),checking=document.getElementById('checking'),msg=document.getElementById('msg');async function recover(){try{const stored=localStorage.getItem('fk_key')||'';if(stored){const ping=await fetch('/api/ping',{headers:{'X-Key':stored},cache:'no-store'});if(ping.ok){location.replace('/');return}localStorage.removeItem('fk_key')}const session=await fetch('/api/session',{cache:'no-store'});if(session.ok){const data=await session.json();localStorage.setItem('fk_key',data.token);location.replace('/');return}}catch(e){}checking.hidden=true;form.hidden=false;msg.textContent=''}document.getElementById('pair').onclick=async()=>{msg.textContent='Pairing…';try{const r=await fetch('/api/pair',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code:document.getElementById('code').value})});const d=await r.json();if(!r.ok)throw new Error(d.error||'Pairing failed');localStorage.setItem('fk_key',d.token);location.replace('/')}catch(e){msg.textContent=e.message}};recover()</script></body></html>''';
  Future<void> _handleSecure(HttpRequest r) async {
    try {
      final path = r.uri.path;
      if (r.method == 'GET' && path == '/pair') {
        return await _text(r, _pairPage, type: ContentType.html);
      }
      if (r.method == 'POST' && path == '/api/pair') return await _pair(r);
      if (r.method == 'GET' && path == '/api/session') {
        if (!_pageAuthorized(r)) {
          return await _json(r, {'error': 'pairing required'}, status: 401);
        }
        return await _json(r, {'ok': true, 'token': token});
      }
      if (r.method == 'GET' && (path == '/' || path == '/index.html')) {
        if (!_pageAuthorized(r)) {
          return await _text(r,
              '<h3>Pairing required</h3><p><a href="/pair">Open secure pairing</a></p>',
              status: 401, type: ContentType.html);
        }
        return await _text(r, _html, type: ContentType.html);
      }
      if (r.method == 'GET' && path == '/app-shell') {
        return await _text(r, _html, type: ContentType.html);
      }
      if (r.method == 'GET' && path == '/sw.js') {
        r.response.headers.set('Service-Worker-Allowed', '/');
        return await _text(r, _serviceWorker,
            type: ContentType('application', 'javascript', charset: 'utf-8'));
      }
      if (r.method == 'GET' && path == '/manifest.webmanifest') {
        if (!_pageAuthorized(r)) {
          return await _json(r, {'error': 'unauthorized'}, status: 403);
        }
        return await _text(r, _manifest,
            type:
                ContentType('application', 'manifest+json', charset: 'utf-8'));
      }
      if (r.method == 'GET' && path == '/pwa-icon.png') {
        _applyHeaders(r.response);
        r.response.headers.contentType = ContentType('image', 'png');
        r.response.add(_icon);
        return await r.response.close();
      }
      if (!path.startsWith('/api/')) {
        return await _json(r, {'error': 'not found'}, status: 404);
      }
      final remote = r.connectionInfo?.remoteAddress.address ?? 'unknown';
      if (!_allowed(_authFailures, remote, 10, const Duration(minutes: 1))) {
        return await _json(r, {'error': 'too many attempts'}, status: 429);
      }
      if (!_constantTime(r.headers.value('X-Key') ?? '', token)) {
        _recordFailure(_authFailures, remote);
        return await _json(r, {'error': 'unauthorized'}, status: 403);
      }
      _authFailures.remove(remote);
      if (r.method == 'GET' && path == '/api/ping') {
        return await _json(
            r, {'ok': true, 'time': DateTime.now().millisecondsSinceEpoch});
      }
      if (r.method == 'POST' && path == '/api/sync') {
        return await _serializeMutation(() => _sync(r));
      }
      final s = r.uri.pathSegments;
      if (s.length >= 2 && s[0] == 'api' && s[1] == 'attachments') {
        if (r.method == 'GET' && s.length == 2) {
          return await _json(r, await readAttachmentManifest());
        }
        if (s.length == 3 && _validIdentity(s[2])) {
          final id = s[2];
          if (r.method == 'GET') return await _downloadAttachment(r, id);
          if (r.method == 'PUT') {
            final encoded = r.headers.value('X-Attachment-Meta') ?? '';
            final metadata = _decodeAttachmentMetadata(encoded);
            if (metadata['id']?.toString() != id) {
              throw const FormatException('Attachment id does not match');
            }
            final bytes = await _readBytes(r, 25 * 1024 * 1024);
            await _serializeMutation(() => writeAttachment(metadata, bytes));
            return await _json(r, {'ok': true});
          }
          if (r.method == 'DELETE') {
            final updatedAt = int.tryParse(
                    r.uri.queryParameters['updatedAt']?.toString() ?? '') ??
                0;
            if (updatedAt <= 0) {
              throw const FormatException('Missing deletion timestamp');
            }
            await _serializeMutation(() => deleteAttachment(id, updatedAt));
            return await _json(r, {'ok': true});
          }
        }
      }
      if (s.length >= 3 &&
          s[0] == 'api' &&
          s[1] == 'store' &&
          _validStore(s[2])) {
        final store = s[2];
        if (r.method == 'GET' && s.length == 3) {
          return await _json(r, readStore(store));
        }
        if (r.method == 'PUT' && s.length == 3) {
          final b = await _readJson(r);
          if (b is! Map) {
            return await _json(r, {'error': 'invalid body'}, status: 400);
          }
          await _serializeMutation(
              () => writeStore(store, Map<String, dynamic>.from(b)));
          return await _json(r, {'ok': true});
        }
        if (r.method == 'DELETE' && s.length == 4) {
          await _serializeMutation(() => deleteStoreValue(store, s[3]));
          return await _json(r, {'ok': true});
        }
        if (r.method == 'POST' && s.length == 4 && s[3] == 'clear') {
          await _serializeMutation(() => clearStore(store));
          return await _json(r, {'ok': true});
        }
      }
      return await _json(r, {'error': 'not found'}, status: 404);
    } on FormatException catch (e) {
      try {
        await _json(r, {'error': e.message}, status: 400);
      } catch (_) {
        await r.response.close();
      }
    } catch (e) {
      try {
        await _json(r, {'error': 'request failed'}, status: 500);
      } catch (_) {
        await r.response.close();
      }
    }
  }

  Future<void> _pair(HttpRequest r) async {
    final remote = r.connectionInfo?.remoteAddress.address ?? 'unknown';
    if (!_allowed(_pairFailures, remote, 5, const Duration(minutes: 5))) {
      return _json(r, {'error': 'Too many attempts. Wait five minutes.'},
          status: 429);
    }
    final body = await _readJson(r);
    final code = body is Map ? body['code']?.toString().trim() ?? '' : '';
    if (!_constantTime(code, pairingCode)) {
      _recordFailure(_pairFailures, remote);
      return _json(r, {'error': 'Incorrect pairing code'}, status: 403);
    }
    _pairFailures.remove(remote);
    _rotatePairingCode();
    r.response.cookies.add(Cookie('fk_session', token)
      ..httpOnly = true
      ..secure = true
      ..sameSite = SameSite.strict
      ..path = '/'
      ..maxAge = 31536000);
    return _json(r, {'ok': true, 'token': token});
  }

  bool _pageAuthorized(HttpRequest r) => r.cookies
      .any((c) => c.name == 'fk_session' && _constantTime(c.value, token));
  bool _constantTime(String a, String b) {
    var diff = a.length ^ b.length;
    final length = max(a.length, b.length);
    for (var i = 0; i < length; i++) {
      diff |= (i < a.length ? a.codeUnitAt(i) : 0) ^
          (i < b.length ? b.codeUnitAt(i) : 0);
    }
    return diff == 0;
  }

  void _recordFailure(Map<String, List<int>> values, String remote) => values
      .putIfAbsent(remote, () => [])
      .add(DateTime.now().millisecondsSinceEpoch);
  bool _allowed(Map<String, List<int>> values, String remote, int maxAttempts,
      Duration window) {
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    final list = values.putIfAbsent(remote, () => [])
      ..removeWhere((v) => v < cutoff);
    return list.length < maxAttempts;
  }

  Future<void> _sync(HttpRequest r) async {
    final body = await _readJson(r);
    if (body is! Map) return _json(r, {'error': 'invalid body'}, status: 400);
    final current = <String, Map<String, dynamic>>{
      for (final e in readStore('entries'))
        if ((e['id']?.toString() ?? '').isNotEmpty) e['id'].toString(): e
    };
    final acceptedEntries = <Map<String, dynamic>>[];
    if (body['entries'] is List) {
      for (final raw in (body['entries'] as List).whereType<Map>()) {
        final e = Map<String, dynamic>.from(raw),
            id = raw['id']?.toString() ?? '';
        if (id.isNotEmpty &&
            (current[id] == null || _version(e) > _version(current[id]!))) {
          acceptedEntries.add(e);
          current[id] = e;
        }
      }
    }
    final names = readStore('categories')
        .map((e) => e['name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
    final acceptedCategories = <Map<String, dynamic>>[];
    if (body['categories'] is List) {
      for (final raw in body['categories'] as List) {
        final name = (raw is Map ? raw['name'] : raw)?.toString().trim() ?? '';
        if (name.isNotEmpty && names.add(name)) {
          acceptedCategories.add({
            'name': name,
            'createdAt': DateTime.now().millisecondsSinceEpoch
          });
        }
      }
    }
    if (acceptedEntries.isNotEmpty || acceptedCategories.isNotEmpty) {
      await writeBatch(acceptedEntries, acceptedCategories);
    }
    return _json(r, {
      'entries': readStore('entries'),
      'categories': readStore('categories'),
      'serverTime': DateTime.now().millisecondsSinceEpoch
    });
  }

  int _version(Map<String, dynamic> e) {
    int p(Object? v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    final a = p(e['updatedAt']), b = p(e['deletedAt']);
    return a > b ? a : b;
  }

  bool _validStore(String v) => v == 'entries' || v == 'categories';
  bool _validIdentity(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

  Map<String, dynamic> _decodeAttachmentMetadata(String encoded) {
    if (encoded.isEmpty || encoded.length > 8192) {
      throw const FormatException('Attachment metadata is invalid');
    }
    try {
      final text = utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
      final value = jsonDecode(text);
      if (value is! Map) throw const FormatException();
      return Map<String, dynamic>.from(value);
    } catch (_) {
      throw const FormatException('Attachment metadata is invalid');
    }
  }

  Future<void> _downloadAttachment(HttpRequest r, String id) async {
    final payload = await readAttachment(id);
    if (payload == null || payload.record.deleted) {
      return _json(r, {'error': 'attachment not found'}, status: 404);
    }
    _applyHeaders(r.response);
    final parts = payload.record.mimeType.split('/');
    r.response.headers.contentType = parts.length == 2
        ? ContentType(parts[0], parts[1])
        : ContentType.binary;
    r.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    r.response.headers.set('Content-Disposition',
        "attachment; filename*=UTF-8''${Uri.encodeComponent(payload.record.name)}");
    r.response.headers.contentLength = payload.bytes.length;
    r.response.add(payload.bytes);
    await r.response.close();
  }

  Future<List<int>> _readBytes(HttpRequest r, int limit) async {
    if (r.contentLength > limit) {
      throw const FormatException('Attachment exceeds the 25 MiB limit');
    }
    final bytes = <int>[];
    await for (final chunk in r) {
      bytes.addAll(chunk);
      if (bytes.length > limit) {
        throw const FormatException('Attachment exceeds the 25 MiB limit');
      }
    }
    if (bytes.isEmpty) throw const FormatException('Attachment is empty');
    return bytes;
  }

  Future<Object?> _readJson(HttpRequest r) async {
    if (r.contentLength > 20 * 1024 * 1024) {
      throw const FormatException('request too large');
    }
    final bytes = <int>[];
    await for (final chunk in r) {
      bytes.addAll(chunk);
      if (bytes.length > 20 * 1024 * 1024) {
        throw const FormatException('request too large');
      }
    }
    return bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
  }

  Future<void> _json(HttpRequest r, Object value, {int status = 200}) =>
      _text(r, jsonEncode(value), status: status, type: ContentType.json);
  Future<void> _text(HttpRequest r, String value,
      {int status = 200, required ContentType type}) async {
    final body =
        type.mimeType == ContentType.html.mimeType ? _withNonce(value) : value;
    final bytes = utf8.encode(body);
    r.response.statusCode = status;
    _applyHeaders(r.response);
    r.response.headers.contentType = type;
    r.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    r.response.headers.contentLength = bytes.length;
    r.response.add(bytes);
    await r.response.close();
  }

  void _applyHeaders(HttpResponse response) {
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'DENY');
    response.headers.set('Referrer-Policy', 'no-referrer');
    response.headers
        .set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
    response.headers.set('Cross-Origin-Resource-Policy', 'same-origin');
    response.headers.set('Content-Security-Policy',
        "default-src 'self'; script-src 'self' 'nonce-$_cspNonce'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'");
  }

  String _withNonce(String html) => html
      .replaceAll('<script>', '<script nonce="$_cspNonce">')
      .replaceAll('<style>', '<style nonce="$_cspNonce">');
  void _rotatePairingCode() {
    pairingCode = Random.secure().nextInt(100000000).toString().padLeft(8, '0');
    _pairFailures.clear();
    onPairingCodeChanged?.call();
  }

  Future<T> _serializeMutation<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<String> _findLanAddress() async {
    final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    bool physical(NetworkInterface item) {
      final name = item.name.toLowerCase();
      return !name.contains('vethernet') &&
          !name.contains('virtual') &&
          !name.contains('wsl') &&
          !name.contains('hyper-v') &&
          !name.contains('vmware') &&
          !name.contains('bluetooth');
    }

    bool private(InternetAddress item) =>
        item.address.startsWith('192.168.') ||
        item.address.startsWith('10.') ||
        _private172(item.address);
    final preferred = interfaces
        .where(physical)
        .expand((i) => i.addresses)
        .where(private)
        .toList();
    if (preferred.isNotEmpty) return preferred.first.address;
    final all = interfaces
        .expand((i) => i.addresses)
        .where((a) => !a.isLoopback)
        .toList();
    for (final a in all) {
      if (private(a)) return a.address;
    }
    return all.isEmpty ? '127.0.0.1' : all.first.address;
  }

  bool _private172(String v) {
    final p = v.split('.');
    final n = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return p.first == '172' && n >= 16 && n <= 31;
  }
}
