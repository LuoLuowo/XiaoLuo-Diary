import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FocusSession {
  const FocusSession({
    required this.type,
    required this.minutes,
    required this.completedAt,
  });
  final String type;
  final int minutes;
  final DateTime completedAt;
  Map<String, Object?> toMap() => {
    'type': type,
    'minutes': minutes,
    'completedAt': completedAt.toIso8601String(),
  };
  factory FocusSession.fromMap(Map<String, Object?> map) => FocusSession(
    type: map['type'] as String? ?? '专注',
    minutes: map['minutes'] as int? ?? 0,
    completedAt:
        DateTime.tryParse(map['completedAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

class PomodoroService {
  static const _sessionsKey = 'focusSessions';
  static const _typesKey = 'focusTypes';
  static Future<List<FocusSession>> sessions() async {
    final raw = (await SharedPreferences.getInstance()).getString(_sessionsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (item) =>
              FocusSession.fromMap(Map<String, Object?>.from(item as Map)),
        )
        .toList();
  }

  static Future<void> addSession(FocusSession session) async {
    final values = await sessions()
      ..add(session);
    await (await SharedPreferences.getInstance()).setString(
      _sessionsKey,
      jsonEncode(values.map((e) => e.toMap()).toList()),
    );
  }

  static Future<List<String>> types() async =>
      (await SharedPreferences.getInstance()).getStringList(_typesKey) ??
      ['学习', '工作', '阅读'];
  static Future<void> saveTypes(List<String> values) async =>
      (await SharedPreferences.getInstance()).setStringList(_typesKey, values);
}
