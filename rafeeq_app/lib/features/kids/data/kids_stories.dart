import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/config/app_config.dart';

export 'kids_stories_data.dart';

/// The kids corner's story shelves (owner, 2026-09-30: «قصص الأنبياء والصالحين
/// والصحابة»). A shelf is shown only when it holds at least one story - an
/// empty «coming soon» shelf is not shown.
enum StoryCategory { prophets, righteous, quran, companions }

/// One caption line. Either the narrator's exact words ([text]), or a
/// recitation of (surah, ayah) whose text the player reads from the app's own
/// mushaf database - the catalogue never carries a copy of an ayah.
class StoryCaption {
  final double start;
  final double end;
  final String? text;
  final int? surah;
  final int? ayah;
  const StoryCaption(this.start, this.end, {this.text, this.surah, this.ayah});

  bool get isAyah => surah != null && ayah != null;
}

/// A finished story video: drawn by code, narrated, the Qur'an in it recited
/// by a named reciter (docs/kids_stories/, CONTENT-LICENSES.md). The data is
/// generated from the rendered files by scripts/build_kids_stories.py.
class KidsStory {
  final String id;
  final StoryCategory category;
  final double seconds;
  final int bytes;
  final List<StoryCaption> captions;
  const KidsStory({
    required this.id,
    required this.category,
    required this.seconds,
    required this.bytes,
    required this.captions,
  });

  String get titleKey => 'kids.story_$id';
  String get videoUrl => '${AppConfig.contentBaseUrl}/kids/stories/$id.mp4';
  String get posterUrl => '${AppConfig.contentBaseUrl}/kids/stories/$id.jpg';

  /// DownloadManager id and file name of the offline copy.
  String get downloadId => 'kids_story_$id';
  String get fileName => 'kids_story_$id.mp4';

  StoryCaption? captionAt(double t) {
    for (final c in captions) {
      if (t >= c.start && t < c.end) return c;
    }
    return null;
  }
}

/// The narration lines in the other six languages (CLAUDE.md §1.7c): story id
/// -> language -> one entry per caption, null at each recited ayah. The voice
/// stays Arabic; the line under the picture is in the child's language.
/// Built and checked by scripts/kids_stories/build_captions_tr.py.
Future<Map<String, Map<String, List<String?>>>>? _captionTr;
Future<Map<String, Map<String, List<String?>>>> kidsCaptionTranslations() =>
    _captionTr ??= rootBundle
        .loadString('assets/data/kids_captions_tr.json')
        .then((raw) => {
              for (final s in (jsonDecode(raw) as Map<String, dynamic>).entries)
                s.key: {
                  for (final l in (s.value as Map<String, dynamic>).entries)
                    l.key: [for (final t in l.value as List) t as String?],
                },
            });
