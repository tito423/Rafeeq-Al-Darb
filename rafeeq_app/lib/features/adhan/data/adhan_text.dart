/// The standard Sunni Adhan text, as one canonical liturgical text (like the
/// azkar bundled elsewhere) — not fetched, not user data, so it is not
/// "mock content" under the project's zero-mock-data rule.
///
/// Each line carries how many times it is actually said, so a genuine
/// karaoke highlight can weight longer/rarer lines correctly instead of
/// giving every phrase equal screen time.
class AdhanLine {
  final String text;
  final int repeat;
  const AdhanLine(this.text, this.repeat);
}

List<AdhanLine> adhanLines({required bool isFajr}) => [
      const AdhanLine('الله أكبر', 4),
      const AdhanLine('أشهد أن لا إله إلا الله', 2),
      const AdhanLine('أشهد أن محمداً رسول الله', 2),
      const AdhanLine('حيّ على الصلاة', 2),
      const AdhanLine('حيّ على الفلاح', 2),
      if (isFajr) const AdhanLine('الصلاة خير من النوم', 2),
      const AdhanLine('الله أكبر', 2),
      const AdhanLine('لا إله إلا الله', 1),
    ];
