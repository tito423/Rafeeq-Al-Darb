import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/fitted_sheet.dart';
import '../../../../core/widgets/toolbar_action.dart';
import '../../data/book_catalog.dart';
import '../../data/book_read_aloud.dart';
import '../../data/book_speaker.dart';
import '../../data/book_text.dart';
import '../../data/tts/book_voice_pref.dart';
import '../../data/tts/open_voice.dart';
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
    required this.aloud,
    this.onTurnPage,
  });

  final LibraryBook book;
  final BookText doc;
  final int pageIndex;

  /// The listening session: the screen owns it, because the page it shows
  /// lights the sentence being read and the player bar drives it.
  final BookReadAloud aloud;

  /// Turns the reader to a page (for «استكمال من حيث توقفت»).
  final ValueChanged<int>? onTurnPage;

  @override
  State<BookListenAction> createState() => BookListenActionState();
}

class BookListenActionState extends State<BookListenAction> {
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

  // Turning the page by hand no longer stops the voice: «قارئ الكتب سئ
  // جدا» (2026-11-01) was partly that a glance at the next page silenced
  // it. The player bar offers the way back to the sentence being read.

  Future<void> _toggle() async {
    final aloud = widget.aloud;
    if (aloud.active) {
      await aloud.stop();
      return;
    }
    if (!await offerOpenVoice(context)) return;
    final probe = BookSpeaker();
    final can = await probe.available;
    probe.dispose();
    if (!can) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('library.text_listen_no_engine'.tr())),
      );
      return;
    }
    final saved = await aloud.savedPoint();
    if (!mounted) return;
    final choice = await _askScope(saved);
    if (choice == null || !mounted) return;
    if (choice == _Scope.resume && saved != null) {
      widget.onTurnPage?.call(saved.$1);
      await aloud.start(widget.doc, saved.$1, toEnd: true, chunk: saved.$2);
    } else {
      await aloud.start(widget.doc, widget.pageIndex,
          toEnd: choice == _Scope.book);
    }
  }

  /// Resume, on to the end of the book, or this page only. Null if
  /// dismissed.
  Future<_Scope?> _askScope((int, int)? saved) => showFittedSheet<_Scope>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saved != null && saved.$1 < widget.doc.pages.length)
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: Text('library.listen_resume'.tr()),
              subtitle: Text(trn('library.listen_resume_desc',
                  args: [_pageLabel(saved.$1)])),
              onTap: () => Navigator.of(ctx).pop(_Scope.resume),
            ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text('library.listen_scope_book'.tr()),
            subtitle: Text('library.listen_scope_book_desc'.tr()),
            onTap: () => Navigator.of(ctx).pop(_Scope.book),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text('library.listen_scope_page'.tr()),
            onTap: () => Navigator.of(ctx).pop(_Scope.page),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  String _pageLabel(int i) =>
      localizeDigits('${widget.doc.printedPageAt(i) ?? i + 1}', uiLanguageCode);

  void _explain() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('library.text_listen_unavailable_title'.tr()),
        content: Text(
          trn(
            'library.text_listen_unavailable_body',
            args: ['${widget.book.diacritisedPct}'],
          ),
        ),
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
    final choice = await showFittedSheet<BookVoice>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListenableBuilder(
        listenable: openVoiceChanges,
        builder: (ctx, _) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'library.voice_section_title'.tr(),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final (v, title, sub) in [
                (
                  BookVoice.open,
                  'library.open_voice_title'.tr(),
                  openVoiceStatus(),
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
            ],
          ),
        ),
      ),
    );
    if (choice == null || choice == current) return;
    if (widget.aloud.active) await widget.aloud.stop();
    if (choice == BookVoice.open && !installed && mounted) {
      await installOpenVoice(context);
      // Cancelled: nothing changes. Sent to the background: the choice
      // stands, and the phone's voice reads until the pack lands.
      if (OpenVoice.wasCancelled) return;
    }
    await BookVoicePref.save(choice);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.aloud,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final on = widget.book.canBeSpoken;
    final speaking = widget.aloud.active;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToolbarAction(
          icon: speaking
              ? Icons.stop_circle_outlined
              : Icons.headphones_outlined,
          label: speaking
              ? 'library.text_listen_stop'.tr()
              : 'library.text_listen'.tr(),
          active: speaking,
          onPressed: on ? _toggle : _explain,
        ),
        if (on)
          ToolbarAction(
            icon: Icons.record_voice_over_outlined,
            label: 'library.voice_short'.tr(),
            onPressed: _pickVoice,
          ),
      ],
    );
  }
}

enum _Scope { resume, book, page }
