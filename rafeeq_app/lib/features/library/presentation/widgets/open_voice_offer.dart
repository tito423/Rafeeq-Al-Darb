import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/byte_formatter.dart';
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
  if (_declinedThisSession || await OpenVoice.isInstalled()) return true;
  if (!context.mounted) return false;
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
    _declinedThisSession = true;
    return true;
  }
  if (choice != 'download' || !context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _InstallDialog(),
      ) ??
      false;
}

/// Asked once per run: someone who chose the phone's voice is not asked
/// again on every page turn.
bool _declinedThisSession = false;

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
