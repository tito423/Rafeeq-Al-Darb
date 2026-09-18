import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/toolbar_action.dart';
import '../../data/book_catalog.dart';
import '../../data/book_speaker.dart';
import '../../data/book_text.dart';

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

  @override
  Widget build(BuildContext context) {
    final on = widget.book.canBeSpoken;
    return ToolbarAction(
      icon: _speaking ? Icons.stop_circle_outlined : Icons.headphones_outlined,
      label: _speaking
          ? 'library.text_listen_stop'.tr()
          : 'library.text_listen'.tr(),
      active: _speaking,
      onPressed: on ? _toggle : _explain,
    );
  }
}
