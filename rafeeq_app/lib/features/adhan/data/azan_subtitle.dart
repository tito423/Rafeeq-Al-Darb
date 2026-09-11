import 'adhan_text.dart';

/// P3‑52: one timed subtitle line for the full-screen Azan player — the text
/// to show, and the window [startTime, endTime) it's visible for.
class AzanSubtitle {
  final String text;
  final Duration startTime;
  final Duration endTime;

  const AzanSubtitle({
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  bool contains(Duration pos) => pos >= startTime && pos < endTime;
}

/// Builds the subtitle timeline for a full adhan.
///
/// Rather than hard-code per-phrase seconds (which would drift against every
/// muezzin's own pacing — a 2.5-minute recording vs a 4-minute one), the
/// canonical [adhanLines] are distributed across the recording's *real*
/// [total] duration, weighted by each phrase's length × how many times it is
/// said. The screen feeds this the actual duration reported by the audio
/// player, so the subtitles track the real audio second-by-second regardless
/// of which muezzin is playing. [total] may be a sensible estimate before the
/// player has reported its real duration.
List<AzanSubtitle> buildAzanSubtitles({
  required bool isFajr,
  required Duration total,
}) {
  final lines = adhanLines(isFajr: isFajr);
  final weights = lines.map((l) => l.text.length * l.repeat).toList();
  final totalWeight = weights.fold<int>(0, (a, b) => a + b);
  if (totalWeight == 0) return const [];

  final out = <AzanSubtitle>[];
  var accMs = 0;
  for (var i = 0; i < lines.length; i++) {
    final startMs = (total.inMilliseconds * accMs / totalWeight).round();
    accMs += weights[i];
    final endMs = (total.inMilliseconds * accMs / totalWeight).round();
    out.add(AzanSubtitle(
      text: lines[i].text,
      startTime: Duration(milliseconds: startMs),
      endTime: Duration(milliseconds: endMs),
    ));
  }
  return out;
}

/// Where one recording speaks — `assets/data/catalogs/adhan_phrase_timings.json`,
/// measured by `scripts/measure_adhan_phrases.py` with ffmpeg's silencedetect.
class AdhanTimings {
  final int totalMs;
  final int firstSpeechMs;
  final int lastSpeechMs;

  /// Start of each subtitle line, when the recording's breaths matched the
  /// adhan's exactly; null when they did not.
  final List<int>? lines;
  final bool linesAreFajr;

  const AdhanTimings({
    required this.totalMs,
    required this.firstSpeechMs,
    required this.lastSpeechMs,
    this.lines,
    this.linesAreFajr = false,
  });

  factory AdhanTimings.fromJson(Map<String, dynamic> j) {
    final fajr = j['lines_fajr'] as List<dynamic>?;
    final plain = j['lines'] as List<dynamic>?;
    return AdhanTimings(
      totalMs: (j['total_ms'] as num).toInt(),
      firstSpeechMs: (j['first_speech_ms'] as num).toInt(),
      lastSpeechMs: (j['last_speech_ms'] as num).toInt(),
      lines: [for (final v in fajr ?? plain ?? const []) (v as num).toInt()],
      linesAreFajr: fajr != null,
    );
  }
}

/// The adhan's lines laid over what the muezzin actually recites.
///
/// «ظهور النص بتاع الأذان ساعات بيقدّم أو يتأخر عن الأذان نفسه». The
/// proportional timing above shares the WHOLE recording out by letters —
/// opening silence, closing silence and a muezzin's long holds included — so
/// the words drifted ahead and behind. With measured line starts the text
/// changes when the muezzin begins the line; without them (a recording whose
/// breaths did not match, or a Fajr text over a non-Fajr recording), the
/// proportional share is laid over the span he speaks, not over the silence.
///
/// [total] is the duration the player reports; the measured milliseconds are
/// scaled to it, so a re-encode that shifted the length a little still lines up.
List<AzanSubtitle> buildAzanSubtitlesMeasured({
  required bool isFajr,
  required Duration total,
  required AdhanTimings timings,
}) {
  final lines = adhanLines(isFajr: isFajr);
  final scale = timings.totalMs <= 0 ? 1.0 : total.inMilliseconds / timings.totalMs;
  final measured = timings.lines;
  if (measured != null &&
      measured.length == lines.length &&
      timings.linesAreFajr == isFajr) {
    return [
      for (var i = 0; i < lines.length; i++)
        AzanSubtitle(
          text: lines[i].text,
          startTime: Duration(milliseconds: (measured[i] * scale).round()),
          endTime: Duration(
            milliseconds: ((i + 1 < measured.length ? measured[i + 1] : timings.lastSpeechMs + 1500) * scale)
                .round(),
          ),
        ),
    ];
  }
  final start = (timings.firstSpeechMs * scale).round();
  final end = (timings.lastSpeechMs * scale).round();
  final span = buildAzanSubtitles(isFajr: isFajr, total: Duration(milliseconds: end - start));
  return [
    for (final s in span)
      AzanSubtitle(
        text: s.text,
        startTime: s.startTime + Duration(milliseconds: start),
        endTime: s.endTime + Duration(milliseconds: start),
      ),
  ];
}
