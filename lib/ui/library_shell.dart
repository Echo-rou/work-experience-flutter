import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../models/work_entry.dart';
import 'entry_card.dart';
import 'entry_detail_page.dart';
import 'entry_editor_page.dart';
import 'settings_view.dart';

class LibraryShell extends StatelessWidget {
  const LibraryShell({super.key, required this.state});
  final WorkLibraryState state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          if (state.loading) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final desktop = MediaQuery.sizeOf(context).width >= 900;
          return Scaffold(
            drawer: desktop
                ? null
                : Drawer(
                    child: _SideNavigation(state: state, closeAfterTap: true)),
            appBar: desktop
                ? null
                : AppBar(
                    title: const Text('Work Experience Library',
                        style: TextStyle(
                            fontFamily: 'serif', fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.navy,
                    foregroundColor: const Color(0xFFF0E8D8),
                    actions: [
                      IconButton(
                          onPressed: () => _openEditor(context),
                          icon: const Icon(Icons.add),
                          tooltip: 'New Record'),
                    ],
                  ),
            body: Row(
              children: [
                if (desktop)
                  SizedBox(width: 242, child: _SideNavigation(state: state)),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                          state: state,
                          desktop: desktop,
                          onNew: () => _openEditor(context)),
                      if (state.error != null)
                        MaterialBanner(
                          content: Text(state.error!),
                          leading: const Icon(Icons.warning_amber,
                              color: AppColors.danger),
                          actions: [
                            TextButton(
                                onPressed: state.clearError,
                                child: const Text('Dismiss'))
                          ],
                        ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(desktop ? 34 : 14,
                                  desktop ? 28 : 18, desktop ? 34 : 14, 0),
                              child: _body(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: desktop
                ? null
                : FloatingActionButton(
                    onPressed: () => _openEditor(context),
                    child: const Icon(Icons.add)),
            bottomNavigationBar:
                desktop ? null : _BottomNavigation(state: state),
          );
        },
      );

  Widget _body(BuildContext context) {
    if (state.searchQuery.trim().isNotEmpty) {
      return _SearchView(
          state: state, open: (entry) => _openDetail(context, entry));
    }
    return switch (state.view) {
      LibraryView.home => _HomeView(
          state: state,
          open: (entry) => _openDetail(context, entry),
          onNew: () => _openEditor(context)),
      LibraryView.timeline => _DatedEntryView(
          title: 'Timeline',
          subtitle: 'Review your records by date, newest first.',
          emptyMessage: 'No records on the timeline yet.',
          emptyIcon: Icons.schedule,
          state: state,
          entries: state.activeEntries,
          open: (entry) => _openDetail(context, entry)),
      LibraryView.favorites => _DatedEntryView(
          title: 'Favorites',
          subtitle: 'Core records worth revisiting',
          emptyMessage: 'No favorite records yet',
          emptyIcon: Icons.star_border_rounded,
          state: state,
          entries: state.activeEntries.where((e) => e.favorite).toList()
            ..sort(_newestFirst),
          open: (entry) => _openDetail(context, entry),
        ),
      LibraryView.tags =>
        _TagsView(state: state, open: (entry) => _openDetail(context, entry)),
      LibraryView.categories => _CategoriesView(state: state),
      LibraryView.trash => _TrashView(state: state),
      LibraryView.settings => SettingsView(state: state),
    };
  }

  Future<void> _openEditor(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => EntryEditorPage(state: state)));

  Future<void> _openDetail(BuildContext context, WorkEntry entry) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EntryDetailPage(state: state, entryId: entry.id)));
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.state, required this.desktop, required this.onNew});
  final WorkLibraryState state;
  final bool desktop;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : 14),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: TextField(
                onChanged: state.setSearch,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search titles, content, categories, or tags…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: state.searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => state.setSearch(''),
                          icon: const Icon(Icons.close, size: 18)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.line)),
                ),
              ),
            ),
          ),
          if (desktop) ...[
            const Spacer(),
            if (state.saving)
              const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Text('Saving…',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)))
            else
              const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Text('✓ Saved locally',
                      style: TextStyle(fontSize: 12, color: AppColors.accent))),
            FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Record')),
          ],
        ]),
      );
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.state, this.closeAfterTap = false});
  final WorkLibraryState state;
  final bool closeAfterTap;

  static const items = [
    (LibraryView.home, Icons.home_outlined, 'Home'),
    (LibraryView.timeline, Icons.schedule, 'Timeline'),
    (LibraryView.favorites, Icons.star_border_rounded, 'Favorites'),
    (LibraryView.tags, Icons.tag, 'Tags'),
    (LibraryView.categories, Icons.category_outlined, 'Categories'),
    (LibraryView.trash, Icons.delete_outline, 'Trash'),
    (LibraryView.settings, Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.navy,
        child: SafeArea(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Work Experience Library',
                        style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 20,
                            letterSpacing: 1,
                            color: Color(0xFFF0E8D8),
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Reflect · Learn · Grow',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF7D879E),
                            letterSpacing: .5)),
                  ]),
            ),
            const Divider(color: Color(0x22FFFFFF), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: items.map((item) {
                  final selected = state.view == item.$1;
                  final count = switch (item.$1) {
                    LibraryView.trash => state.trashEntries.length,
                    _ => 0,
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: ListTile(
                      dense: true,
                      selected: selected,
                      selectedColor: AppColors.gold,
                      textColor: const Color(0xFFB6BFD1),
                      iconColor:
                          selected ? AppColors.gold : const Color(0xFFB6BFD1),
                      selectedTileColor: const Color(0x29C9A86A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      leading: Icon(item.$2, size: 20),
                      title: Text(item.$3),
                      trailing: count == 0
                          ? null
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: const Color(0x1FFFFFFF),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text('$count',
                                  style: const TextStyle(fontSize: 11)),
                            ),
                      onTap: () {
                        state.changeView(item.$1);
                        if (closeAfterTap) Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Local-first · Private',
                    style: TextStyle(fontSize: 11, color: Color(0xFF66708A)))),
          ]),
        ),
      );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.state});
  final WorkLibraryState state;
  @override
  Widget build(BuildContext context) {
    const views = [
      LibraryView.home,
      LibraryView.timeline,
      LibraryView.favorites,
      LibraryView.settings
    ];
    var index = views.indexOf(state.view);
    if (index < 0) index = 0;
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => state.changeView(views[value]),
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home'),
        NavigationDestination(icon: Icon(Icons.schedule), label: 'Timeline'),
        NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: 'Favorites'),
        NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings'),
      ],
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView(
      {required this.state, required this.open, required this.onNew});
  final WorkLibraryState state;
  final ValueChanged<WorkEntry> open;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final entries = state.activeEntries..sort(_newestFirst);
    final todos = state.todayTodos;
    final days = entries.map((e) => e.date).toSet().length;
    return ListView(padding: const EdgeInsets.only(bottom: 60), children: [
      Container(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 24 : 36),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.navyLight]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Every reflection sharpens the next decision',
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 25,
                  color: Color(0xFFE8E2D2),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Turn todays solution into tomorrows reusable method.',
              style: TextStyle(color: Color(0xFFA8B2C7))),
          const SizedBox(height: 18),
          Text('Recorded on $days day${days == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.gold)),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => _addTodo(context),
            icon: const Icon(Icons.add),
            label: const Text("Add Today's To-do"),
          ),
          if (todos.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              "Today's To-dos",
              style: TextStyle(
                color: Color(0xFFE8E2D2),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...todos.map((todo) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(children: [
                    Checkbox(
                      value: todo.completed,
                      onChanged: (_) => state.toggleTodo(todo.id),
                      fillColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected)
                              ? AppColors.accent
                              : Colors.transparent),
                      side: const BorderSide(color: Color(0xFFA8B2C7)),
                    ),
                    Expanded(
                      child: Text(
                        todo.content,
                        style: TextStyle(
                          color: const Color(0xFFE8E2D2),
                          decoration: todo.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete To-do',
                      onPressed: () => state.removeTodo(todo.id),
                      icon: const Icon(Icons.close,
                          size: 18, color: Color(0xFFA8B2C7)),
                    ),
                  ]),
                )),
          ],
        ]),
      ),
      const SizedBox(height: 22),
      Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onNew,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.add)),
              SizedBox(width: 12),
              Text('Just solved something? Capture it as a reusable record.',
                  style: TextStyle(color: AppColors.muted)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Text('Recent Records',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      if (entries.isEmpty)
        const _Empty(
            icon: Icons.auto_stories_outlined,
            message: 'No records yet. Start with your first takeaway today.')
      else
        _ResponsiveGrid(
          children: entries
              .take(8)
              .map((e) => EntryCard(
                  entry: e,
                  onOpen: () => open(e),
                  onFavorite: () => state.toggleFavorite(e.id)))
              .toList(),
        ),
    ]);
  }

  Future<void> _addTodo(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Today's To-do"),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'What needs to be done?'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.trim().isNotEmpty) await state.addTodo(value);
  }
}

