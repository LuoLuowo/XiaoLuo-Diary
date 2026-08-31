import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'data_page.dart';
import 'profile_page.dart';
import 'tag_management_page.dart';
import 'theme_page.dart';
import 'trash_page.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 120),
      children: [
        Text(
          '我的',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundImage:
                        profile.avatarPath.isNotEmpty &&
                            File(profile.avatarPath).existsSync()
                        ? FileImage(File(profile.avatarPath))
                        : null,
                    child: profile.avatarPath.isEmpty
                        ? const Text(
                            '罗',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.nickname,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          profile.signature,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        _heading(context, '🎨  外观与主题'),
        _tile(
          context,
          Icons.palette_outlined,
          '主题与颜色',
          '跟随系统 · 多套日间与夜间配色',
          const ThemePage(),
        ),
        const SizedBox(height: 22),
        _heading(context, '⚙️  通用设置'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('显示日记摘要'),
                subtitle: const Text('时间轴卡片显示正文前几行'),
                value: state.showSummary,
                onChanged: (v) => state.setDisplay(summary: v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('显示左侧时间轴'),
                subtitle: const Text('关闭后使用简洁列表布局'),
                value: state.showTimeline,
                onChanged: (v) => state.setDisplay(timeline: v),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('日记字体大小'),
                subtitle: Slider(
                  min: 13,
                  max: 22,
                  divisions: 9,
                  value: state.diaryFontSize,
                  label: '${state.diaryFontSize.round()}号',
                  onChanged: state.setDiaryFontSize,
                ),
                trailing: Text('${state.diaryFontSize.round()}'),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('保存无损原图/原视频'),
                subtitle: const Text('默认关闭；关闭时会自动压缩，节省本地空间'),
                value: state.keepOriginalMedia,
                onChanged: state.setKeepOriginalMedia,
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('日记照片比例'),
                subtitle: const Text('控制打开日记后的照片显示；时间轴卡片保持固定拼图'),
                trailing: DropdownButton<String>(
                  value: state.photoRatioMode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'dynamic', child: Text('动态调整')),
                    DropdownMenuItem(
                      value: 'landscape',
                      child: Text('横向 16:9'),
                    ),
                    DropdownMenuItem(value: 'original', child: Text('真实比例')),
                  ],
                  onChanged: (value) {
                    if (value != null) state.setPhotoRatioMode(value);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _heading(context, '整理与管理'),
        Card(
          child: Column(
            children: [
              _innerTile(
                context,
                Icons.tag_rounded,
                '标签管理',
                const TagManagementPage(),
              ),
              const Divider(height: 1),
              _innerTile(
                context,
                Icons.storage_outlined,
                '数据管理',
                const DataPage(),
              ),
              const Divider(height: 1),
              _innerTile(
                context,
                Icons.delete_sweep_outlined,
                '回收站',
                const TrashPage(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _heading(context, '帮助与联系'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('联系我们'),
            subtitle: const Text('访问 zmjsh.top'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => launchUrl(
              Uri.parse('https://www.zmjsh520.top'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        const SizedBox(height: 22),
        _heading(context, '关于小罗日记'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '小罗日记',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text('V0.7.17'),
                SizedBox(height: 8),
                Text('记录属于自己的每一天。'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _heading(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      value,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    ),
  );
  Widget _innerTile(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
  );
}
