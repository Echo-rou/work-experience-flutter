import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/work_entry.dart';

class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onFavorite,
    this.compact = false,
  });

  final WorkEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(entry.date,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.title.isEmpty ? 'Untitled Record' : entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink),
                      ),
                    ),
                    IconButton(
                      tooltip: entry.favorite
                          ? 'Remove from Favorites'
                          : 'Add to Favorites',
                      visualDensity: VisualDensity.compact,
                      onPressed: onFavorite,
                      icon: Icon(
                          entry.favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: entry.favorite
                              ? const Color(0xFFE0A83E)
                              : const Color(0xFFD8D2C4)),
                    ),
                  ],
                ),
                if (entry.summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(entry.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF4A5261), height: 1.55)),
                ],
                if (entry.category.isNotEmpty || entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      if (entry.category.isNotEmpty)
                        _Chip(
                            label: entry.category,
                            background: AppColors.accentSoft,
                            foreground: AppColors.accent),
                      ...entry.tags.take(4).map((tag) => _Chip(label: '#$tag')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label,
      this.background = const Color(0xFFEEF0F3),
      this.foreground = const Color(0xFF68707E)});
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                color: foreground,
                fontWeight: FontWeight.w500)),
      );
}
