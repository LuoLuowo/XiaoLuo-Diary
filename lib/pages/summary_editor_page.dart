import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../utils/reading_text_styles.dart';
import '../utils/rich_text_contrast.dart';

Document summaryDocument(String plain, String rich) {
  if (rich.isNotEmpty) {
    try {
      return Document.fromJson(jsonDecode(rich) as List);
    } catch (_) {
      /* Legacy plain text. */
    }
  }
  return Document()..insert(0, plain);
}

class SummaryEditorPage extends StatefulWidget {
  const SummaryEditorPage({
    super.key,
    required this.heading,
    required this.plain,
    required this.rich,
    required this.title,
    required this.withTitle,
    required this.onSave,
  });
  final String heading, plain, rich, title;
  final bool withTitle;
  final Future<void> Function(String title, String plain, String rich) onSave;
  @override
  State<SummaryEditorPage> createState() => _SummaryEditorPageState();
}

class _SummaryEditorPageState extends State<SummaryEditorPage> {
  late final title = TextEditingController(text: widget.title);
  late final editor = QuillController(
    document: summaryDocument(widget.plain, widget.rich),
    selection: const TextSelection.collapsed(offset: 0),
  );
  final focus = FocusNode();
  final scroll = ScrollController();
  bool saving = false;
  @override
  void dispose() {
    title.dispose();
    editor.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await widget.onSave(
        title.text.trim(),
        editor.document.toPlainText().trim(),
        jsonEncode(editor.document.toDelta().toJson()),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.heading),
      actions: [
        TextButton(
          onPressed: saving ? null : save,
          child: Text(saving ? '保存中' : '保存'),
        ),
      ],
    ),
    body: Column(
      children: [
        if (widget.withTitle)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '本月标题'),
            ),
          ),
        Expanded(
          child: QuillEditor(
            controller: editor,
            focusNode: focus,
            scrollController: scroll,
            config: QuillEditorConfig(
              expands: true,
              padding: const EdgeInsets.all(20),
              placeholder: '写下这一段时间的心情与收获…',
              customStyles: readingTextStyles(context, 16),
              textSpanBuilder: readableRichTextSpan,
            ),
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: QuillSimpleToolbar(
              controller: editor,
              config: const QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showDividers: false,
                showFontFamily: false,
                showFontSize: false,
                showBoldButton: true,
                showItalicButton: false,
                showUnderLineButton: true,
                showSmallButton: false,
                showLineHeightButton: false,
                showStrikeThrough: false,
                showInlineCode: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: true,
                showAlignmentButtons: false,
                showHeaderStyle: false,
                showListNumbers: false,
                showListBullets: false,
                showListCheck: true,
                showCodeBlock: false,
                showQuote: false,
                showIndent: false,
                showLink: true,
                showUndo: true,
                showRedo: true,
                showDirection: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class SummaryContent extends StatefulWidget {
  const SummaryContent({super.key, required this.plain, required this.rich});
  final String plain, rich;
  @override
  State<SummaryContent> createState() => _SummaryContentState();
}

class _SummaryContentState extends State<SummaryContent> {
  late final controller = QuillController(
    document: summaryDocument(widget.plain, widget.rich),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuillEditor.basic(
    controller: controller,
    config: QuillEditorConfig(
      scrollable: false,
      enableInteractiveSelection: false,
      customStyles: readingTextStyles(context, 15),
      textSpanBuilder: readableRichTextSpan,
    ),
  );
}
