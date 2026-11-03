import 'dart:io';
import 'dart:isolate';

/// Directory scans that run on a background isolate.
///
/// Owner, 2026-11-02: «التطبيق لما بيحمل جيجات كتير ٤٠ او ٥٠ جيجا تحسه
/// بيبطئ». Measured 2026-11-04 on emulator-5554 (debug build) with 21,592
/// downloaded files (80 whole-surah recitations, two per-ayah reciters):
/// the recitation library's start-up scan held the UI isolate for 230 ms,
/// and opening «التنزيلات» for 1,090 ms - every `listSync` and `lengthSync`
/// ran where the frames are drawn. File counts, not gigabytes, set the cost,
/// and a phone's storage is slower than the emulator's. These helpers do
/// the same work off the UI isolate; only plain strings and numbers cross.

/// Total bytes of the files under [path] (recursively unless [recursive] is
/// false), counting only names ending in one of [extensions] (lower case,
/// with the dot) when given. 0 when [path] does not exist.
Future<int> diskBytes(
  String path, {
  bool recursive = true,
  Set<String>? extensions,
}) =>
    Isolate.run(() => _bytes(path, recursive, extensions));

int _bytes(String path, bool recursive, Set<String>? extensions) {
  final dir = Directory(path);
  if (!dir.existsSync()) return 0;
  var total = 0;
  try {
    for (final e in dir.listSync(recursive: recursive, followLinks: false)) {
      if (e is! File) continue;
      if (extensions != null && !extensions.contains(_ext(e.path))) continue;
      try {
        total += e.lengthSync();
      } on FileSystemException {
        // Deleted between the listing and the stat: not on the disk any more.
      }
    }
  } on FileSystemException {
    return total;
  }
  return total;
}

/// The names (not paths) of the files directly inside each of [dirs],
/// keyed by the directory as given. With [nonEmptyOnly], a zero-byte file
/// (a download that died at its first byte) is left out. A missing
/// directory maps to an empty list.
Future<Map<String, List<String>>> fileNamesIn(
  List<String> dirs, {
  bool nonEmptyOnly = false,
}) =>
    Isolate.run(() => {for (final d in dirs) d: fileNamesSync(d, nonEmptyOnly)});

/// The synchronous listing behind [fileNamesIn], for code that is already
/// inside an `Isolate.run` and parses the names there too.
List<String> fileNamesSync(String path, [bool nonEmptyOnly = false]) {
  final dir = Directory(path);
  if (!dir.existsSync()) return const [];
  final out = <String>[];
  try {
    for (final e in dir.listSync(followLinks: false)) {
      if (e is! File) continue;
      if (nonEmptyOnly) {
        try {
          if (e.lengthSync() <= 0) continue;
        } on FileSystemException {
          continue;
        }
      }
      final name = e.uri.pathSegments.last;
      out.add(name);
    }
  } on FileSystemException {
    return out;
  }
  return out;
}

String _ext(String path) {
  final slash = path.lastIndexOf(Platform.pathSeparator);
  final dot = path.lastIndexOf('.');
  return dot > slash ? path.substring(dot).toLowerCase() : '';
}
