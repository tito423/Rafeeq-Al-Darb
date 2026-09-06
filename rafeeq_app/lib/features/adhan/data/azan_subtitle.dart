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
