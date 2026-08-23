/// Text sanitizer for Arabic Islamic texts (Azkar, Duas, Hadiths, Quran details)
class TextSanitizer {
  TextSanitizer._();

  static String clean(String? input) {
    if (input == null || input.isEmpty) return '';

    String s = input.replaceAll('\xa0', ' ');

    // Strip raw escaped newline artifacts
    s = s.replaceAll(r'\n', '\n');
    s = s.replaceAll(RegExp(r"['""],\s*['""]"), ' ');

    // Convert (( )) to « »
    s = s.replaceAll(RegExp(r'\(\(\s*'), '«');
    s = s.replaceAll(RegExp(r'\s*\)\)'), '»');

    // Split lines and drop pure punctuation / quote lines
    final lines = s.split('\n');
    final cleanedLines = <String>[];
    for (final line in lines) {
      String l = line.trim();
      if (l.isEmpty) continue;
      if (l == "'" || l == '"' || l == ',' || l == '.' || l == "','" || l == '","' || l == "''" || l == '""' || l == '-' || l == '—') {
        continue;
      }
      
      // Trim quotes and punctuation from edges
      while (l.isNotEmpty && (l.startsWith("'") || l.startsWith('"') || l.startsWith(','))) {
        l = l.substring(1).trim();
      }
      while (l.isNotEmpty && (l.endsWith("'") || l.endsWith('"') || l.endsWith(','))) {
        l = l.substring(0, l.length - 1).trim();
      }

      if (l.isNotEmpty) {
        cleanedLines.add(l.replaceAll(RegExp(r'[ \t]+'), ' '));
      }
    }

    String result = cleanedLines.join('\n').trim();
    result = result.replaceAll(RegExp(r'^«\s*«'), '«');
    result = result.replaceAll(RegExp(r'»\s*»$'), '»');
    result = result.replaceAll(RegExp(r'^»'), '');
    result = result.replaceAll(RegExp(r'«$'), '');
    return result.trim();
  }
}
