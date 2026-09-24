import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/utils/digits.dart';
import '../../data/tts/book_voice_pref.dart';
import '../../data/tts/open_voice.dart';

/// Offers the open reader voice before the first «استماع» without it.
///
/// The phone's own Arabic voices do not give the divine name its tafkhim —
/// measured, not heard: the vowel after the lam of «الله» sits at F2 ≈
/// 1450–1600 Hz in Google's voices against 972 Hz in al-Minshawi's
/// recitation, and 1232 Hz in this voice. The owner called the plain one
/// unusable for a religious reader, so the better voice is offered up front,
/// with its real size, and the phone's voice stays as the answer for anyone
/// who will not spend ~252 MB on it.
///
/// Returns true when the reader should go on and read (in whichever voice
/// is now available), false when the user cancelled.
Future<bool> offerOpenVoice(BuildContext context) async {
  if (await BookVoicePref.load() == BookVoice.device ||
      await OpenVoice.isInstalled()) {
    return true;
  }
  if (!context.mounted) return false;
  // Already downloading (sent to the background earlier): not offered
  // again as if nothing had started - its progress is shown instead.
  if (OpenVoice.installProgress.value != null) {
    return installOpenVoice(context);
  }
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('library.open_voice_title'.tr()),
      content: Text('library.open_voice_body'
          .tr(args: [formatBytes(OpenVoice.totalBytes)])),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('device'),
          child: Text('library.open_voice_use_device'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop('download'),
          child: Text('library.open_voice_download'.tr()),
        ),
      ],
    ),
  );
  if (choice == 'device') {
    // Remembered, not asked again on every page: Settings → «قارئ الكتب»
    // is where it is changed back.
    await BookVoicePref.save(BookVoice.device);
    return true;
  }
  if (choice != 'download' || !context.mounted) return false;
  return installOpenVoice(context);
}

/// The enhanced voice's state in words, for every place that lists it:
/// downloading with its percentage, installed, or its size to download.
String openVoiceStatus() {
  final p = OpenVoice.installProgress.value;
  if (p != null) return '${'downloads.downloading'.tr()}  ${percentOf(p)}';
  return OpenVoice.installed.value == true
      ? 'library.voice_open_installed'.tr()
      : 'library.voice_open_not_installed'
          .tr(args: [formatBytes(OpenVoice.totalBytes)]);
}

/// Rebuilds when the enhanced voice starts, progresses or finishes.
final openVoiceChanges =
    Listenable.merge([OpenVoice.installProgress, OpenVoice.installed]);

/// Downloads the pack behind a progress dialog. True once it is installed;
/// false if it failed or the user sent it to the background.
Future<bool> installOpenVoice(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _InstallDialog(),
    ) ??
    false;

class _InstallDialog extends StatefulWidget {
  const _InstallDialog();

  @override
  State<_InstallDialog> createState() => _InstallDialogState();
}

class _InstallDialogState extends State<_InstallDialog> {
  int _done = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await OpenVoice.install((d, _) {
        if (mounted) setState(() => _done = d);
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // Closing the connection to cancel surfaces as a network error; the
      // flag says it was the reader, not the network.
      if (OpenVoice.wasCancelled) {
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = OpenVoice.totalBytes;
    return AlertDialog(
      title: Text('library.open_voice_title'.tr()),
      content: _error != null
          ? Text('library.open_voice_failed'.tr())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: _done / total),
                const SizedBox(height: 12),
                Text(ratio(formatBytes(_done), formatBytes(total))),
              ],
            ),
      actions: [
        // The download carries on after the dialog closes (OpenVoice keeps
        // one install in flight), so nobody is held on a progress bar.
        if (_error == null)
          TextButton(
            onPressed: OpenVoice.cancelInstall,
            child: Text('common.cancel'.tr()),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_error != null
              ? 'common.ok'.tr()
              : 'library.open_voice_hide'.tr()),
        ),
      ],
    );
  }
}
