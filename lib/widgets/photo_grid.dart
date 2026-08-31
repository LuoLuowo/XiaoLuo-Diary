import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'live_photo_badge.dart';

class PhotoGrid extends StatefulWidget {
  const PhotoGrid({
    super.key,
    required this.paths,
    this.onTap,
    this.height = 220,
    this.mode = 'dynamic',
    this.livePaths = const {},
  });
  final List<String> paths;
  final ValueChanged<int>? onTap;
  final double height;
  final String mode;
  final Set<String> livePaths;
  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  final Map<String, double> ratios = {};
  int generation = 0;
  @override
  void initState() {
    super.initState();
    _loadRatios();
  }

  @override
  void didUpdateWidget(PhotoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paths.join('|') != widget.paths.join('|')) _loadRatios();
  }

  Future<void> _loadRatios() async {
    final current = ++generation;
    for (final path in widget.paths.take(4)) {
      if (ratios.containsKey(path)) continue;
      try {
        final buffer = await ui.ImmutableBuffer.fromFilePath(path);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final ratio = descriptor.width / descriptor.height;
        descriptor.dispose();
        buffer.dispose();
        if (!mounted || current != generation) return;
        setState(() => ratios[path] = ratio);
      } catch (_) {
        /* Missing media is filtered below. */
      }
    }
  }

  double _ratio(String path) {
    if (widget.mode == 'landscape') return 16 / 9;
    final value = ratios[path] ?? 4 / 3;
    return widget.mode == 'original' ? value : (value >= 1 ? 4 / 3 : 3 / 4);
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.paths
        .where((path) => File(path).existsSync())
        .toList();
    final visible = available.take(4).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < (visible.length / 2).ceil(); row++) ...[
          if (row > 0) const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (
                var column = 0;
                column < (visible.length == 1 ? 1 : 2);
                column++
              ) ...[
                if (column > 0) const SizedBox(width: 4),
                Expanded(
                  child: row * 2 + column < visible.length
                      ? _tile(
                          context,
                          visible[row * 2 + column],
                          row * 2 + column,
                          available.length,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, String path, int index, int count) =>
      AspectRatio(
        aspectRatio: _ratio(path),
        child: GestureDetector(
          onTap: () => widget.onTap?.call(widget.paths.indexOf(path)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                if (widget.livePaths.contains(path))
                  const Positioned(left: 7, top: 7, child: LivePhotoBadge()),
                if (index == 3 && count > 4)
                  ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: Text(
                        '+${count - 4}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
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

/// Fixed collage used only by the timeline cards. It deliberately does not
/// inherit the detail-page photo-ratio preference: cards remain compact and
/// predictable while the diary detail can show the selected ratio.
class TimelinePhotoGrid extends StatelessWidget {
  const TimelinePhotoGrid({
    super.key,
    required this.paths,
    this.onTap,
    this.livePaths = const {},
  });
  final List<String> paths;
  final ValueChanged<int>? onTap;

  final Set<String> livePaths;

  @override
  Widget build(BuildContext context) {
    final available = paths.where((path) => File(path).existsSync()).toList();
    final visible = available.take(4).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    Widget tile(String path, int index, {double? ratio}) => GestureDetector(
      onTap: () => onTap?.call(paths.indexOf(path)),
      child: AspectRatio(
        aspectRatio: ratio ?? 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(path), fit: BoxFit.cover, cacheWidth: 900),
              if (livePaths.contains(path))
                const Positioned(left: 7, top: 7, child: LivePhotoBadge()),
              if (index == 3 && available.length > 4)
                ColoredBox(
                  color: Colors.black45,
                  child: Center(
                    child: Text(
                      '+${available.length - 4}',
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (visible.length == 1) return tile(visible.first, 0, ratio: 4 / 3);
    if (visible.length == 2) {
      return Row(
        children: [
          Expanded(child: tile(visible[0], 0)),
          const SizedBox(width: 4),
          Expanded(child: tile(visible[1], 1)),
        ],
      );
    }
    if (visible.length == 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: tile(visible[0], 0, ratio: .5)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                tile(visible[1], 1),
                const SizedBox(height: 4),
                tile(visible[2], 2),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tile(visible[0], 0)),
            const SizedBox(width: 4),
            Expanded(child: tile(visible[1], 1)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: tile(visible[2], 2)),
            const SizedBox(width: 4),
            Expanded(child: tile(visible[3], 3)),
          ],
        ),
      ],
    );
  }
}
