import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../app_theme.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.state});
  final WorkLibraryState state;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _url;
  late final TextEditingController _token;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.state.serverUrl);
    _token = TextEditingController(text: widget.state.serverToken);
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 60),
        children: [
          const _Header(
              title: 'Settings', subtitle: 'Backup, restore, and LAN sync'),
          _Section(
            title: 'iPhone PWA',
            description:
                'iPhone data is always saved locally first and remains available while the computer is off. On the same Wi-Fi, both devices sync automatically. For first-time setup, open the Setup Guide URL and trust the dedicated certificate.',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                    widget.state.pwaHosting
                        ? Icons.wifi_tethering
                        : Icons.wifi_tethering_off,
                    color: widget.state.pwaHosting
                        ? AppColors.accent
                        : AppColors.muted),
                const SizedBox(width: 10),
                Text(
                    widget.state.pwaHosting
                        ? 'LAN service is running'
                        : 'LAN service is stopped',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              if (widget.state.pwaAddress.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Setup Guide URL (contains no secret)',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 5),
                SelectableText(widget.state.pwaSetupAddress,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const Text('iPhone PWA URL',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 5),
                SelectableText(widget.state.pwaAddress,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text('Pairing code: ${widget.state.pwaPairingCode}',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
              if (widget.state.pwaHostError != null) ...[
                const SizedBox(height: 10),
                Text(widget.state.pwaHostError!,
                    style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => widget.state.pwaHosting
                          ? widget.state.stopPwaHost()
                          : widget.state.startPwaHost()),
                  icon: Icon(widget.state.pwaHosting
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline),
                  label: Text(widget.state.pwaHosting
                      ? 'Stop Service'
                      : 'Start Service'),
                ),
                if (widget.state.pwaAddress.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: widget.state.pwaSetupAddress));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Address copied')));
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Setup Guide URL'),
                  ),
              ]),
              const SizedBox(height: 12),
              const Text(
                  'After the first online launch and Add to Home Screen, the PWA can open, view, and edit offline. Newer changes merge automatically when the computer is online again.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          _Section(
            title: 'Local Data and Portable Backup',
            description:
                'Records are always saved to this device first. Export a .dwr backup regularly for complete recovery.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export Backup')),
                OutlinedButton.icon(
                    onPressed: _busy ? null : () => _import(true),
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Merge Import')),
                OutlinedButton.icon(
                    onPressed: _busy ? null : () => _import(false),
                    icon: const Icon(Icons.restore),
                    label: const Text('Replace and Restore')),
                Text(
                    widget.state.lastBackupAt == 0
                        ? 'No backup exported yet'
                        : 'Last backup: ${_time(widget.state.lastBackupAt)}',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          _Section(
            title: 'Connect Trusted HTTPS Sync Service (Advanced)',
            description:
                'Only connect to a trusted HTTPS endpoint. Plain HTTP can expose the access key to other devices on the network.',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (context, constraints) {
                final url = TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                      labelText: 'Computer URL',
                      hintText: 'Example: https://192.168.1.8:8732'),
                );
                final token = TextField(
                  controller: _token,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Access Key',
                      hintText: 'Access key issued by the trusted service'),
                );
                if (constraints.maxWidth < 650) {
                  return Column(
                      children: [url, const SizedBox(height: 12), token]);
                }
                return Row(children: [
                  Expanded(flex: 2, child: url),
                  const SizedBox(width: 12),
                  Expanded(child: token)
                ]);
              }),
              const SizedBox(height: 14),
              Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                        onPressed: _busy ? null : _saveAndSync,
                        icon: const Icon(Icons.sync),
                        label: Text(widget.state.syncing
                            ? 'Syncing…'
                            : 'Save and Sync')),
                    OutlinedButton(
                        onPressed: _busy ? null : _test,
                        child: const Text('Test Connection')),
                    if (widget.state.lastSyncAt > 0)
                      Text('Last sync: ${_time(widget.state.lastSyncAt)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                  ]),
              if (widget.state.syncMessage != null) ...[
                const SizedBox(height: 10),
                Text(widget.state.syncMessage!,
                    style: TextStyle(
                        color:
                            widget.state.syncMessage!.startsWith('Sync failed')
                                ? AppColors.danger
                                : AppColors.accent)),
              ],
            ]),
          ),
          const _Section(
            title: 'Privacy Note',
            description:
                'Use this app for lessons, decisions, methods, and reflection. Do not store client information, case files, contract text, or confidential material.',
            child: Row(children: [
              Icon(Icons.privacy_tip_outlined, color: AppColors.accent),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'LAN sync does not upload to the cloud. Data moves only between devices you configure.'))
            ]),
          ),
        ],
      );

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
        final path = await widget.state.exportBackup();
        if (path != null && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Backup exported')));
        }
      });

  Future<void> _import(bool merge) => _run(() async {
        if (!merge) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Replace current data?'),
              content: const Text(
                  'Current records will be replaced by the backup. Export a backup first.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Continue')),
              ],
            ),
          );
          if (confirmed != true) return;
        }
        final count = await widget.state.importBackup(merge: merge);
        if (count != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported $count new records')));
        }
      });

  Future<void> _test() => _run(() async {
        await widget.state.testLan(_url.text, _token.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Connection successful')));
        }
      });

  Future<void> _saveAndSync() => _run(() async {
        await widget.state.saveLanConfig(_url.text, _token.text);
        await widget.state.syncLan();
      });

  static String _time(int milliseconds) => DateFormat('yyyy-MM-dd HH:mm')
      .format(DateTime.fromMillisecondsSinceEpoch(milliseconds));
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 25,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        ]),
      );
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.description, required this.child});
  final String title;
  final String description;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(description,
                style: const TextStyle(color: AppColors.muted, height: 1.55)),
            const SizedBox(height: 18),
            child,
          ]),
        ),
      );
}
