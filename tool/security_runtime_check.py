import json
import plistlib
import re
import ssl
import urllib.error
import urllib.request

TLS = ssl._create_unverified_context()


def request(url, *, data=None, headers=None):
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=headers or {})
    try:
        with urllib.request.urlopen(req, context=TLS, timeout=5) as response:
            return response.status, dict(response.headers), response.read()
    except urllib.error.HTTPError as error:
        return error.code, dict(error.headers), error.read()


setup_status, _, setup = request('http://127.0.0.1:8731/setup')
profile_status, profile_headers, profile = request(
    'http://127.0.0.1:8731/work-experience-root.mobileconfig')
certificate_status, _, certificate = request(
    'http://127.0.0.1:8731/work-experience-root.cer')
pair_status, pair_headers, pair_page = request('https://127.0.0.1:8732/pair')
session_status, _, _ = request('https://127.0.0.1:8732/api/session')
root_status, _, _ = request('https://127.0.0.1:8732/')
pair_attempts = [
    request(
        'https://127.0.0.1:8732/api/pair',
        data={'code': '00000000'},
        headers={'Content-Type': 'application/json'},
    )[0]
    for _ in range(6)
]

setup_text = setup.decode()
required_headers = {
    'content-security-policy', 'x-content-type-options', 'x-frame-options',
    'referrer-policy', 'permissions-policy', 'cross-origin-resource-policy',
}
actual_headers = {name.lower() for name in pair_headers}
profile_header_map = {name.lower(): value for name, value in profile_headers.items()}
profile_plist = plistlib.loads(profile)
root_payload = profile_plist['PayloadContent'][0]
result = {
    'setup_status': setup_status,
    'setup_contains_32_hex_secret': bool(re.search(r'[A-Fa-f0-9]{32}', setup_text)),
    'setup_contains_legacy_query_key': '?k=' in setup_text or '&k=' in setup_text,
    'setup_links_mobileconfig': 'work-experience-root.mobileconfig' in setup_text,
    'profile_status': profile_status,
    'profile_content_type': profile_header_map.get('content-type', '').split(';')[0],
    'profile_has_root_payload': b'<string>com.apple.security.root</string>' in profile,
    'profile_plist_type': profile_plist.get('PayloadType'),
    'certificate_status': certificate_status,
    'profile_certificate_matches_download': root_payload.get('PayloadContent') == certificate,
    'pair_page_status': pair_status,
    'pair_page_supports_home_screen_recovery': (
        b'/api/session' in pair_page
        and b'Pair This Home Screen App' in pair_page
    ),
    'session_without_cookie_status': session_status,
    'root_without_cookie_status': root_status,
    'wrong_pairing_attempt_statuses': pair_attempts,
    'missing_security_headers': sorted(required_headers - actual_headers),
}
print(json.dumps(result, indent=2))
assert result == {
    'setup_status': 200,
    'setup_contains_32_hex_secret': False,
    'setup_contains_legacy_query_key': False,
    'setup_links_mobileconfig': True,
    'profile_status': 200,
    'profile_content_type': 'application/x-apple-aspen-config',
    'profile_has_root_payload': True,
    'profile_plist_type': 'Configuration',
    'certificate_status': 200,
    'profile_certificate_matches_download': True,
    'pair_page_status': 200,
    'pair_page_supports_home_screen_recovery': True,
    'session_without_cookie_status': 401,
    'root_without_cookie_status': 401,
    'wrong_pairing_attempt_statuses': [403, 403, 403, 403, 403, 429],
    'missing_security_headers': [],
}