class _DatedEntryView extends StatelessWidget {
  const _DatedEntryView({
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.state,
    required this.entries,
    required this.open,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final WorkLibraryState state;
  final List<WorkEntry> entries;
  final ValueChanged<WorkEntry> open;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = List<WorkEntry>.from(entries)..sort(_newestFirst);
    final grouped = <String, List<WorkEntry>>{};
    for (final entry in sortedEntries) {
      grouped.putIfAbsent(entry.date, () => []).add(entry);
    }
    return ListView(padding: const EdgeInsets.only(bottom: 60), children: [
      _PageHeader(title: title, subtitle: subtitle),
      if (sortedEntries.isEmpty)
        _Empty(icon: emptyIcon, message: emptyMessage)
      else
        ...grouped.entries.expand((group) => [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 13, 2, 10),
                child: Row(children: [
                  Text(group.key,
                      style: const TextStyle(
                          fontFamily: 'serif',
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                  const SizedBox(width: 8),
                  Text(
                      '${group.value.length} record${group.value.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  const SizedBox(width: 10),
                  const Expanded(child: Divider()),
                ]),
              ),
              ...group.value.map((e) => EntryCard(
                    entry: e,
                    compact: true,
                    onOpen: () => open(e),
                    onFavorite: () => state.toggleFavorite(e.id),
                  )),
            ]),
    ]);
  }
}

class _EntryCollection extends StatelessWidget {
  const _EntryCollection(
      {required this.title,
      required this.subtitle,
      required this.emptyMessage,
      required this.state,
      required this.entries,
      required this.open});
  final String title;
  final String subtitle;
  final String emptyMessage;
  final WorkLibraryState state;
  final List<WorkEntry> entries;
  final ValueChanged<WorkEntry> open;

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.only(bottom: 60), children: [
        _PageHeader(title: title, subtitle: subtitle),
        if (entries.isEmpty)
          _Empty(icon: Icons.inbox_outlined, message: emptyMessage)
        else
          _ResponsiveGrid(
              children: entries
                  .map((e) => EntryCard(
                      entry: e,
                      onOpen: () => open(e),
                      onFavorite: () => state.toggleFavorite(e.id)))
                  .toList()),
      ]);
}

class _SearchView extends StatelessWidget {
  const _SearchView({required this.state, required this.open});
  final WorkLibraryState state;
  final ValueChanged<WorkEntry> open;
  @override
  Widget build(BuildContext context) {
    final results = state.searchResults();
    return _EntryCollection(
      title: 'Search Results',
      subtitle:
          '${results.length} result${results.length == 1 ? '' : 's'} for "${state.searchQuery}"',
      emptyMessage: 'No matching records found.',
      state: state,
      entries: results,
      open: open,
    );
  }
}

class _TagsView extends StatelessWidget {
  const _TagsView({required this.state, required this.open});
  final WorkLibraryState state;
  final ValueChanged<WorkEntry> open;
  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final entry in state.activeEntries) {
      for (final tag in entry.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final tags = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final filtered = state.selectedTag == null
        ? <WorkEntry>[]
        : state.activeEntries
            .where((e) => e.tags.contains(state.selectedTag))
            .toList()
      ..sort(_newestFirst);
    return ListView(padding: const EdgeInsets.only(bottom: 60), children: [
      const _PageHeader(title: 'Tags', subtitle: 'Browse records by topic.'),
      if (tags.isEmpty)
        const _Empty(icon: Icons.tag, message: 'No tags yet.')
      else ...[
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: tags
              .map((tag) => FilterChip(
                    selected: state.selectedTag == tag,
                    label: Text('#$tag  ${counts[tag]}'),
                    onSelected: (selected) =>
                        state.selectTag(selected ? tag : null),
                  ))
              .toList(),
        ),
        if (state.selectedTag != null) ...[
          const SizedBox(height: 24),
          Text('#${state.selectedTag}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _ResponsiveGrid(
              children: filtered
                  .map((e) => EntryCard(
                      entry: e,
                      onOpen: () => open(e),
                      onFavorite: () => state.toggleFavorite(e.id)))
                  .toList()),
        ],
      ],
    ]);
  }
}

