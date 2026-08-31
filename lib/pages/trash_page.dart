import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/diary_entry.dart';
import '../services/app_state.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: state.trash.isEmpty
          ? const Center(child: Text('回收站是空的'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 70),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '删除的日记保留30天，到期后自动永久删除。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final value in state.trash)
                  Card(
                    child: ListTile(
                      title: Text(value.diary.displayTitle),
                      subtitle: Text(
                        '删除于 ${DateFormat('yyyy年M月d日 HH:mm').format(value.deletedAt)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) =>
                            _handle(context, state, value, action),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'restore', child: Text('恢复日记')),
                          PopupMenuItem(value: 'delete', child: Text('永久删除')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    AppState state,
    TrashedDiary value,
    String action,
  ) async {
    if (action == 'restore') {
      await state.restoreDiary(value);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日记已恢复')));
      }
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('永久删除这篇日记？'),
            content: const Text('永久删除后无法恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('永久删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await state.deleteDiaryPermanently(value);
  }
}
