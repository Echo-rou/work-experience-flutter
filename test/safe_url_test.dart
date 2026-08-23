import 'package:flutter_test/flutter_test.dart';
import 'package:work_experience_library/utils/safe_url.dart';

void main() {
  group('safe external links', () {
    test('accepts HTTP and HTTPS links with an authority', () {
      expect(parseSafeHttpUrl('https://example.com/path')?.scheme, 'https');
      expect(parseSafeHttpUrl(' http://localhost:8080 '), isNotNull);
    });

    test('rejects executable, local-file, and malformed links', () {
      expect(parseSafeHttpUrl('javascript:alert(1)'), isNull);
      expect(parseSafeHttpUrl('file:///C:/secret.txt'), isNull);
      expect(parseSafeHttpUrl('mailto:user@example.com'), isNull);
      expect(parseSafeHttpUrl('https:///missing-host'), isNull);
      expect(parseSafeHttpUrl('not a url'), isNull);
    });
  });
}
