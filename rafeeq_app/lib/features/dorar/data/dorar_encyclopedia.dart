import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/source_rules.dart';

/// One of al-Durar al-Saniyya's encyclopaedias (dorar.net/`slug`).
class DorarEncyclopedia {
  const DorarEncyclopedia(this.slug, this.titleKey);
  final String slug;
  final String titleKey;
}

/// The encyclopaedias on dorar.net's front page (read 2026-09-26). Each
/// front page carries its whole table of contents.
const dorarEncyclopedias = [
  DorarEncyclopedia('aqeeda', 'dorar.enc_aqeeda'),
  DorarEncyclopedia('feqhia', 'dorar.enc_feqhia'),
  DorarEncyclopedia('qfiqhia', 'dorar.enc_qfiqhia'),
  DorarEncyclopedia('osolfeqh', 'dorar.enc_osolfeqh'),
  // Not listed until each has its own reader: both opened EMPTY on the
  // owner's Xiaomi (2026-09-27). Measured: /tafseer is 114 surah cards
  // (/tafseer/N, split into parts /tafseer/N/M, sections #tt1..), and
  // /history is browsed by era (?era=N) and event (/history/event/N) -
  // neither has the <ul id="mtree"> tree the other nine share.
  // tafseer: its own reader (DorarTafseerScreen), listed by the hub.
  // history: its own reader (DorarHistoryScreen), listed by the hub.
  DorarEncyclopedia('adyan', 'dorar.enc_adyan'),
  DorarEncyclopedia('frq', 'dorar.enc_frq'),
  DorarEncyclopedia('alakhlaq', 'dorar.enc_alakhlaq'),
  DorarEncyclopedia('aadab', 'dorar.enc_aadab'),
  DorarEncyclopedia('arabia', 'dorar.enc_arabia'),
];

/// A node of an encyclopaedia's table of contents: a folder (كتاب، باب،
/// فصل، مبحث، مطلب…) with [children], or a section with an [id].
class DorarTocNode {
  DorarTocNode(this.title, {this.id});
  final String title;
  final int? id;
  final List<DorarTocNode> children = [];
  bool get isSection => id != null;
}

/// One paragraph of a section: a heading or text.
class DorarPara {
  const DorarPara(this.text, {this.heading = false});
  final String text;
  final bool heading;
}

class DorarSection {
  const DorarSection(this.title, this.paras, this.footnotes);
  final String title;
  final List<DorarPara> paras;
  final List<String> footnotes;
}

final _tagRe = RegExp(r'<[^>]+>');
final _wsRe = RegExp(r'\s+');