class _CategoriesView extends StatelessWidget {
  const _CategoriesView({required this.state});
  final WorkLibraryState state;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.only(bottom: 60), children: [
        const _PageHeader(
            title: 'Categories',
            subtitle: 'Build a structure that works for you.'),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Category')),
        ),
        const SizedBox(height: 14),
        ...state.categories.map((category) {
          final count =
              state.activeEntries.where((e) => e.category == category).length;
          return Card(
            margin: const EdgeInsets.only(bottom: 9),
            child: ListTile(
              leading:
                  const Icon(Icons.folder_outlined, color: AppColors.accent),
              title: Text(category),
              subtitle: Text('$count record${count == 1 ? '' : 's'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => value == 'rename'
                    ? _rename(context, category)
                    : _delete(context, category, count),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete'))
                ],
              ),
            ),
          );
        }),
      ]);

  Future<String?> _ask(BuildContext context, String title,
      [String value = '']) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Confirm'))
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _add(BuildContext context) async {
    final name = await _ask(context, 'Add Category');
    if (name != null) await state.addCategory(name);
  }

  Future<void> _rename(BuildContext context, String oldName) async {
    final name = await _ask(context, 'Rename Category', oldName);
    if (name != null) await state.renameCategory(oldName, name);
  }

  Future<void> _delete(BuildContext context, String name, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(count == 0
            ? 'Category "$name" will be deleted.'
            : '$count record${count == 1 ? '' : 's'} will be moved to "Uncategorized".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'))
        ],
      ),
    );
    if (confirmed == true) await state.deleteCategory(name);
  }
}

