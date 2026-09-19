import '../../data/tts/open_voice.dart';
import '../../data/tts/book_voice_pref.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/toolbar_action.dart';
import '../../data/book_catalog.dart';
import '../../data/book_speaker.dart';
import '../../data/book_text.dart';
import 'open_voice_offer.dart';

/// The reader's «استماع» control, and everything behind it.
///
/// It lives in its own file rather than inside `book_text_reader_screen.dart`
/// because that screen is already over its length ceiling, and because TTS
/// state is not the reader's business: the screen knows which page is open,
/// and this knows how to say it.
///
/// WHAT IT REFUSES TO DO, which is the point of the whole feature:
///
///  * It will not read a book whose text is not vowelled. Arabic without
///    harakat is genuinely ambiguous — one consonantal skeleton is several
///    words — and in a scholarly religious text a wrong vowel is a wrong
///    MEANING. `LibraryBook.canBeSpoken` gates it on `diacritisedPct`, which
///    is measured against the hosted text, not guessed. 83 of 213 pass.
///  * It will not read Qur'an. `pageSpeechText` drops every paragraph
///    Shamela marked as an ayah before the engine sees it, because the
///    Qur'an is recited and this app already carries real recitations by
///    named qurra'.
///
/// A book that fails the gate still shows the button. It explains why there
/// is no audio instead of disappearing, because a missing control reads as a
/// bug and a stated reason reads as a decision.
class BookListenAction extends StatefulWidget {
  const BookListenAction({
    super.key,
    required this.book,
    required this.doc,
    required this.pageIndex,
  });

  final LibraryBook book;
  final BookText doc;
  final int pageIndex;

  @override
  State<BookListenAction> createState() => BookListenActionState();
}

class BookListenActionState extends State<BookListenAction> {
  final BookSpeaker _speaker = BookSpeaker();
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    // Load the enhanced voice while the page is being read (see warmUp).
    if (widget.book.canBeSpoken) {
      BookVoicePref.load().then((v) {
        if (v == BookVoice.open) OpenVoice.instance.warmUp();
      });
    }
  }

  @override
  void didUpdateWidget(BookListenAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Turning the page stops the voice. Letting it read on while the reader
    // is looking at a different page is worse than silence.
    if (oldWidget.pageIndex != widget.pageIndex && _speaking) {
      _speaker.stop();
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  void dispose() {
    _speaker.stop();
    _speaker.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_speaking) {
      await _speaker.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    if (!await offerOpenVoice(context)) return;
    if (!await _speaker.available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('library.text_listen_no_engine'.tr())),
      );
      return;
    }
    final page = widget.doc.pages[widget.pageIndex];
    final text =
        pageSpeechText(page.paras.map((p) => (text: p.text, kind: p.kind)));
    if (text.trim().isEmpty) return;
    if (mounted) setState(() => _speaking = true);
    await _speaker.speak(text);
    if (mounted) setState(() => _speaking = false);
  }

  void _explain() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('library.text_listen_unavailable_title'.tr()),
        content: Text(trn('library.text_listen_unavailable_body',
            args: ['${widget.book.diacritisedPct}'])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }

  /// «مفيش خيار لتبديل صوت القارئ بين الجهاز والموديل … حط خيار في القارئ
  /// عشان أختار بسرعة». The same two voices as Settings → «قارئ الكتب», one
  /// tap away inside the reader; choosing stops the page so the next
  /// «استماع» speaks in the new voice.
  Future<void> _pickVoice() async {
    final current = await BookVoicePref.load();
    final installed = await OpenVoice.isInstalled();
    if (!mounted) return;
    final choice = await showModalBottomSheet<BookVoice>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('library.voice_section_title'.tr(),
                style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final (v, title, sub) in [
            (
              BookVoice.open,
              'library.open_voice_title'.tr(),
              installed
                  ? 'library.voice_open_installed'.tr()
                  : 'library.voice_open_not_installed'
                      .tr(args: [formatBytes(OpenVoice.totalBytes)]),
            ),
            (
              BookVoice.device,
              'library.open_voice_use_device'.tr(),
              'library.voice_device_desc'.tr(),
            ),
          ])
            ListTile(
              leading: Icon(
                v == current
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: v == current ? AppColors.gold : null,
              ),
              title: Text(title),
              subtitle: Text(sub),
              onTap: () => Navigator.of(ctx).pop(v),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || choice == current) return;
    if (_speaking) {
      await _speaker.stop();
      if (mounted) setState(() => _speaking = false);
    }
    if (choice == BookVoice.open && !installed && mounted) {
      await installOpenVoice(context);
      // Cancelled: nothing changes. Sent to the background: the choice
      // stands, and the phone's voice reads until the pack lands.
      if (OpenVoice.wasCancelled) return;
    }
    await BookVoicePref.save(choice);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.book.canBeSpoken;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ToolbarAction(
        icon: _speaking ? Icons.stop_circle_outlined : Icons.headphones_outlined,
        label: _speaking
            ? 'library.text_listen_stop'.tr()
            : 'library.text_listen'.tr(),
        active: _speaking,
        onPressed: on ? _toggle : _explain,
      ),
      if (on)
        ToolbarAction(
          icon: Icons.record_voice_over_outlined,
          label: 'library.voice_short'.tr(),
          onPressed: _pickVoice,
        ),
    ]);
  }
}
