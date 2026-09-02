/// How a single prayer's Adhan alert behaves. One of these four — never a
/// fifth "off" state; WORK_QUEUE Stage 1 asks for exactly these four modes,
/// each still producing an ongoing, dismissible notification.
enum AdhanMode {
  /// Full adhan audio + the full-screen karaoke view (wakes a locked screen).
  full,

  /// Full adhan audio, ordinary notification — no full-screen takeover.
  audio,

  /// No sound, device vibrates.
  vibrate,

  /// No sound, no vibration — a quiet, honest reminder only.
  silent;

  /// Localization key for this mode's label (`prayer.mode_*` in
  /// assets/translations).
  String get trKey => 'prayer.mode_$name';

  static AdhanMode fromName(String? value) => AdhanMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => AdhanMode.full,
      );
}
