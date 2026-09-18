/// One selectable Adhan sound — either one of the 10 bundled, verified
/// muezzin recordings, or an MP3 the user imported from their own device.
class AdhanOption {
  final String id;
  final String name;

  /// Flutter asset path, used for in-app preview playback (just_audio).
  /// Null for a custom adhan — previewed from [filePath] instead.
  final String? assetPath;

  /// Android raw-resource name (no extension) backing this sound for the
  /// native adhan player. Null for a custom adhan — that case is played
  /// straight from [filePath].
  final String? rawResource;

  /// Absolute file path on device storage. Only set for a custom adhan.
  final String? filePath;

  final bool isCustom;
  final String source;
  final String? url;

  /// A Fajr recording — one that really recites «الصلاة خير من النوم».
  /// Established by listening with speech recognition
  /// (`scripts/align_adhan_phrases.py`), not by a file name: one archive.org
  /// file named «fajr» turned out not to contain the line at all.
  final bool isFajr;

  /// For an ordinary recording: the id of the SAME muezzin's Fajr adhan, when
  /// the catalogue has one. Fajr then sounds in the voice the user picked
  /// instead of a stranger's, and never without its Fajr line.
  final String? fajrPair;

  const AdhanOption({
    required this.id,
    required this.name,
    required this.isCustom,
    this.assetPath,
    this.rawResource,
    this.filePath,
    this.source = '',
    this.url,
    this.isFajr = false,
    this.fajrPair,
  });

  factory AdhanOption.bundled(Map<String, dynamic> json) => AdhanOption(
        id: json['id'] as String,
        name: json['name'] as String,
        assetPath: json['asset'] as String?,
        rawResource: json['raw'] as String?,
        isCustom: false,
        source: json['source'] as String? ?? '',
        url: json['url'] as String?,
        isFajr: json['fajr'] as bool? ?? false,
        fajrPair: json['fajr_pair'] as String?,
      );

  /// Whether this recording may sound for [prayerKey]. A Fajr adhan only at
  /// Fajr, an ordinary one never at Fajr — «الصلاة خير من النوم» is part of
  /// the Fajr adhan and of no other. A file the user imported is theirs to
  /// place; the app cannot hear what it contains.
  bool fitsPrayer(String prayerKey) =>
      isCustom || isFajr == (prayerKey == 'fajr');

  factory AdhanOption.custom({
    required String id,
    required String name,
    required String filePath,
  }) =>
      AdhanOption(
        id: id,
        name: name,
        filePath: filePath,
        isCustom: true,
      );

  Map<String, dynamic> toCustomJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
      };
}
