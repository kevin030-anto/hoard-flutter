import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/backup/backup_service.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/sheet_scaffold.dart';
import 'delete_data_page.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Currency options offered in the picker.
  static const currencies = <(String, String)>[
    ('₹', 'Indian Rupee'),
    ('\$', 'US Dollar'),
    ('€', 'Euro'),
    ('£', 'British Pound'),
    ('¥', 'Yen / Yuan'),
    ('₩', 'Korean Won'),
    ('₽', 'Russian Ruble'),
    ('฿', 'Thai Baht'),
    ('₺', 'Turkish Lira'),
    ('₫', 'Vietnamese Dong'),
    ('₴', 'Ukrainian Hryvnia'),
    ('₦', 'Nigerian Naira'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appProvider.select((d) => d.settings));
    final notifier = ref.read(appProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const Text('Settings',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),

            // ----------------------------------------------------- Theme
            _SectionCard(
              title: 'Appearance',
              children: [
                _ThemeSelector(
                  current: settings.themeMode,
                  onChanged: (m) =>
                      notifier.updateSettings(settings.copyWith(themeMode: m)),
                ),
              ],
            ),

            // -------------------------------------------------- Currency
            _SectionCard(
              title: 'Currency',
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      currencies.any((c) => c.$1 == settings.currencySymbol)
                          ? settings.currencySymbol
                          : null,
                  decoration: const InputDecoration(labelText: 'Symbol'),
                  items: [
                    for (final c in currencies)
                      DropdownMenuItem(
                        value: c.$1,
                        child: Text('${c.$1}   ${c.$2}'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      notifier
                          .updateSettings(settings.copyWith(currencySymbol: v));
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.showCurrencySymbol,
                  title: const Text('Show currency symbol'),
                  subtitle: const Text('Off hides the symbol next to amounts'),
                  onChanged: (v) => notifier.updateSettings(
                      settings.copyWith(showCurrencySymbol: v)),
                ),
              ],
            ),

            // -------------------------------------------------- Gestures
            _SectionCard(
              title: 'Gestures',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.swapSwipeActions,
                  title: const Text('Swap swipe directions'),
                  subtitle: Text(settings.swapSwipeActions
                      ? 'Right = Edit · Left = Delete'
                      : 'Right = Delete · Left = Edit'),
                  onChanged: (v) => notifier
                      .updateSettings(settings.copyWith(swapSwipeActions: v)),
                ),
              ],
            ),

            // ---------------------------------------------------- Backup
            _SectionCard(
              title: 'Backup & Restore',
              children: [
                _ActionTile(
                  icon: Icons.backup_rounded,
                  color: AppColors.primary,
                  title: 'Backup data',
                  subtitle: 'Export everything to a .json file',
                  onTap: () => _backup(context, notifier),
                ),
                _ActionTile(
                  icon: Icons.restore_rounded,
                  color: AppColors.accent,
                  title: 'Restore data',
                  subtitle: 'Import from a .json backup (replaces current data)',
                  onTap: () => _restore(context, notifier),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Note: receipt images are not included in the backup file — only their references are saved.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // -------------------------------------------------- Danger
            _SectionCard(
              title: 'Data',
              children: [
                _ActionTile(
                  icon: Icons.delete_sweep_rounded,
                  color: Colors.red,
                  title: 'Delete data',
                  subtitle: 'Delete income, expenses, or everything',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeleteDataPage()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Center(
              child: Text(
                  '${AppConstants.appName}  •  v${AppConstants.appVersion}',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backup(BuildContext context, AppNotifier notifier) async {
    final choice = await showModalBottomSheet<_BackupChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BackupSheet(),
    );
    if (choice == null) return;
    try {
      final json = BackupService.buildJson(notifier, parts: choice.parts);
      if (choice.saveToDevice) {
        final path = await BackupService.saveToDevice(json);
        if (context.mounted && path != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Backup saved to device')));
        }
      } else {
        await BackupService.share(json);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    }
  }

  Future<void> _restore(BuildContext context, AppNotifier notifier) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Restore backup?',
      message:
          'This will REPLACE all current data with the contents of the backup file. Continue?',
      confirmLabel: 'Choose file',
      destructive: false,
    );
    if (!ok) return;
    try {
      final restored = await BackupService.restore(notifier);
      if (context.mounted && restored) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data restored successfully')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = {
      ThemeMode.system: ('System', Icons.brightness_auto_rounded),
      ThemeMode.light: ('Light', Icons.light_mode_rounded),
      ThemeMode.dark: ('Dark', Icons.dark_mode_rounded),
    };
    return Row(
      children: [
        for (final e in options.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: current == e.key
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: current == e.key
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 1.6),
                ),
                child: Column(
                  children: [
                    Icon(e.value.$2,
                        color: current == e.key ? AppColors.primary : null),
                    const SizedBox(height: 6),
                    Text(e.value.$1,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                current == e.key ? AppColors.primary : null)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55))),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _BackupChoice {
  final Set<String> parts;
  final bool saveToDevice;
  const _BackupChoice(this.parts, this.saveToDevice);
}

/// Lets the user choose which data sets to back up, then Share or Save.
class _BackupSheet extends StatefulWidget {
  const _BackupSheet();

  @override
  State<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<_BackupSheet> {
  // key -> label
  static const _parts = <String, String>{
    'logs': 'Income & Expense Logs',
    'accounts': 'Accounts',
    'paymentModes': 'Pay Modes',
    'categories': 'Categories',
    'autoPays': 'Auto-Pay',
    'tags': 'Tags',
  };
  final Set<String> _selected = {..._parts.keys};

  bool get _all => _selected.length == _parts.length;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Backup data',
      icon: Icons.backup_rounded,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _all,
          title: const Text('Select All',
              style: TextStyle(fontWeight: FontWeight.w700)),
          onChanged: (v) => setState(() {
            _selected.clear();
            if (v == true) _selected.addAll(_parts.keys);
          }),
        ),
        const Divider(),
        for (final e in _parts.entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _selected.contains(e.key),
            title: Text(e.value),
            onChanged: (v) => setState(() {
              if (v == true) {
                _selected.add(e.key);
              } else {
                _selected.remove(e.key);
              }
            }),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context, _BackupChoice({..._selected}, false)),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context, _BackupChoice({..._selected}, true)),
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
