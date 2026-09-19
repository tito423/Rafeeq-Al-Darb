import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/book_speaker.dart';
import 'open_voice_offer.dart';

/// What the reader's voice may say of a passage: the paragraphs that are not
/// Qur'an (the same rule as the book reader's `pageSpeechText`), with any
/// Qur'anic words quoted INSIDE a paragraph taken out as well - these texts
/// cite an ayah in ﴿ ﴾ or in plain { } (trap #35), and the Qur'an is recited
/// by named qurra' in this app, never by a synthetic voice.
String speakablePassage(Iterable<({String text, String kind})> paras) =>
    pageSpeechText(paras)
        .replaceAll(RegExp(r'﴿[^﴾]*﴾'), ' ')
        .replaceAll(RegExp(r'\{[^}]*\}'), ' ')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();

/// Marks per Arabic letter, in per cent - exactly what
/// `scripts/measure_diacritisation.py` measured for every library book
/// (`[ً-ْٰ]` over `[ء-ي]`), so the same 80% line applies here.
double diacritisedShare(String text) {
  final letters = RegExp('[\u0621-\u064A]').allMatches(text).length;
  if (letters == 0) return 0;
  return 100 * RegExp('[\u064B-\u0652\u0670]').allMatches(text).length / letters;
}

/// «حط زرار أنيميتد جميل للاستماع لكل ما في الحج والعمرة وعلم التجويد، وأي
/// حاجة فيها نص متشكّل ينفع يتسمع» (2026-09-19). A pill that reads the
/// passage above it in the voice chosen for the library; while it speaks the
/// headphones breathe and the label becomes «إيقاف». Closing the card or
/// leaving the screen stops it.
///
/// «أي حاجة فيها نص متشكّل»: a passage below the library's 80% line is not
/// offered at all - a wrong vowel in these texts is a wrong meaning, the
/// same reason the reader refuses unvowelled books.
class ListenTextButton extends StatefulWidget {
  /// Built when pressed, so the text is always the passage as shown now.
  final String Function() text;

  const ListenTextButton({super.key, required this.text});

  @override
  State<ListenTextButton> createState() => _ListenTextButtonState();
}

class _ListenTextButtonState extends State<ListenTextButton>
    with SingleTickerProviderStateMixin {
  final BookSpeaker _speaker = BookSpeaker();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _speaking = false;
  int _run = 0;

  @override
  void dispose() {
    _run++;
    _speaker.stop();
    _speaker.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_speaking) {
      _run++;
      await _speaker.stop();
      _set(false);
      return;
    }
    final text = widget.text();
    if (text.isEmpty) return;
    if (!await offerOpenVoice(context)) return;
    if (!await _speaker.available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('library.text_listen_no_engine'.tr())),
      );
      return;
    }
    final run = ++_run;
    _set(true);
    await _speaker.speak(text);
    if (run == _run) _set(false);
  }

  void _set(bool on) {
    if (!mounted) return;
    setState(() => _speaking = on);
    on ? _pulse.repeat(reverse: true) : _pulse.stop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_speaking && diacritisedShare(widget.text()) < 80) {
      return const SizedBox.shrink();
    }
    final fg = _speaking ? Colors.white : AppColors.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: _speaking
                    ? const LinearGradient(
                        colors: [Color(0xFFE2C15A), AppColors.gold],
                      )
                    : null,
                color: _speaking
                    ? null
                    : AppColors.gold.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.6),
                ),
                boxShadow: _speaking
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.25).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                    ),
                    child: Icon(
                      _speaking
                          ? Icons.graphic_eq_rounded
                          : Icons.headphones_rounded,
                      size: 18,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _speaking
                        ? 'library.text_listen_stop'.tr()
                        : 'library.text_listen'.tr(),
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
