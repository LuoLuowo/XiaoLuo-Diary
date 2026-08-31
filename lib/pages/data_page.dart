import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/app_state.dart';
import '../widgets/loading_operation.dart';

enum _BackupExportScope { full, dateRange }

class DataPage extends StatelessWidget {
  const DataPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final imageCount = state.diaries.fold<int>(
      0,
      (s, d) => s + d.images.length,
    );
    final attachmentCount = state.diaries.fold<int>(
      0,
      (s, d) => s + d.attachments.length,
    );
    final videoCount = state.diaries.fold<int>(
      0,
      (s, d) => s + d.videos.length,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          FutureBuilder<Map<String, int>>(
            future: state.storage.mediaCounts(),
            builder: (context, mediaSnapshot) {
              final scanned = mediaSnapshot.data ?? const <String, int>{};
              final shownImages = imageCount > (scanned['images'] ?? 0)
                  ? imageCount
                  : (scanned['images'] ?? 0);
              final shownVideos = videoCount > (scanned['videos'] ?? 0)
                  ? videoCount
                  : (scanned['videos'] ?? 0);
              final shownAttachments =
                  attachmentCount > (scanned['attachments'] ?? 0)
                  ? attachmentCount
                  : (scanned['attachments'] ?? 0);
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('日记数量'),
                      trailing: Text('${state.diaries.length} 篇'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.video_library_outlined),
                      title: const Text('视频数量'),
                      trailing: Text('$shownVideos 个'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.photo_outlined),
                      title: const Text('图片数量'),
                      trailing: Text('$shownImages 张'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: const Text('附件数量'),
                      trailing: Text('$shownAttachments 个'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('媒体占用'),
                      subtitle: const Text('不包含已导出的 ZIP / PDF 备份'),
                      trailing: Text(_size(state.storageBytes)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: const Text('清理无引用媒体'),
                      subtitle: const Text('释放旧版永久删除后留下的文件，不删除日记、回收站或备份'),
                      onTap: () async {
                        final ok =
                            await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('清理无引用媒体？'),
                                content: const Text(
                                  '只清理应用媒体目录中已不被任何日记、回收站、书籍封面或头像使用的文件。该清理不可撤销，导出的备份不受影响。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('清理'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (!ok) return;
                        final freed = await state.cleanUnreferencedMedia();
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已释放 ${_size(freed)}')),
                          );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.backup_outlined),
                  title: Text('导出与恢复'),
                  subtitle: Text('导出后可自行保存到阿里云盘或其他云盘'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('导出阅读 PDF'),
                  subtitle: const Text('用于查看、打印；包含日记文字和照片缩略图'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportPdf(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('导出数据备份'),
                  subtitle: const Text('完整备份或按日期导出增量 ZIP'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportData(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('导入数据备份'),
                  subtitle: const Text('仅追加未存在的日记，不会覆盖本地内容'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importData(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder(
            future: state.storage.mediaRoot(),
            builder: (_, snapshot) => Card(
              child: ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('本地媒体位置'),
                subtitle: Text(snapshot.data?.path ?? '读取中…'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final result = await state.changeMediaRoot();
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(result.message)));
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Card(
            child: ListTile(
              leading: Icon(Icons.cloud_outlined),
              title: Text('阿里云盘'),
              subtitle: Text('即将支持 · 第一版不会连接云端'),
              trailing: Chip(label: Text('敬请期待')),
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '所有日记内容、照片、视频和附件都优先保存在这台设备上。图片和视频默认压缩；可在通用设置中开启原图保存。',
              style: TextStyle(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  Future<void> _exportPdf(BuildContext context) async {
    final state = context.read<AppState>();
    try {
      final file = await runLoading(
        context,
        '正在整理日记并生成 PDF…',
        (_) => state.exportDiaryPdf(),
      );
      if (!context.mounted) return;
      await _exportDone(context, file, '阅读 PDF 已生成', allowSaveToFolder: false);
    } catch (error) {
      if (context.mounted) {
        _error(context, 'PDF 导出失败：$error');
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    final scope = await showModalBottomSheet<_BackupExportScope>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('完整数据备份'),
              subtitle: const Text('导出全部日记、媒体和阅读感悟'),
              onTap: () => Navigator.pop(sheetContext, _BackupExportScope.full),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('按日期导出增量备份'),
              subtitle: const Text('只导出所选日期内的日记，文件名带日期范围'),
              onTap: () =>
                  Navigator.pop(sheetContext, _BackupExportScope.dateRange),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (scope == null || !context.mounted) return;
    DateTime? from;
    DateTime? to;
    if (scope == _BackupExportScope.dateRange) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1970),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: DateTime(now.year, now.month, now.day),
        ),
        helpText: '选择要备份的日记日期范围',
      );
      if (range == null || !context.mounted) return;
      from = DateTime(range.start.year, range.start.month, range.start.day);
      to = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
        999,
      );
    }
    final state = context.read<AppState>();
    try {
      final result = await runLoading(
        context,
        '正在准备数据备份…',
        (update) =>
            state.exportDataBackup(from: from, to: to, onProgress: update),
      );
      if (!context.mounted) return;
      await _exportDone(
        context,
        result.file,
        scope == _BackupExportScope.full ? '完整数据备份已生成' : '增量数据备份已生成',
        allowSaveToFolder: true,
      );
    } catch (error) {
      if (context.mounted) {
        _error(context, '数据备份失败：$error');
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final state = context.read<AppState>();
    try {
      final picked = await runLoading(
        context,
        '正在选择备份文件…',
        (_) => FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['zip'],
          withData: false,
        ),
      );
      final path = picked?.files.singleOrNull?.path;
      if (path == null || !context.mounted) return;
      final preview = await runLoading(
        context,
        '正在检查备份文件…',
        (update) => state.inspectDataBackup(File(path), onProgress: update),
      );
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('确认导入备份？'),
          content: Text(
            '备份中有 ${preview.diaries.length} 篇日记、${preview.books.length} 本阅读感悟、${preview.mediaNames.length} 个媒体文件。\n\n只会追加本地不存在的日记和书籍；同一篇记录会自动跳过。不会覆盖本地日记、个人资料、设置或已有总结。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
      final result = await runLoading(
        context,
        '正在恢复数据，请不要关闭应用…',
        (update) => state.importDataBackup(File(path), onProgress: update),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已追加 ${result.addedDiaries} 篇日记、${result.addedBooks} 本书籍；跳过 ${result.skippedDiaries} 篇已有日记、${result.skippedBooks} 本已有书籍',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        _error(context, '无法导入该备份：$error');
      }
    }
  }

  Future<void> _exportDone(
    BuildContext context,
    File file,
    String title, {
    required bool allowSaveToFolder,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(title)),
            IconButton(
              tooltip: '关闭',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: Text(
          allowSaveToFolder
              ? '备份文件已生成。你可以选择手机或电脑上的文件夹另存一份，也可以分享给其他应用。\n\n应用内副本：\n${file.path}'
              : 'PDF 已生成。点击“分享给其他 App”，可以选择阅读器、文件管理器或其他支持 PDF 的应用。\n\n应用内副本：\n${file.path}',
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile(file.path)],
                  title: title,
                  text: '小罗日记备份文件',
                ),
              );
            },
            icon: const Icon(Icons.ios_share),
            label: const Text('分享给其他 App'),
          ),
          if (allowSaveToFolder)
            FilledButton.icon(
              onPressed: () async {
                try {
                  final storage = context.read<AppState>().storage;
                  final saved = await runLoading(
                    context,
                    '正在保存备份到所选文件夹…',
                    (_) => storage.saveExportCopy(file),
                  );
                  if (saved != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已保存到你选择的位置：$saved')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    _error(context, '保存到本地失败：$error');
                  }
                }
              },
              icon: const Icon(Icons.save_alt),
              label: const Text('保存到本地文件夹'),
            ),
        ],
      ),
    );
  }

  void _error(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('操作未完成'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
