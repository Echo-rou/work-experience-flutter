import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../models/work_entry.dart';
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
          if (entry == null)
            return const Scaffold(
                body: Center(child: Text('Record not found')));
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
                    Text(entry.title.isEmpty ? 'Untitled Record' : entry.title,
                        style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                    const SizedBox(height: 10),
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
                    if (entry.summary.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Daily Takeaway',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent)),
                              const SizedBox(height: 8),
                              SelectableText(entry.summary,
                                  style: const TextStyle(
                                      fontSize: 16, height: 1.7)),
                            ]),
                      ),
                    ],
                    if (entry.content.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: MarkdownBody(
                            data: entry.content,
                            selectable: true,
                            onTapLink: (_, href, __) {
                              if (href != null)
                                launchUrl(Uri.parse(href),
                                    mode: LaunchMode.externalApplication);
                            },
                          ),
                        ),
                      ),
                    ],
                    if (entry.link.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(entry.link),
                              mode: LaunchMode.externalApplication),
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

  Future<void> _delete(BuildContext context, WorkEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text(
            '“${entry.title.isEmpty ? 'Untitled Record' : entry.title}” can be restored later.'),
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
