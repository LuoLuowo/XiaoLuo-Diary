import 'dart:async';
import 'package:flutter/material.dart';

typedef OperationProgress =
    void Function(String phase, int completed, int total);

/// Owns exactly one dialog route. Errors/cancellation never pop the page below.
Future<T> runLoading<T>(
  BuildContext context,
  String message,
  Future<T> Function(OperationProgress update) operation,
) async {
  final status = ValueNotifier((phase: message, completed: 0, total: 0));
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('加载中'),
          ],
        ),
        content: ValueListenableBuilder(
          valueListenable: status,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.phase),
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: value.total > 0
                    ? (value.completed / value.total).clamp(0.0, 1.0)
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                value.total > 0
                    ? '${(100 * value.completed / value.total).floor()}% · ${value.completed} / ${value.total}'
                    : '正在处理，请稍候…',
              ),
            ],
          ),
        ),
      ),
    ),
  );
  unawaited(navigator.push(route));
  try {
    // Paint the loading state before invoking a picker or doing any work.
    await WidgetsBinding.instance.endOfFrame;
    return await operation((phase, completed, total) {
      status.value = (phase: phase, completed: completed, total: total);
    });
  } finally {
    if (route.isActive) navigator.removeRoute(route);
    await route.completed;
    status.dispose();
  }
}
