import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

class LocalCertificateBundle {
  const LocalCertificateBundle(
      {required this.pfxPath,
      required this.pfxPassword,
      required this.rootCertificatePath});
  final String pfxPath;
  final String pfxPassword;
  final String rootCertificatePath;
}

class LocalCertificateService {
  String get _powerShellExecutable {
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final executable =
        File('$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe');
    return executable.existsSync() ? executable.path : 'powershell.exe';
  }

  Map<String, String> get _powerShellEnvironment {
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    return {
      'PSModulePath': '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\Modules'
    };
  }

  Future<LocalCertificateBundle> prepare(String ipAddress) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
          'Automatic LAN HTTPS certificate setup currently supports Windows only');
    }
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
        '${support.path}${Platform.pathSeparator}work_experience_library${Platform.pathSeparator}certificates');
    await directory.create(recursive: true);
    final pfx =
        File('${directory.path}${Platform.pathSeparator}lan-server.pfx');
    final root = File(
        '${directory.path}${Platform.pathSeparator}work-experience-root.cer');
    if (await pfx.exists()) await pfx.delete();
    final password = base64UrlEncode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)));

    String safe(String value) => value.replaceAll("'", "''");
    final script = r'''
$ErrorActionPreference = 'Stop'
$rootSubject = 'CN=Work Experience Library Local Root'
$serverSubject = 'CN=Work Experience Library LAN'
$root = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $rootSubject -and $_.HasPrivateKey } | Sort-Object NotAfter -Descending | Select-Object -First 1
if (-not $root) {
  $root = New-SelfSignedCertificate -Type Custom -Subject $rootSubject -KeyAlgorithm RSA -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage CertSign,CRLSign,DigitalSignature -KeyExportPolicy NonExportable -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddYears(10) -TextExtension @('2.5.29.19={critical}{text}ca=1&pathlength=0')
}
Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $serverSubject } | Remove-Item -Force
$server = New-SelfSignedCertificate -Type Custom -Subject $serverSubject -Signer $root -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyUsage DigitalSignature,KeyEncipherment -KeyExportPolicy Exportable -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddDays(390) -TextExtension @('2.5.29.19={critical}{text}ca=0','2.5.29.37={text}1.3.6.1.5.5.7.3.1',"2.5.29.17={text}IPAddress=$IP_ADDRESS&DNS=localhost")
$password = ConvertTo-SecureString -String $PFX_PASSWORD -Force -AsPlainText
Export-PfxCertificate -Cert $server -FilePath $PFX_PATH -Password $password -ChainOption EndEntityCertOnly -Force | Out-Null
Export-Certificate -Cert $root -FilePath $ROOT_PATH -Type CERT -Force | Out-Null
Remove-Item -LiteralPath ("Cert:\CurrentUser\My\" + $server.Thumbprint) -Force
Write-Output $root.Thumbprint
'''
        .replaceAll(r'$IP_ADDRESS', safe(ipAddress))
        .replaceAll(r'$PFX_PATH', "'${safe(pfx.path)}'")
        .replaceAll(r'$ROOT_PATH', "'${safe(root.path)}'")
        .replaceAll(r'$PFX_PASSWORD', "'${safe(password)}'");

    final result = await Process.run(
      _powerShellExecutable,
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script
      ],
      runInShell: false,
      environment: _powerShellEnvironment,
    );
    if (result.exitCode != 0 || !await pfx.exists() || !await root.exists()) {
      final detail = result.stderr.toString().trim();
      throw ProcessException(
          _powerShellExecutable,
          const [],
          detail.isEmpty ? 'Certificate generation failed' : detail,
          result.exitCode);
    }
    return LocalCertificateBundle(
        pfxPath: pfx.path,
        pfxPassword: password,
        rootCertificatePath: root.path);
  }

  Future<void> cleanupServerCertificates() async {
    if (!Platform.isWindows) return;
    const script = r'''$ErrorActionPreference = 'Stop'
Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq 'CN=Work Experience Library LAN' } | Remove-Item -Force
''';
    final result = await Process.run(
      _powerShellExecutable,
      const [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ],
      runInShell: false,
      environment: _powerShellEnvironment,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        _powerShellExecutable,
        const [],
        'Could not remove the temporary TLS certificate',
        result.exitCode,
      );
    }
  }
}
