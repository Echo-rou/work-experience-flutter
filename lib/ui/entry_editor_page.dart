import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../models/work_entry.dart';

class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({super.key, required this.state, this.entry});
  final WorkLibraryState state;
  final WorkEntry? entry;

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  late final TextEditingController _date;
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _tags;
  late final TextEditingController _summary;
  late final TextEditingController _content;
  late final TextEditingController _link;
  bool _preview = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _date = TextEditingController(
        text: entry?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    _title = TextEditingController(text: entry?.title ?? '');
    _category = TextEditingController(text: entry?.category ?? '');
    _tags = TextEditingController(text: entry?.tags.join(', ') ?? '');
    _summary = TextEditingController(text: entry?.summary ?? '');
    _content = TextEditingController(text: entry?.content ?? '');
    _link = TextEditingController(text: entry?.link ?? '');
  }

  @override
  void dispose() {
    for (final controller in [
      _date,
      _title,
      _category,
      _tags,
      _summary,
      _content,
      _link
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title:
              Text(widget.entry == null ? 'Record a Takeaway' : 'Edit Record'),
          actions: [
            TextButton.icon(
              onPressed: _submitting ? null : _save,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
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
                        MediaQuery.sizeOf(context).width < 600 ? 18 : 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 650;
                          final date = _Field(
                              label: 'Date',
                              child: TextField(
                                  controller: _date,
                                  readOnly: true,
                                  onTap: _pickDate));
                          final title = _Field(
                            label: 'Title',
                            child: TextField(
                                controller: _title,
                                decoration: const InputDecoration(
                                    hintText:
                                        'A short title, for example: Supply chain risk decision')),
                          );
                          if (narrow) return Column(children: [date, title]);
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 190, child: date),
                                const SizedBox(width: 16),
                                Expanded(child: title),
                              ]);
                        }),
                        LayoutBuilder(builder: (context, constraints) {
                          final category = _Field(
                            label: 'Category',
                            child: Autocomplete<String>(
                              initialValue:
                                  TextEditingValue(text: _category.text),
                              optionsBuilder: (value) => widget.state.categories
                                  .where((e) => e.contains(value.text)),
                              onSelected: (value) => _category.text = value,
                              fieldViewBuilder:
                                  (context, controller, focusNode, onSubmit) {
                                controller.addListener(
                                    () => _category.text = controller.text);
                                return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                        hintText:
                                            'Choose or enter a new category'));
                              },
                            ),
                          );
                          final link = _Field(
                            label: 'Related Link (optional)',
                            child: TextField(
                                controller: _link,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                    hintText: 'https://…')),
                          );
                          if (constraints.maxWidth < 650)
                            return Column(children: [category, link]);
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: category),
                                const SizedBox(width: 16),
                                Expanded(child: link)
                              ]);
                        }),
                        _Field(
                          label: 'Tags',
                          hint: 'Separate multiple tags with commas',
                          child: TextField(
                              controller: _tags,
                              decoration: const InputDecoration(
                                  hintText:
                                      'For example: supply chain, contract, risk')),
                        ),
                        _Field(
                          label: 'Daily Takeaway',
                          child: TextField(
                            controller: _summary,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                                hintText:
                                    'In one sentence: what will I do next time?'),
                          ),
                        ),
                        Row(
                          children: [
                            const Expanded(
                                child: Text('Thought Process',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600))),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _preview = !_preview),
                              icon: Icon(
                                  _preview
                                      ? Icons.edit_outlined
                                      : Icons.visibility_outlined,
                                  size: 18),
                              label: Text(
                                  _preview ? 'Continue Editing' : 'Preview'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_preview)
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 220),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDFCFB),
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _content.text.trim().isEmpty
                                ? const Text('No content yet',
                                    style: TextStyle(color: AppColors.muted))
                                : MarkdownBody(data: _content.text),
                          )
                        else
                          TextField(
                            controller: _content,
                            minLines: 9,
                            maxLines: 20,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText:
                                  'Record your reasoning, approach, and reusable lessons…\n\nMarkdown supported: **bold**, # heading, - list, > quote',
                              alignLabelWithHint: true,
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            FilledButton.icon(
                                onPressed: _submitting ? null : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Save Record')),
                            const SizedBox(width: 12),
                            OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel')),
                            const Spacer(),
                            const Flexible(
                                child: Text(
                                    'Saved locally first; LAN sync runs automatically when available',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.muted))),
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
      );

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date.text) ?? DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null) _date.text = DateFormat('yyyy-MM-dd').format(result);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty &&
        _summary.text.trim().isEmpty &&
        _content.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a title, takeaway, or thought before saving')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.state.saveEntry(
        id: widget.entry?.id,
        date: _date.text,
        title: _title.text,
        category: _category.text,
        tags: _tags.text.split(RegExp('[,，]')),
        summary: _summary.text,
        content: _content.text,
        link: _link.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF4A5261))),
          const SizedBox(height: 7),
          child,
          if (hint != null) ...[
            const SizedBox(height: 5),
            Text(hint!,
                style: const TextStyle(fontSize: 12, color: AppColors.muted))
          ],
        ]),
      );
}
