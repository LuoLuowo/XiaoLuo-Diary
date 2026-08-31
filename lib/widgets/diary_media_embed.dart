import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../pages/image_preview_page.dart';
import '../utils/live_photo.dart';
import 'video_thumbnail.dart';

class DiaryMediaEmbedBuilder extends EmbedBuilder {
  const DiaryMediaEmbedBuilder({
    required this.type,
    required this.focusNode,
    this.liveVideos = const [],
  });
  final String type;
  final FocusNode focusNode;
  final List<String> liveVideos;
  @override
  String get key => type;
  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final source = embedContext.node.value.data as String;
    final controller = embedContext.controller;
    void insertLine(bool after) {
      final position = embedContext.node.documentOffset + (after ? 1 : 0);
      controller.replaceText(position, 0, '\n', null);
      focusNode.requestFocus();
      final selection = TextSelection.collapsed(
        offset: position + (after ? 1 : 0),
      );
      controller.updateSelection(selection, ChangeSource.local);
      // The surrounding Quill gesture also selects the embed on this tap.
      // Restore the requested blank line after that gesture/focus update.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted)
          controller.updateSelection(selection, ChangeSource.local);
      });
    }

    Future<bool> remove(String _) async {
      final position = embedContext.node.documentOffset;
      controller.replaceText(
        position,
        1,
        '',
        TextSelection.collapsed(offset: position),
      );
      return true;
    }

    Widget gutter(bool after) => Semantics(
      label: after ? '在媒体下方输入文字' : '在媒体上方输入文字',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => insertLine(after),
        child: const SizedBox(height: 22, width: double.infinity),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        gutter(false),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              if (type == 'image')
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImagePreviewPage(
                        paths: [source],
                        onDelete: remove,
                        liveVideos: {
                          if (livePhotoVideoForImage(source, liveVideos)
                              case final video?)
                            source: video,
                        },
                      ),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.file(
                      File(source),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      cacheWidth: 1600,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                )
              else
                VideoThumbnail(path: source),
              Positioned(
                right: 5,
                top: 5,
                child: IconButton.filledTonal(
                  tooltip: '移除媒体',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    final ok =
                        await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('从正文移除媒体？'),
                            content: const Text('保存日记后生效，取消编辑不会删除原文件。'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('移除'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                    if (ok) await remove(source);
                  },
                ),
              ),
            ],
          ),
        ),
        gutter(true),
      ],
    );
  }
}
