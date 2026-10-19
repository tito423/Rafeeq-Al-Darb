import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this phone has the memory «رفيق»'s recogniser needs.
///
/// Measured 2026-10-20 on the API-24 emulator with the omnilingual pack
/// loaded: the app holds ~530 MB (PSS). At 1 GB of RAM the low-memory killer
/// took the launcher, the keyboard and then the app, and Android restarted
/// `AssistantListenService` every 30 s into the same death - a crash loop
/// (TRAPS 76). At 2 GB (MemTotal 2,049,872 kB) it ran with 367 MB still
/// free. A phone sold as «2 GB» reports MemTotal around 1.8-1.9 GB, so the
/// line is drawn at 1.6 GB: every 2 GB phone passes, 1 GB and 1.5 GB phones
/// are told why instead of crashing.
const rafeeqMinMemTotalKb = 1600000;

/// The size the refusal names: the class of phone it needs. Bytes, through
/// formatBytes, never written into the sentence (byte_formatter test).
const rafeeqAdvertisedMinRamBytes = 2000000000;

/// MemTotal from /proc/meminfo, in kB; null where it cannot be read (not
/// Android/Linux, or an unexpected format) - then nothing is refused.
Future<int?> deviceMemTotalKb() async {
  try {
    if (!Platform.isAndroid && !Platform.isLinux) return null;
    for (final line in await File('/proc/meminfo').readAsLines()) {
      if (!line.startsWith('MemTotal:')) continue;
      return int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
    }
  } on FileSystemException {
    // Unreadable: decide nothing.
  }
  return null;
}

/// True when [memTotalKb] is known and below [rafeeqMinMemTotalKb].
bool rafeeqTooLittleMemory(int? memTotalKb) =>
    memTotalKb != null && memTotalKb < rafeeqMinMemTotalKb;

/// MemTotal, read once; it does not change while the app runs.
final deviceMemTotalProvider = FutureProvider<int?>((ref) => deviceMemTotalKb());
