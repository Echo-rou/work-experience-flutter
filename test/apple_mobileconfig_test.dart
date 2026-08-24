import 'package:flutter_test/flutter_test.dart';
import 'package:work_experience_library/services/apple_mobileconfig.dart';

void main() {
  test('builds an iOS root certificate configuration profile', () {
    final profile = buildAppleRootCertificateProfile(
      certificateBytes: const [0, 1, 2, 255],
      certificateThumbprint: '0123456789ABCDEF0123456789ABCDEF01234567',
      computerName: 'Office & <PC>',
    );

    expect(profile, contains('<string>com.apple.security.root</string>'));
    expect(profile, contains('<string>Configuration</string>'));
    expect(profile, contains('<data>AAEC/w==</data>'));
    expect(
        profile,
        contains(
            'com.baixi.workexperience.root.0123456789abcdef0123456789abcdef01234567'));
    expect(profile, contains('Office &amp; &lt;PC&gt;'));
    expect(profile, isNot(contains('Office & <PC>')));
    expect(profile, contains('<false/>'));
    expect(
        RegExp(r'<string>[0-9A-F]{8}-[0-9A-F]{4}-5[0-9A-F]{3}-8[0-9A-F]{3}-[0-9A-F]{12}</string>')
            .allMatches(profile)
            .length,
        2);
  });

  test('rejects invalid certificate profile input', () {
    expect(
      () => buildAppleRootCertificateProfile(
        certificateBytes: const [1],
        certificateThumbprint: 'short',
        computerName: 'PC',
      ),
      throwsFormatException,
    );
    expect(
      () => buildAppleRootCertificateProfile(
        certificateBytes: const [],
        certificateThumbprint: '0123456789ABCDEF0123456789ABCDEF01234567',
        computerName: 'PC',
      ),
      throwsFormatException,
    );
  });
}
