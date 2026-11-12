import 'package:intl/intl.dart';

final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final DateFormat _dateOnly = DateFormat('dd/MM/yyyy');
final DateFormat _timeOnly = DateFormat('HH:mm');

String formatDateTime(DateTime? value) =>
    value == null ? 'Sin registros' : _dateTime.format(value);

String formatDate(DateTime? value) =>
    value == null ? 'Sin registros' : _dateOnly.format(value);

String formatTime(DateTime? value) =>
    value == null ? '--:--' : _timeOnly.format(value);

String formatShortDateTime(DateTime? value) =>
    value == null ? 'Sin registros' : _dateTime.format(value);

String relativeTime(DateTime? value, {DateTime? now}) {
  if (value == null) return 'Sin registros';
  final reference = now ?? DateTime.now();
  final difference = reference.difference(value);
  final future = difference.isNegative;
  final duration = difference.abs();
  String text;
  if (duration.inMinutes < 1) {
    text = 'menos de 1 min';
  } else if (duration.inHours < 1) {
    text = '${duration.inMinutes} min';
  } else if (duration.inDays < 1) {
    text = '${duration.inHours} h';
  } else if (duration.inDays < 30) {
    text = '${duration.inDays} d';
  } else if (duration.inDays < 365) {
    text = '${duration.inDays ~/ 30} mes(es)';
  } else {
    text = '${duration.inDays ~/ 365} año(s)';
  }
  return future ? 'en $text' : 'hace $text';
}

String formatDuration(Duration duration) {
  if (duration.isNegative) return '0 min';
  if (duration.inDays > 0) {
    final hours = duration.inHours.remainder(24);
    return '${duration.inDays} d $hours h';
  }
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours} h $minutes min';
  }
  return '${duration.inMinutes} min';
}

String formatPercent(num value) => '${(value * 100).round()}%';
