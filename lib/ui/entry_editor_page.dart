import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../models/work_entry.dart';
import '../utils/safe_url.dart';

class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({super.key, required this.state, this.entry});

  final WorkLibraryState state;
  final WorkEntry? entry;

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  late final TextEditingController _date;
  late final TextEditingController _category;
  late final TextEditingController _tags;
  late final TextEditingController _link;
  final List<TextEditingController> _items = [];
  final List<FocusNode> _itemFocusNodes = [];
  bool _submitting = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _date = TextEditingController(
      text: entry?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _category = TextEditingController(text: entry?.category ?? '');
    _tags = TextEditingController(text: entry?.tags.join(', ') ?? '');
    _link = TextEditingController(text: entry?.link ?? '');
    for (final value in entry?.contentItems ?? const <String>[]) {
      _addItem(value, false);
    }
    if (_items.isEmpty) _addItem('', false);
    for (final controller in [_date, _category, _tags, _link]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final controller in [_date, _category, _tags, _link, ..._items]) {
      controller.dispose();
    }
    for (final focusNode in _itemFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Widget _buildCategoryInput() {
    final categories = widget.state.categories.toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return MenuAnchor(
      menuChildren: [
        for (final category in categories)
          MenuItemButton(
            onPressed: () {
              _category.text = category;
              _category.selection =
                  TextSelection.collapsed(offset: category.length);
            },
            child: Text(category),
          ),
      ],
      builder: (context, menuController, child) => TextField(
        key: const ValueKey('record-category'),
        controller: _category,
        onTap: categories.isEmpty
            ? null
            : () {
                if (!menuController.isOpen) menuController.open();
              },
        decoration: InputDecoration(
          hintText: 'Choose or enter a new category',
          suffixIcon: categories.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Show existing categories',
                  onPressed: () => menuController.isOpen
                      ? menuController.close()
                      : menuController.open(),
                  icon: const Icon(Icons.arrow_drop_down),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: !_dirty || _submitting,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) await _confirmDiscard();
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: Text(widget.entry == null ? 'Add Record' : 'Edit Record'),
            actions: [
              TextButton.icon(
                onPressed: _submitting ? null : _save,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save'),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(
                        MediaQuery.sizeOf(context).width < 600 ? 18 : 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field(
                            label: 'Date',
                            child: TextField(
                              key: const ValueKey('record-date'),
                              controller: _date,
                              readOnly: true,
                              onTap: _pickDate,
                            ),
                          ),
                          _Field(
                            label: 'Category',
                            child: _buildCategoryInput(),
                          ),
                          _Field(
                            label: 'Tags',
                            hint: 'Separate multiple tags with commas',
                            child: TextField(
                              key: const ValueKey('record-tags'),
                              controller: _tags,
                              decoration: const InputDecoration(
                                hintText: 'For example: work, study, idea',
                              ),
                            ),
                          ),
                          _Field(
                            label: 'Related Link (optional)',
                            child: TextField(
                              key: const ValueKey('record-link'),
                              controller: _link,
                              keyboardType: TextInputType.url,
                              decoration:
                                  const InputDecoration(hintText: 'https://…'),
                            ),
                          ),
                          const Text(
                            'Items',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Enter adds the next item. Shift + Enter starts a new line inside the current item.',
                            style:
                                TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_items.length, _buildItem),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: _submitting ? null : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Save Record'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              const Spacer(),
                              const Flexible(
                                child: Text(
                                  'Saved locally first; LAN sync runs automatically when available',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildItem(int index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${index + 1}.',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Focus(
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      _insertLineBreak(index);
                    } else {
                      _insertItemAfter(index);
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  key: ValueKey('record-item-$index'),
                  controller: _items[index],
                  focusNode: _itemFocusNodes[index],
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: index == 0
                        ? 'Enter the first item'
                        : 'Enter the next item',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('add-item-$index'),
                  tooltip: 'Add item after this one',
                  onPressed: () => _insertItemAfter(index),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  key: ValueKey('remove-item-$index'),
                  tooltip: 'Remove item',
                  onPressed:
                      _items.length == 1 ? null : () => _removeItem(index),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          ],
        ),
      );

  void _addItem([String value = '', bool notify = true]) {
    final controller = TextEditingController(text: value);
    controller.addListener(_markDirty);
    _items.add(controller);
    _itemFocusNodes.add(FocusNode());
    if (notify && mounted) {
      setState(() => _dirty = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).nextFocus();
      });
    }
  }

  void _insertItemAfter(int index) {
    final controller = TextEditingController()..addListener(_markDirty);
    final focusNode = FocusNode();
    setState(() {
      _items.insert(index + 1, controller);
      _itemFocusNodes.insert(index + 1, focusNode);
      _dirty = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNode.requestFocus();
    });
  }

  void _insertLineBreak(int index) {
    final controller = _items[index];
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final text = controller.text.replaceRange(start, end, '\n');
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  void _removeItem(int index) {
    final controller = _items.removeAt(index);
    final focusNode = _itemFocusNodes.removeAt(index);
    controller.dispose();
    focusNode.dispose();
    setState(() => _dirty = true);
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'Your changes have not been saved. You can stay and finish editing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _dirty = false;
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date.text) ?? DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null) {
      _date.text = DateFormat('yyyy-MM-dd').format(result);
    }
  }

  Future<void> _save() async {
    final items = _items
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item before saving')),
      );
      return;
    }
    final link = _link.text.trim();
    if (link.isNotEmpty && parseSafeHttpUrl(link) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid HTTP or HTTPS related link'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.state.saveEntry(
        id: widget.entry?.id,
        date: _date.text,
        title: '',
        category: _category.text,
        tags: _tags.text.split(RegExp('[,，]')),
        summary: '',
        content: items.join('\n\n'),
        items: items,
        link: _link.text,
      );
      if (mounted) {
        _dirty = false;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.hint});

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A5261),
              ),
            ),
            const SizedBox(height: 7),
            child,
            if (hint != null) ...[
              const SizedBox(height: 5),
              Text(
                hint!,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ],
        ),
      );
}
