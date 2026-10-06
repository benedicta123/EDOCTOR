/// Formate une date ISO de l'API en « 16/09/2026 à 14:30 » ; null → '—'.
String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
}

/// Libellé relatif court : « à l'instant », « il y a 5 min », ou date complète.
String relativeLabel(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.isNegative || diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return formatDateTime(iso);
}

/// Formate le nom d'un médecin pour éviter les doublons « Dr. Dr. »
String doctorDisplay(String name) {
  final clean = name.trim();
  if (clean.isEmpty) return 'Médecin';
  if (clean.toLowerCase().startsWith('dr.') || clean.toLowerCase().startsWith('dr ')) {
    return clean;
  }
  return 'Dr. $clean';
}
