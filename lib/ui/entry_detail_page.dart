import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../models/work_entry.dart';
import '../utils/safe_url.dart';
import 'entry_editor_page.dart';

class EntryDetailPage extends StatelessWidget {
  const EntryDetailPage(
      {super.key, required this.state, required this.entryId});
  final WorkLibraryState state;
  final String entryId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final entry = state.findEntry(entryId);
          if (entry == null) {
            return const Scaffold(
                body: Center(child: Text('Record not found')));
          }
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.background,
              title: const Text('Record Details'),
              actions: [
                IconButton(
                  tooltip: entry.favorite
                      ? 'Remove from Favorites'
                      : 'Add to Favorites',
                  onPressed: () => state.toggleFavorite(entry.id),
                  icon: Icon(
                      entry.favorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: entry.favorite ? const Color(0xFFE0A83E) : null),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EntryEditorPage(state: state, entry: entry),
                  )),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Move to Trash',
                  onPressed: () => _delete(context, entry),
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.danger),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 60),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(entry.date,
                            style: const TextStyle(color: AppColors.muted)),
                        if (entry.category.isNotEmpty)
                          Chip(label: Text(entry.category)),
                        ...entry.tags.map((tag) => Chip(label: Text('#$tag'))),
                      ],
                    ),
                    if (entry.contentItems.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: List.generate(entry.contentItems.length,
                                (index) {
                              final item = entry.contentItems[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == entry.contentItems.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accentSoft,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: MarkdownBody(
                                        data: item.replaceAll(
                                            RegExp(r'\r?\n'), '  \n'),
                                        selectable: true,
                                        onTapLink: (_, href, __) =>
                                            _openHttpLink(context, href ?? ''),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                    if (entry.link.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _openHttpLink(context, entry.link),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open Related Link'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );

  Future<void> _openHttpLink(BuildContext context, String value) async {
    final uri = parseSafeHttpUrl(value);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Only valid HTTP and HTTPS links can be opened')));
      return;
    }
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this link')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this link')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WorkEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text('“${entry.displayText}” can be restored later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move to Trash')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await state.moveToTrash(entry.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
