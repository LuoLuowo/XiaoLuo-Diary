import 'package:flutter/material.dart';
import 'diary_editor_page.dart';
import 'discover_page.dart';
import 'plan_page.dart';
import 'timeline_page.dart';
import 'data_overview_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final pages = const [
    TimelinePage(),
    PlanPage(),
    DataOverviewPage(),
    DiscoverPage(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: false,
    resizeToAvoidBottomInset: false,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: IndexedStack(index: index, children: pages),
        ),
      ),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    floatingActionButton: SizedBox(
      width: 70,
      height: 70,
      child: FloatingActionButton(
        elevation: 5,
        shape: const CircleBorder(),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DiaryEditorPage()),
        ),
        child: const Icon(Icons.add_rounded, size: 36),
      ),
    ),
    bottomNavigationBar: BottomAppBar(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          _NavItem(
            icon: Icons.auto_stories_outlined,
            activeIcon: Icons.auto_stories_rounded,
            label: '日记',
            active: index == 0,
            onTap: () => setState(() => index = 0),
          ),
          _NavItem(
            icon: Icons.checklist_outlined,
            activeIcon: Icons.checklist_rounded,
            label: '计划',
            active: index == 1,
            onTap: () => setState(() => index = 1),
          ),
          const SizedBox(width: 74),
          _NavItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
            label: '数据',
            active: index == 2,
            onTap: () => setState(() => index = 2),
          ),
          _NavItem(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            label: '功能',
            active: index == 3,
            onTap: () => setState(() => index = 3),
          ),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? activeIcon : icon,
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
