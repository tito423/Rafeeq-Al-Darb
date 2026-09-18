import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/byte_formatter.dart';
import '../../data/tts/book_voice_pref.dart';
import '../../data/tts/open_voice.dart';
import 'open_voice_offer.dart';

/// Settings → «قارئ الكتب»: which voice reads a book aloud.
///
/// Two real choices, both working: the downloadable enhanced voice (tafkhim
/// of the divine name, 252 MB) and the phone's own male Arabic voice, which
/// the owner asked to keep as an option in its own right. Choosing the
/// enhanced voice before it is installed downloads it right here; removing
/// it is on the Downloads screen with every other pack.
class BookVoiceSection extends StatefulWidget {
  const BookVoiceSection({super.key});

  @override
  State<BookVoiceSection> createState() => _BookVoiceSectionState();
}

class _BookVoiceSectionState extends State<BookVoiceSection> {
  BookVoice? _voice;
  bool _installed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final v = await BookVoicePref.load();
    final i = await OpenVoice.isInstalled();
    if (!mounted) return;
    setState(() {
      _voice = v;
      _installed = i;
    });
  }

  Future<void> _choose(BookVoice v) async {
    if (v == BookVoice.open && !_installed) {
      await installOpenVoice(context);
    }
    await BookVoicePref.save(v);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faint = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final voice = _voice;
    if (voice == null) return const SizedBox.shrink();

    Widget option(BookVoice v, String title, String subtitle) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            v == voice
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: v == voice ? theme.colorScheme.primary : null,
          ),
          title: Text(title),
          subtitle: Text(subtitle, style: faint),
          onTap: () => _choose(v),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            option(
              BookVoice.open,
              'library.open_voice_title'.tr(),
              _installed
                  ? 'library.voice_open_installed'.tr()
                  : 'library.voice_open_not_installed'
                      .tr(args: [formatBytes(OpenVoice.totalBytes)]),
            ),
            option(
              BookVoice.device,
              'library.open_voice_use_device'.tr(),
              'library.voice_device_desc'.tr(),
            ),
            if (voice == BookVoice.open && !_installed) ...[
              const SizedBox(height: 4),
              Text('library.voice_open_fallback_note'.tr(), style: faint),
            ],
          ],
        ),
      ),
    );
  }
}
