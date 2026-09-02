/// One selectable Adhan sound — either one of the 10 bundled, verified
/// muezzin recordings, or an MP3 the user imported from their own device.
class AdhanOption {
  final String id;
  final String name;

  /// Flutter asset path, used for in-app preview playback (just_audio).
  /// Null for a custom adhan — previewed from [filePath] instead.
  final String? assetPath;

  /// Android raw-resource name (no extension) backing this sound for the
  /// native notification-alarm sound API. Null for a custom adhan — that
  /// case uses a FileProvider content:// URI over [filePath] instead.
  final String? rawResource;

  /// Absolute file path on device storage. Only set for a custom adhan.
  final String? filePath;

  final bool isCustom;
  final String source;

  const AdhanOption({
    required this.id,
    required this.name,
    required this.isCustom,
    this.assetPath,
    this.rawResource,
    this.filePath,
    this.source = '',
  });

  factory AdhanOption.bundled(Map<String, dynamic> json) => AdhanOption(
        id: json['id'] as String,
        name: json['name'] as String,
        assetPath: json['asset'] as String?,
        rawResource: json['raw'] as String?,
        isCustom: false,
        source: json['source'] as String? ?? '',
      );

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
