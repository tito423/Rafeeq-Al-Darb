/// The two prose courses at the foot of the tajweed ladder, read from
/// `assets/data/tajweed/<id>.json.gz`.
///
/// The owner, 2026-10-02: the old ladder (three mutoon) was «كبير جدا وصعب جدا
/// على الاطفال», and he asked for «اسهل وايسر الكتب الكاملة من الشاملة … بتدرج
/// وسهولة … منهج كامل ميسيبش اي حاجة». So the ladder now opens on two
/// complete Shamela books written to teach, not to be memorised:
///
/// * [taysirCourse] — «تيسير أحكام التجويد (المستوى الأول)» of يحيى الغوثاني,
///   written «لصغار الطلبة … على طريقة السؤال والجواب».
/// * [ghayaCourse] — «غاية المريد في علم التجويد» of عطية قابل نصر, the whole
///   science chapter by chapter, each chapter closed by its questions.
///
/// The files are built by `scripts/build_tajweed_courses.py` from the raw
/// Shamela pages kept under `scripts/shamela_raw/`; every Qur'an quotation in
/// them is written from the app's own mushaf text with its surah and ayah
/// (CLAUDE.md §1.2), and `scripts/tajweed_courses_report.txt` lists each one.
library;

import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const taysirCourse = 'taysir_ahkam_al_tajwid_1';
const ghayaCourse = 'ghayat_al_murid';

/// One run of a paragraph.
///
/// [kind]: `t` text, `b` the author's bold lead-in, `h` a bracketed heading
/// inside a line, `q` Qur'an words (mushaf text, [ref] = «surah:ayah»), `n` a
/// footnote pointer, `r` a whole ayah a lost example table pointed to.
class CourseSpan {
  final String kind;
  final String text;
  final String? ref;

  const CourseSpan(this.kind, this.text, [this.ref]);

  bool get isQuran => kind == 'q' || kind == 'r';

  /// (surah, ayah) of a Qur'an span.
  (int, int)? get place {
    final r = ref;
    if (r == null) return null;
    final i = r.indexOf(':');
    if (i < 0) return null;
    final s = int.tryParse(r.substring(0, i));
    final a = int.tryParse(r.substring(i + 1));
    return s == null || a == null ? null : (s, a);
  }
}

/// A paragraph and what it is.
///
/// [kind]: `p` prose, `head` a section heading, `q`/`a` the Taysir's
/// question and answer, `row` a table row (cells split on «\»), `verse` a line
/// of a poem («صدر ... عجز»), `exh`/`ex` a chapter's questions, `notes` the
/// page's footnotes, `refs` the ayahs a lost example table pointed to.
class CourseBlock {
  final String kind;
  final List<CourseSpan> spans;

  const CourseBlock(this.kind, this.spans);

  String get text => spans.map((s) => s.text).join().trim();
}

class CourseLesson {
  final String title;
  final List<CourseBlock> blocks;

  const CourseLesson(this.title, this.blocks);
}

class CourseBook {
  final String id;
  final String title;
  final String author;
  final String edition;
  final String shamelaUrl;
  final List<CourseLesson> lessons;

  const CourseBook({
    required this.id,
    required this.title,
    required this.author,
    required this.edition,
    required this.shamelaUrl,
    required this.lessons,
  });

  factory CourseBook.fromJson(Map<String, dynamic> j) => CourseBook(
        id: j['id'] as String,
        title: j['title'] as String,
        author: j['author'] as String,
        edition: j['edition'] as String,
        shamelaUrl: j['shamelaUrl'] as String,
        lessons: [
          for (final l in (j['lessons'] as List).cast<Map<String, dynamic>>())
            CourseLesson(l['title'] as String, [
              for (final b in (l['blocks'] as List).cast<Map<String, dynamic>>())
                CourseBlock(b['k'] as String, [
                  for (final s in (b['s'] as List).cast<List<dynamic>>())
                    CourseSpan(
                      s[0] as String,
                      s[1] as String,
                      s.length > 2 ? s[2] as String : null,
                    ),
                ]),
            ]),
        ],
      );

  /// Parses the gzip bytes of `assets/data/tajweed/<id>.json.gz`.
  static CourseBook fromGzip(Uint8List bytes) => CourseBook.fromJson(
      jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>);
}

Future<CourseBook> loadCourseBook(String id) async {
  final d = await rootBundle.load('assets/data/tajweed/$id.json.gz');
  final bytes = d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
  // The Ghaya is ~1 MB of JSON: parsed off the UI thread.
  return compute(CourseBook.fromGzip, bytes);
}

final courseBookProvider =
    FutureProvider.family<CourseBook, String>((ref, id) async {
  try {
    return await loadCourseBook(id);
  } catch (e, st) {
    debugPrint('courseBookProvider($id) failed: $e\n$st');
    rethrow;
  }
});

/// Lessons the reader has marked done in one course, kept by TITLE, as the
/// other levels keep theirs.
class CourseProgress extends StateNotifier<Set<String>> {
  final String id;

  CourseProgress(this.id) : super(const {}) {
    _restore();
  }

  String get _key => 'tajweed_course.$id.done_v1';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = {...?prefs.getStringList(_key)};
  }

  Future<void> toggle(String lesson) async {
    final next = {...state};
    next.contains(lesson) ? next.remove(lesson) : next.add(lesson);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}

final courseProgressProvider =
    StateNotifierProvider.family<CourseProgress, Set<String>, String>(
        (ref, id) => CourseProgress(id));
