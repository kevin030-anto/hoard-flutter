import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_tag.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/sheet_scaffold.dart';

Future<void> showTagEditor(BuildContext context, {AppTag? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TagEditor(existing: existing),
  );
}

class _TagEditor extends ConsumerStatefulWidget {
  final AppTag? existing;
  const _TagEditor({this.existing});

  @override
  ConsumerState<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends ConsumerState<_TagEditor> {
  final _nameCtrl = TextEditingController();

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) _nameCtrl.text = widget.existing!.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _editing ? 'Edit Tag' : 'Add Tag',
      icon: Icons.tag_rounded,
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
            onPressed: _nameCtrl.text.trim().isEmpty ? null : _save,
            child: Text(_editing ? 'Save' : 'Add')),
      ),
      children: [
        SheetSection(
          label: 'Tag name',
          child: TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                prefixText: '#', hintText: 'travel, work, savings...'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: a tag named "savings" marks tagged transactions as savings in Analysis.',
          style: TextStyle(
              fontSize: 12,
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final notifier = ref.read(appProvider.notifier);
    final name = _nameCtrl.text.trim().replaceAll('#', '');
    final tag = (widget.existing ??
            AppTag(
              id: notifier.newId(),
              name: name,
              order: ref.read(appProvider).nextTagOrder,
            ))
        .copyWith(name: name);
    await notifier.upsertTag(tag);
    if (mounted) Navigator.pop(context);
  }
}
