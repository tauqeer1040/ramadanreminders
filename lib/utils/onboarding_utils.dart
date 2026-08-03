List<String> extractVerses(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  final refs = <String>{};
  for (final match in RegExp(r'(\d+:\d+)').allMatches(raw)) {
    refs.add(match.group(1)!);
  }
  return refs.toList();
}
