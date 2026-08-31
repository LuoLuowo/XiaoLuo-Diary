import 'package:intl/intl.dart';

String diaryDate(DateTime value) {
  const weeks = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${DateFormat('yyyy/MM/dd HH:mm').format(value)}  ${weeks[value.weekday - 1]}';
}

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return '☀️ 早安';
  if (hour < 18) return '🌤️ 下午好';
  return '🌙 晚安';
}
