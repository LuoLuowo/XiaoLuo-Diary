import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class TagManagementPage extends StatelessWidget {
  const TagManagementPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          IconButton(
            onPressed: () => _edit(context, state),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        children: [
          for (final tag in state.tags)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -3),
                contentPadding: const EdgeInsets.only(left: 12, right: 4),
                leading: const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.tag, size: 15),
                ),
                title: Text(tag),
                subtitle: Text(
                  '${state.diaries.where((d) => d.tags.contains(tag)).length} 篇',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') _edit(context, state, old: tag);
                    if (v == 'delete') _delete(context, state, tag);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('重命名')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    AppState state, {
    String? old,
  }) async {
    final c = TextEditingController(text: old);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(old == null ? '新建标签' : '重命名标签'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value != null) {
      if (old == null)
        await state.addTag(value);
      else
        await state.renameTag(old, value);
    }
  }

  Future<void> _delete(BuildContext context, AppState state, String tag) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('删除标签“$tag”？'),
            content: const Text('只会解除日记与标签的关系，不会删除任何日记。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) await state.deleteTag(tag);
  }
}
