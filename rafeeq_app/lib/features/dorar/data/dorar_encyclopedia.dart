import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  DorarEncyclopedia('tafseer', 'dorar.enc_tafseer'),
  DorarEncyclopedia('history', 'dorar.enc_history'),
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
  final start = html.indexOf('id="mtree"');
  if (start < 0) return const [];
  // From the tree's own opening tag - `id="mtree"` sits inside it.
  final body = html.substring(html.lastIndexOf('<ul', start));
  final token = RegExp(
    r'<ul\b|</ul>|<a\s+href="([^"]*)"[^>]*>(.*?)</a>',
    dotAll: true,
  );
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
  final a = html.indexOf('<div class="w-100 mt-4">');
  if (a < 0) return null;
  var b = html.indexOf('id="more-titles"', a);
  if (b >= 0) b = html.lastIndexOf('<h3', b); // from the tag's start
  if (b < 0) b = html.indexOf('public-qa-section', a);
  if (b < 0) b = html.length;
  var body = html.substring(a + '<div class="w-100 mt-4">'.length, b);
  final qa = body.indexOf('public-qa-section');
  if (qa >= 0) body = body.substring(0, qa);
  // The section's own <h1> is inside the content card (`id="cntnt"`); the
  // first <h1> of the page is the site header («الموسوعة العقدية»).
  final card = html.indexOf('id="cntnt"');
  final titleM = RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true)
      .firstMatch(card < 0 ? html : html.substring(card));
  final title = titleM == null ? '' : _text(titleM.group(1)!);

  final footnotes = <String>[];
  body = body.replaceAllMapped(
    RegExp(r'<span class="tip">(.*?)</span>', dotAll: true),
    (m) {
      final note = _text(m.group(1)!).replaceFirst(RegExp(r'^\[\d+\]\s*'), '');
      footnotes.add(note);
      return ' (${footnotes.length}) ';
    },
  );
  body = body.replaceAllMapped(
    RegExp(r'<span class="title-\d">(.*?)</span>', dotAll: true),
    (m) => '<br/>\u0001${m.group(1)}<br/>',
  );
  // The end-of-section control (a popover button) is not content.
  body = body.replaceAll(RegExp(r'<a id="enc-tip".*?</a>', dotAll: true), '');
  final paras = <DorarPara>[];
  for (final chunk in body.split(RegExp(r'<br\s*/?>|</p>|<p[^>]*>'))) {
    final heading = chunk.contains('\u0001');
    final t = _text(chunk.replaceAll('\u0001', '')).replaceAll(' .', '.');
    if (t.isEmpty || t == '.') continue;
    paras.add(DorarPara(t, heading: heading));
  }
  return DorarSection(title, paras, footnotes);
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

  String url(String slug, [int? id]) =>
      id == null ? 'https://dorar.net/$slug' : 'https://dorar.net/$slug/$id';
}
