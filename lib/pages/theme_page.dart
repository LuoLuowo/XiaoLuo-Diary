import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_controller.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('外观与主题')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '显示模式',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('跟随系统'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('浅色'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('深色'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {theme.mode},
            onSelectionChanged: (value) => theme.setMode(value.first),
          ),
          const SizedBox(height: 32),
          Text(
            '日间主题',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _choice(
                theme.lightPalette,
                'warm',
                '暖白',
                const Color(0xFF9C6B4E),
                theme.setLight,
              ),
              _choice(
                theme.lightPalette,
                'cream',
                '米白',
                const Color(0xFFA97845),
                theme.setLight,
              ),
              _choice(
                theme.lightPalette,
                'blue',
                '清新蓝',
                const Color(0xFF487A9E),
                theme.setLight,
              ),
              _choice(
                theme.lightPalette,
                'green',
                '淡绿色',
                const Color(0xFF56806C),
                theme.setLight,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            '夜间主题',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _choice(
                theme.darkPalette,
                'night',
                '深蓝夜空',
                const Color(0xFF30446D),
                theme.setDark,
              ),
              _choice(
                theme.darkPalette,
                'gray',
                '深灰',
                const Color(0xFF3E4148),
                theme.setDark,
              ),
              _choice(
                theme.darkPalette,
                'black',
                '暖黑',
                const Color(0xFF3A302B),
                theme.setDark,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '主题会立即应用到日记、卡片、导航栏和按钮。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _choice(
    String current,
    String value,
    String label,
    Color color,
    ValueChanged<String> select,
  ) => ChoiceChip(
    selected: current == value,
    onSelected: (_) => select(value),
    avatar: CircleAvatar(backgroundColor: color),
    label: Text(label),
    padding: const EdgeInsets.all(10),
  );
}
