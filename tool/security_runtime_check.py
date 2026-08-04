import json
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
pair_status, pair_headers, _ = request('https://127.0.0.1:8732/pair')
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
result = {
    'setup_status': setup_status,
    'setup_contains_32_hex_secret': bool(re.search(r'[A-Fa-f0-9]{32}', setup_text)),
    'setup_contains_legacy_query_key': '?k=' in setup_text or '&k=' in setup_text,
    'pair_page_status': pair_status,
    'root_without_cookie_status': root_status,
    'wrong_pairing_attempt_statuses': pair_attempts,
    'missing_security_headers': sorted(required_headers - actual_headers),
}
print(json.dumps(result, indent=2))
assert result == {
    'setup_status': 200,
    'setup_contains_32_hex_secret': False,
    'setup_contains_legacy_query_key': False,
    'pair_page_status': 200,
    'root_without_cookie_status': 401,
    'wrong_pairing_attempt_statuses': [403, 403, 403, 403, 403, 429],
    'missing_security_headers': [],
}
