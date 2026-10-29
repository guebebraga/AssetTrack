int _counter = 0;

String newId(String prefix) {
  _counter += 1;
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return '$prefix-${stamp.toUpperCase()}-${_counter.toString().padLeft(3, '0')}';
}

String nextAssetCode(String prefix, Iterable<String> existingCodes) {
  final normalizedPrefix = prefix.trim().isEmpty
      ? 'ACT'
      : prefix.trim().toUpperCase();
  final pattern = RegExp('^${RegExp.escape(normalizedPrefix)}-(\\d+)\$');
  var max = 0;
  for (final code in existingCodes) {
    final match = pattern.firstMatch(code.toUpperCase());
    if (match != null) {
      final value = int.tryParse(match.group(1)!) ?? 0;
      if (value > max) max = value;
    }
  }
  var candidate = max + 1;
  final codes = existingCodes.map((e) => e.toUpperCase()).toSet();
  while (codes.contains(
    '$normalizedPrefix-${candidate.toString().padLeft(3, '0')}',
  )) {
    candidate += 1;
  }
  return '$normalizedPrefix-${candidate.toString().padLeft(3, '0')}';
}