class _TrashView extends StatelessWidget {
  const _TrashView({required this.state});
  final WorkLibraryState state;
  @override
  Widget build(BuildContext context) {
    final entries = state.trashEntries
      ..sort((a, b) => (b.deletedAt ?? 0).compareTo(a.deletedAt ?? 0));
    return ListView(padding: const EdgeInsets.only(bottom: 60), children: [
      const _PageHeader(
          title: 'Trash',
          subtitle: 'Deleted records can be restored or removed permanently.'),
      if (entries.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
              onPressed: () => _empty(context),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text('Empty Trash (${entries.length})')),
        ),
      const SizedBox(height: 12),
      if (entries.isEmpty)
        const _Empty(icon: Icons.delete_outline, message: 'Trash is empty.')
      else
        ...entries.map((entry) => Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                title: Text(entry.displayText),
                subtitle: Text('${entry.date} · ${entry.timelinePreview()}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Wrap(spacing: 6, children: [
                  OutlinedButton(
                      onPressed: () => state.restore(entry.id),
                      child: const Text('Restore')),
                  IconButton(
                      onPressed: () => _purge(context, entry),
                      icon: const Icon(Icons.delete_forever,
                          color: AppColors.danger),
                      tooltip: 'Delete Forever'),
                ]),
              ),
            )),
    ]);
  }

  Future<bool> _confirm(
          BuildContext context, String title, String message) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete Forever'))
                ],
              )) ??
      false;

  Future<void> _purge(BuildContext context, WorkEntry entry) async {
    if (await _confirm(
        context, 'Delete Forever?', 'This action cannot be undone.')) {
      await state.purge(entry.id);
    }
  }

  Future<void> _empty(BuildContext context) async {
    if (await _confirm(context, 'Empty Trash?',
        'All records in Trash will be deleted permanently.')) {
      await state.emptyTrash();
    }
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        if (columns == 1) {
          return Column(
              children: children
                  .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 11), child: e))
                  .toList());
        }
        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.75,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      });
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});
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

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 70),
        child: Column(children: [
          Icon(icon, size: 46, color: AppColors.muted),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: AppColors.muted))
        ]),
      );
}

int _newestFirst(WorkEntry a, WorkEntry b) {
  final byDate = b.date.compareTo(a.date);
  return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
}
