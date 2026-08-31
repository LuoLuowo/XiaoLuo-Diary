import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'gallery_page.dart';
import 'annual_summary_page.dart';
import 'reading_page.dart';
import 'settings_page.dart';
import 'countdown_page.dart';
import 'random_moment_page.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
      children: [
        Text(
          '功能',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          '整理生活，也收藏阅读和每一年的故事。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        _FeatureCard(
          icon: '⚙️',
          title: '设置',
          description: '主题、资料、标签与本地数据',
          button: '打开设置',
          colors: const [Color(0xFF7687A6), Color(0xFF52647E)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: SettingsPage()),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _FeatureCard(
          icon: '🎲',
          title: '随机时刻',
          description: '去看看曾经的自己。',
          button: '随机看看',
          colors: const [Color(0xFFD9A66C), Color(0xFFA96D55)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RandomMomentPage()),
          ),
        ),
        const SizedBox(height: 18),
        _FeatureCard(
          icon: '⏳',
          title: '倒数日',
          description: '记住生日、纪念日和期待的日子',
          button: '查看倒数',
          colors: const [Color(0xFF4B9BC1), Color(0xFF34718F)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CountdownPage()),
          ),
        ),
        const SizedBox(height: 18),
        _FeatureCard(
          icon: '🖼️',
          title: '我的画廊',
          description:
              '${state.diaries.fold<int>(0, (sum, e) => sum + e.images.length)} 张照片，都是生活留下的光。',
          button: '打开画廊',
          colors: const [Color(0xFF6C92A8), Color(0xFF48677D)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GalleryPage()),
          ),
        ),
        const SizedBox(height: 18),
        _FeatureCard(
          icon: '📖',
          title: '阅读感悟',
          description: '${state.books.length} 本书 · 大纲式读书笔记',
          button: '开始阅读',
          colors: const [Color(0xFF7F9271), Color(0xFF526648)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReadingPage()),
          ),
        ),
        const SizedBox(height: 18),
        _FeatureCard(
          icon: '🗓️',
          title: '年度总结',
          description: '按年份回顾，也包含每个月的小结',
          button: '查看总结',
          colors: const [Color(0xFF9A7F9D), Color(0xFF6E5675)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnualSummaryPage()),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.button,
    required this.colors,
    required this.onTap,
  });
  final String icon, title, description, button;
  final List<Color> colors;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 31)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonal(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors.last,
              padding: const EdgeInsets.symmetric(horizontal: 13),
            ),
            child: Text(button),
          ),
        ],
      ),
    ),
  );
}
