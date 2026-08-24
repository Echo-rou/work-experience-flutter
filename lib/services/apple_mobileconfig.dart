import 'dart:convert';

String buildAppleRootCertificateProfile({
  required List<int> certificateBytes,
  required String certificateThumbprint,
  required String computerName,
}) {
  final fingerprint = certificateThumbprint
      .replaceAll(RegExp('[^0-9A-Fa-f]'), '')
      .toUpperCase();
  if (fingerprint.length != 40) {
    throw const FormatException('A SHA-1 certificate thumbprint is required');
  }
  if (certificateBytes.isEmpty) {
    throw const FormatException('The root certificate is empty');
  }

  final safeComputerName =
      _xml(computerName.trim().isEmpty ? 'Windows PC' : computerName.trim());
  final lowerFingerprint = fingerprint.toLowerCase();
  final certificateData = base64Encode(certificateBytes);
  final payloadUuid = _uuid(fingerprint.substring(0, 32));
  final profileUuid = _uuid(fingerprint.substring(8, 40));

  return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadCertificateFileName</key>
      <string>work-experience-root.cer</string>
      <key>PayloadContent</key>
      <data>$certificateData</data>
      <key>PayloadDescription</key>
      <string>Trusts HTTPS connections to Work Experience Library on $safeComputerName.</string>
      <key>PayloadDisplayName</key>
      <string>Work Experience Library Root – $safeComputerName</string>
      <key>PayloadIdentifier</key>
      <string>com.baixi.workexperience.root.$lowerFingerprint</string>
      <key>PayloadType</key>
      <string>com.apple.security.root</string>
      <key>PayloadUUID</key>
      <string>$payloadUuid</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
    </dict>
  </array>
  <key>PayloadDescription</key>
  <string>Installs the local HTTPS root certificate for Work Experience Library on $safeComputerName. It contains no VPN, MDM, account, or private key.</string>
  <key>PayloadDisplayName</key>
  <string>Work Experience Library – $safeComputerName</string>
  <key>PayloadIdentifier</key>
  <string>com.baixi.workexperience.profile.$lowerFingerprint</string>
  <key>PayloadOrganization</key>
  <string>Work Experience Library</string>
  <key>PayloadRemovalDisallowed</key>
  <false/>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>$profileUuid</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
''';
}

String _uuid(String hex) {
  final value = hex.toUpperCase().split('');
  value[12] = '5';
  value[16] = '8';
  final normalized = value.join();
  return '${normalized.substring(0, 8)}-${normalized.substring(8, 12)}-${normalized.substring(12, 16)}-${normalized.substring(16, 20)}-${normalized.substring(20, 32)}';
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
