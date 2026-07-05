import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/icon_registry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/pickers.dart';
import '../../../shared/widgets/sheet_scaffold.dart';

Future<void> showCategoryEditor(BuildContext context, {Category? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CategoryEditor(existing: existing),
  );
}

class _CategoryEditor extends ConsumerStatefulWidget {
  final Category? existing;
  const _CategoryEditor({this.existing});

  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  final _nameCtrl = TextEditingController();
  late int _color;
  late String _icon;
  late CategoryKind _kind;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _color = e?.colorValue ?? AppColors.palette.first.toARGB32();
    _icon = e?.iconKey ?? 'food';
    _kind = e?.kind ?? CategoryKind.expense;
    if (e != null) _nameCtrl.text = e.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _editing ? 'Edit Category' : 'Add Category',
      icon: AppIcons.of(_icon),
      iconColor: Color(_color),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
            onPressed: _nameCtrl.text.trim().isEmpty ? null : _save,
            child: Text(_editing ? 'Save' : 'Add')),
      ),
      children: [
        SheetSection(
          label: 'Name',
          child: TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'e.g. Breakfast, Fuel'),
          ),
        ),
        SheetSection(
          label: 'Used for',
          child: Wrap(
            spacing: 10,
            children: [
              for (final k in CategoryKind.values)
                ChoiceChip(
                  label: Text(switch (k) {
                    CategoryKind.expense => 'Expense',
                    CategoryKind.income => 'Income',
                    CategoryKind.both => 'Both',
                  }),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
        ),
        SheetSection(
          label: 'Color',
          child: ColorPicker(
              selected: _color, onChanged: (c) => setState(() => _color = c)),
        ),
        SheetSection(
          label: 'Icon',
          child: IconPicker(
            iconKeys: AppIcons.categoryIcons,
            selected: _icon,
            color: _color,
            onChanged: (k) => setState(() => _icon = k),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final notifier = ref.read(appProvider.notifier);
    final cat = (widget.existing ??
            Category(
                id: notifier.newId(),
                name: '',
                colorValue: _color,
                iconKey: _icon,
                order: ref.read(appProvider).nextCategoryOrder))
        .copyWith(
      name: _nameCtrl.text.trim(),
      colorValue: _color,
      iconKey: _icon,
      kind: _kind,
    );
    await notifier.upsertCategory(cat);
    if (mounted) Navigator.pop(context);
  }
}
