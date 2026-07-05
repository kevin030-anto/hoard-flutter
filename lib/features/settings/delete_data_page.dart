import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../shared/widgets/confirm_dialog.dart';

class DeleteDataPage extends ConsumerWidget {
  const DeleteDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Data')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _DeleteTile(
            icon: Icons.arrow_upward_rounded,
            color: Colors.green,
            title: 'Delete all income',
            subtitle: 'Removes every income entry and adjusts balances.',
            onTap: () => _run(
              context,
              title: 'Delete all income?',
              message:
                  'All income transactions will be permanently deleted and balances adjusted. This cannot be undone.',
              action: notifier.deleteAllIncome,
              done: 'All income deleted',
            ),
          ),
          _DeleteTile(
            icon: Icons.arrow_downward_rounded,
            color: Colors.orange,
            title: 'Delete all expenses',
            subtitle: 'Removes every expense entry and adjusts balances.',
            onTap: () => _run(
              context,
              title: 'Delete all expenses?',
              message:
                  'All expense transactions will be permanently deleted and balances adjusted. This cannot be undone.',
              action: notifier.deleteAllExpenses,
              done: 'All expenses deleted',
            ),
          ),
          _DeleteTile(
            icon: Icons.category_rounded,
            color: Colors.purple,
            title: 'Delete all categories',
            subtitle: 'Removes every category (transactions stay, uncategorized).',
            onTap: () => _run(
              context,
              title: 'Delete all categories?',
              message:
                  'All categories will be permanently deleted. Existing transactions keep their amounts but show as uncategorized. This cannot be undone.',
              action: notifier.deleteAllCategories,
              done: 'All categories deleted',
            ),
          ),
          _DeleteTile(
            icon: Icons.tag_rounded,
            color: Colors.teal,
            title: 'Delete all tags',
            subtitle: 'Removes every tag (transactions stay, untagged).',
            onTap: () => _run(
              context,
              title: 'Delete all tags?',
              message:
                  'All tags will be permanently deleted. Existing transactions keep their data but show as untagged. This cannot be undone.',
              action: notifier.deleteAllTags,
              done: 'All tags deleted',
            ),
          ),
          _DeleteTile(
            icon: Icons.delete_forever_rounded,
            color: Colors.red,
            title: 'Delete ALL data',
            subtitle:
                'Spending, balance accounts, payment modes, categories, tags, auto-pays and settings.',
            onTap: () => _run(
              context,
              title: 'Delete everything?',
              message:
                  'This deletes ALL data: spending, balance categories, payment modes, categories, tags, auto-pays and settings. This cannot be undone.',
              action: notifier.deleteAllData,
              done: 'All data deleted',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() action,
    required String done,
  }) async {
    final ok = await showConfirmDialog(context,
        title: title, message: message, confirmLabel: 'Delete');
    if (!ok) return;
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
    }
  }
}

class _DeleteTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _DeleteTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
