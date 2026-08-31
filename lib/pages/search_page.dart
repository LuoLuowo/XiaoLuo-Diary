import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/diary_card.dart';
import 'diary_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String query = '';
  final selectedTags = <String>{};
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Each selected tag is a constraint: results must contain all of them.
    final results = state
        .search(query)
        .where((diary) => selectedTags.every(diary.tags.contains))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('搜索日记')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索标题、正文或标签',
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  children: [
                    ChoiceChip(
                      label: const Text('全部'),
                      selected: selectedTags.isEmpty,
                      onSelected: (_) => setState(selectedTags.clear),
                    ),
                    const SizedBox(width: 8),
                    for (final tag in state.tags) ...[
                      FilterChip(
                        label: Text('#$tag'),
                        selected: selectedTags.contains(tag),
                        onSelected: (selected) => setState(() {
                          selected
                              ? selectedTags.add(tag)
                              : selectedTags.remove(tag);
                        }),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (selectedTags.length > 1)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('筛选同时包含所选标签的日记', style: TextStyle(fontSize: 12)),
                ),
              Expanded(
                child: query.trim().isEmpty && selectedTags.isEmpty
                    ? const Center(child: Text('输入关键词，或点击标签找回一段记忆'))
                    : results.isEmpty
                    ? const Center(child: Text('没有找到相关日记'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => DiaryCard(
                          diary: results[i],
                          showSummary: true,
                          fontSize: state.diaryFontSize,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DiaryDetailPage(diaryId: results[i].id!),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