String _text(String html) => html
    .replaceAll(_tagRe, '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll(_wsRe, ' ')
    .trim();

/// The table of contents: the page's `<ul id="mtree">` tree. A folder is
/// `<li class="mtree-node"><a href="#">title</a><ul>…</ul></li>`, a
/// section `<li><a href="/<slug>/N">title</a></li>`.
List<DorarTocNode> parseDorarToc(String html, String slug) {
  final rules = SourceRules.instance;
  final start = html.indexOf(rules.s('dorar.toc.start'));
  if (start < 0) return const [];
  // From the tree's own opening tag - `id="mtree"` sits inside it.
  final body = html.substring(html.lastIndexOf('<ul', start));
  final token = rules.re('dorar.toc.token');
  final sectionHref = RegExp('^/${RegExp.escape(slug)}/' r'(\d+)$');
  final root = <DorarTocNode>[];
  final stack = <List<DorarTocNode>>[root];
  DorarTocNode? lastFolder;
  var depth = 0;
  for (final m in token.allMatches(body)) {
    final t = m.group(0)!;
    if (t.startsWith('<ul')) {
      depth++;
      if (depth == 1) continue; // the tree's own <ul id="mtree">
      stack.add(lastFolder?.children ?? stack.last);
    } else if (t == '</ul>') {
      depth--;
      if (depth == 0) break; // end of the tree
      if (stack.length > 1) stack.removeLast();
    } else {
      final href = m.group(1)!;
      final title = _text(m.group(2)!);
      if (title.isEmpty) continue;
      final sm = sectionHref.firstMatch(href);
      if (sm != null) {
        stack.last.add(DorarTocNode(title, id: int.parse(sm.group(1)!)));
      } else if (href == '#') {
        lastFolder = DorarTocNode(title);
        stack.last.add(lastFolder);
      }
    }
  }
  return root;
}

/// A section page -> title, paragraphs, footnotes. The content is the block
/// after `<div class="w-100 mt-4">` up to «انظر أيضا». Headings are
/// `title-1`/`title-2` spans; footnotes are `<span class="tip">`, lifted
/// out and numbered. Text is Dorar's own (ayahs stay inline between ﴿ ﴾).
/// Null when the page is not a section (an unknown id answers 200 with the
/// generic page - a soft 404, trap #5).
DorarSection? parseDorarSection(String html) {
  final rules = SourceRules.instance;
  final startMarker = rules.s('dorar.section.start');
  final a = html.indexOf(startMarker);
  if (a < 0) return null;
  var b = html.indexOf(rules.s('dorar.section.end'), a);
  if (b >= 0) b = html.lastIndexOf('<h3', b); // from the tag's start
  if (b < 0) b = html.indexOf(rules.s('dorar.section.end_alt'), a);
  if (b < 0) b = html.length;
  var body = html.substring(a + startMarker.length, b);
  final qa = body.indexOf(rules.s('dorar.section.end_alt'));
  if (qa >= 0) body = body.substring(0, qa);
  // The section's own <h1> is inside the content card (`id="cntnt"`); the
  // first <h1> of the page is the site header («الموسوعة العقدية»).
  final card = html.indexOf(rules.s('dorar.section.card'));
  final titleM = rules
      .re('dorar.section.title')
      .firstMatch(card < 0 ? html : html.substring(card));
  final title = titleM == null ? '' : _text(titleM.group(1)!);

  final footnotes = <String>[];
  // The end-of-section control (a popover button) is dropped in _bodyParas.
  final paras = _bodyParas(body, footnotes);
  return DorarSection(title, paras, footnotes);
}

/// One surah card on /tafseer (read 2026-09-27: 114 cards,
/// `<a href="/tafseer/N"><strong>سورة …</strong></a>`).
class DorarSurahRef {
  const DorarSurahRef(this.number, this.title);
  final int number;
  final String title;
}

List<DorarSurahRef> parseDorarTafseerSurahs(String html) => [
      for (final m in SourceRules.instance
          .re('dorar.tafseer.surah')
          .allMatches(html))
        DorarSurahRef(int.parse(m.group(1)!), _text(m.group(2)!)),
    ];

/// A page of the Tafseer encyclopaedia: a surah's introduction
/// (/tafseer/N) or a range of its ayahs (/tafseer/N/M). There is no list of
/// the parts: each page links only to the one before and after it
/// («السابق» / «التالي»), across surahs too, so the reader follows that chain.
class DorarChainPage {
  const DorarChainPage(this.title, this.paras, this.footnotes,
      {this.prev, this.next});
  final String title;
  final List<DorarPara> paras;
  final List<String> footnotes;

  /// Site paths («/tafseer/2/1»), null at either end.
  final String? prev;
  final String? next;
}

/// Each section is an `<article>` whose `<h5>` is its heading («تفسير
/// الآيات:», «غريب الكلمات:» …); footnotes are the same `span.tip` as the
/// other encyclopaedias. Null when the page has no article (soft 404).
DorarChainPage? parseDorarChainPage(String html, String slug) {
  final rules = SourceRules.instance;
  final articles = rules.re('dorar.chain.article').allMatches(html).toList();
  if (articles.isEmpty) return null;
  final t = rules.re('dorar.chain.title').firstMatch(html);
  var title = t == null ? '' : _text(t.group(1)!);
  final dash = title.lastIndexOf(' - ');
  if (dash >= 0) title = title.substring(dash + 3).trim();
  final footnotes = <String>[];
  final paras = <DorarPara>[];
  for (final a in articles) {
    var body = a.group(1)!;
    final h = rules.re('dorar.chain.heading').firstMatch(body);
    if (h != null) {
      final head = _text(h.group(1)!).replaceFirst(RegExp(r':\s*$'), '');
      if (head.isNotEmpty) paras.add(DorarPara(head, heading: true));
      body = body.replaceRange(h.start, h.end, '');
    }
    paras.addAll(_bodyParas(body, footnotes));
  }
  String? link(String label) {
    for (final m in rules.re('dorar.chain.link').allMatches(html)) {
      if (_text(m.group(2)!) == label &&
          m.group(1)!.startsWith('/$slug/')) {
        return m.group(1);
      }
    }
    return null;
  }

  return DorarChainPage(title, paras, footnotes,
      prev: link(rules.s('dorar.chain.prev')),
      next: link(rules.s('dorar.chain.next')));
}

/// A section body's paragraphs, with its footnotes lifted into [footnotes]
/// and replaced by their number - shared by the section and chain pages.
List<DorarPara> _bodyParas(String body, List<String> footnotes) {
  final rules = SourceRules.instance;
  body = body.replaceAllMapped(rules.re('dorar.section.footnote'), (m) {
    final note = _text(m.group(1)!).replaceFirst(RegExp(r'^\[\d+\]\s*'), '');
    footnotes.add(note);
    return ' (${footnotes.length}) ';
  });
  body = body.replaceAllMapped(
    rules.re('dorar.section.heading'),
    (m) => '<br/>\u0001${m.group(1)}<br/>',
  );
  body = body.replaceAll(rules.re('dorar.section.drop'), '');
  final paras = <DorarPara>[];
  for (final chunk in body.split(RegExp(r'<br\s*/?>|</p>|<p[^>]*>'))) {
    final heading = chunk.contains('\u0001');
    final t = _text(chunk.replaceAll('\u0001', '')).replaceAll(' .', '.');
    if (t.isEmpty || t == '.') continue;
    paras.add(DorarPara(t, heading: heading));
  }
  return paras;
}

/// One event of the History encyclopaedia, as its era page lists it (the
/// page carries every event's whole text in an accordion - 20 a page,
/// `?era=N&page=M`; measured 2026-09-27).
class DorarHistoryEvent {
  const DorarHistoryEvent(
      this.id, this.title, this.hijri, this.gregorian, this.details);
  final int id;
  final String title;
  final String hijri;
  final String gregorian;
  final List<String> details;
}

class DorarHistoryPage {
  const DorarHistoryPage(this.events, this.lastPage);
  final List<DorarHistoryEvent> events;
  final int lastPage;
}

/// The eras on /history («عصر النبوة» …), `?era=N`.
List<DorarSurahRef> parseDorarHistoryEras(String html) {
  final seen = <int>{};
  return [
    for (final m in SourceRules.instance.re('dorar.history.era').allMatches(html))
      if (seen.add(int.parse(m.group(1)!)))
        DorarSurahRef(int.parse(m.group(1)!), _text(m.group(2)!)),
  ];
}

DorarHistoryPage parseDorarHistoryPage(String html) {
  final rules = SourceRules.instance;
  final events = <DorarHistoryEvent>[
    for (final m in rules.re('dorar.history.event').allMatches(html))
      DorarHistoryEvent(
        int.parse(m.group(5)!),
        _text(m.group(1)!).replaceFirst(RegExp(r'\s*\.$'), ''),
        _text(m.group(2)!),
        _text(m.group(3)!),
        [
          for (final para
              in m.group(4)!.split(RegExp(r'<br\s*/?>|</p>\s*<p[^>]*>')))
            if (_text(para).isNotEmpty) _text(para),
        ],
      ),
  ];
  var last = 1;
  for (final m in rules.re('dorar.history.page').allMatches(html)) {
    final n = int.parse(m.group(1)!);
    if (n > last) last = n;
  }
  return DorarHistoryPage(events, last);
}

/// Reads dorar.net on demand. A table of contents or a section once read is
/// kept on the phone (app support `dorar/`), so it opens again without the
/// network - a reader's cache, not a copy of the site («جميع الحقوق محفوظة
/// لمؤسسة الدرر السنية»; see DORAR_ISLAMQA_NOTES.md).
class DorarEncyclopediaService {
  DorarEncyclopediaService._();
  static final DorarEncyclopediaService instance = DorarEncyclopediaService._();

  final Dio _dio = Dio();

  Future<File> _cache(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'dorar', name));
  }

  Future<String> _get(String path, String cacheName, {Duration? maxAge}) async {
    final f = await _cache(cacheName);
    if (f.existsSync() &&
        (maxAge == null ||
            DateTime.now().difference(f.lastModifiedSync()) < maxAge)) {
      return utf8.decode(gzip.decode(await f.readAsBytes()));
    }
    try {
      final res = await _dio.get<String>(
        'https://dorar.net$path',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': 'RafeeqAlDarb (Android; personal library)'},
          receiveTimeout: const Duration(seconds: 40),
        ),
      );
      final html = res.data ?? '';
      await f.parent.create(recursive: true);
      await f.writeAsBytes(gzip.encode(utf8.encode(html)));
      return html;
    } catch (_) {
      if (f.existsSync()) return utf8.decode(gzip.decode(await f.readAsBytes()));
      rethrow;
    }
  }

  /// The table of contents, refreshed weekly.
  Future<List<DorarTocNode>> toc(String slug) async => parseDorarToc(
        await _get('/$slug', '$slug.toc.html.gz',
            maxAge: const Duration(days: 7)),
        slug,
      );

  Future<DorarSection?> section(String slug, int id) async =>
      parseDorarSection(await _get('/$slug/$id', '$slug.$id.html.gz'));

  /// The 114 surah cards of the Tafseer encyclopaedia, refreshed weekly.
  Future<List<DorarSurahRef>> tafseerSurahs() async =>
      parseDorarTafseerSurahs(await _get('/tafseer', 'tafseer.toc.html.gz',
          maxAge: const Duration(days: 7)));

  /// A page of a chained encyclopaedia by its site path («/tafseer/2/1»).
  Future<DorarChainPage?> chainPage(String path, String slug) async =>
      parseDorarChainPage(
          await _get(path, '${path.substring(1).replaceAll('/', '.')}.html.gz'),
          slug);

  /// The History encyclopaedia's eras, refreshed weekly.
  Future<List<DorarSurahRef>> historyEras() async => parseDorarHistoryEras(
      await _get('/history', 'history.eras.html.gz',
          maxAge: const Duration(days: 7)));

  /// One page (20 events) of an era, refreshed weekly.
  Future<DorarHistoryPage> historyPage(int era, int page) async =>
      parseDorarHistoryPage(await _get('/history?era=$era&page=$page',
          'history.$era.$page.html.gz',
          maxAge: const Duration(days: 7)));

  String url(String slug, [int? id]) =>
      id == null ? 'https://dorar.net/$slug' : 'https://dorar.net/$slug/$id';
}
