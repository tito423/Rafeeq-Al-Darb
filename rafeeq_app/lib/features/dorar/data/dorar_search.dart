import '../../../core/utils/arabic_normalize.dart';
import 'dorar_encyclopedia.dart';

/// One searchable section of an encyclopaedia's contents.
class DorarSectionHit {
  const DorarSectionHit(this.encyclopedia, this.id, this.title, this.path);
  final DorarEncyclopedia encyclopedia;
  final int id;
  final String title;

  /// The folders above it («كتاب الطهارة › باب المياه»), for the result line.
  final String path;
}

/// Every section of [nodes], with the folders it sits in.
List<(DorarSectionHit, String)> flattenDorarToc(
    DorarEncyclopedia e, List<DorarTocNode> nodes) {
  final out = <(DorarSectionHit, String)>[];
  void walk(List<DorarTocNode> level, List<String> above) {
    for (final n in level) {
      if (n.isSection) {
        final path = above.join(' › ');
        out.add((
          DorarSectionHit(e, n.id!, n.title, path),
          _norm('${n.title} $path'),
        ));
      }
      if (n.children.isNotEmpty) walk(n.children, [...above, n.title]);
    }
  }

  walk(nodes, const []);
  return out;
}

String _norm(String s) => normalizeArabicLoose(normalizeArabic(s));

/// Owner, 2026-09-27: «بحث عام في الدرر كلها زي ما انت عامل في الشاملة» -
/// one search over the contents of every encyclopaedia, like the Shamela
/// title search: local, instant once the contents are on the phone.
///
/// Best first: the section title itself, then titles starting with the
/// query, then titles holding every word, then title + folders holding
/// every word (so «المياه الطهارة» finds a section under كتاب الطهارة).
List<DorarSectionHit> searchDorarSections(
    List<(DorarSectionHit, String)> all, String query,
    {int limit = 200}) {
  final q = _norm(query.trim());
  if (q.isEmpty) return const [];
  final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final ranked = <(int, DorarSectionHit)>[];
  for (final (hit, both) in all) {
    final title = _norm(hit.title);
    final int rank;
    if (title == q) {
      rank = 0;
    } else if (title.startsWith(q)) {
      rank = 1;
    } else if (words.every(title.contains)) {
      rank = 2;
    } else if (words.every(both.contains)) {
      rank = 3;
    } else {
      continue;
    }
    ranked.add((rank, hit));
  }
  ranked.sort((a, b) {
    final r = a.$1.compareTo(b.$1);
    return r != 0 ? r : a.$2.title.length.compareTo(b.$2.title.length);
  });
  return [for (final r in ranked.take(limit)) r.$2];
}
