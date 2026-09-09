# -*- coding: utf-8 -*-
"""Move the 226 book blurbs onto a key and a template.

197 of them are the generated sentence «مصنَّف لـ <author>، <N> صفحة، ضمن باب
<category>.». Its three slots already exist elsewhere: the author is
`properName(authorAr, authorEn)`, the category is `BookCategory.labelKey`, and
the page count is a number that was only ever inside that sentence — so it
becomes a field, and the sentence becomes one key.

The remaining 29 are prose, and each gets `book_desc.<id>`.

The script asserts, per book, that the category word written into the sentence
is the category the book is actually filed under. If a single one disagrees,
nothing is written: swapping in `category.labelKey` would then be changing what
the card says, not translating it.
"""

import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAT = os.path.join(ROOT, "rafeeq_app", "lib", "features", "library", "data",
                   "book_catalog.dart")
LIT = r"""(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")"""
TEMPLATE = re.compile(r"^مصنَّف لـ (.+?)، (\d+) صفحة، ضمن باب (.+?)\.$")

# The Arabic the generated sentence names, and the enum value the book carries.
CATEGORY_WORD = {
    "الحديث": "hadith",
    "الفقه": "fiqh",
    "العقيدة": "aqidah",
    "التفسير": "tafsir",
    "السيرة والتاريخ": "seerah",
    "التزكية والرقائق": "tazkiyah",
    "الأدب": "adab",
}


def _blocks(src):
    for b in re.split(r"\n  LibraryBook\(", src)[1:]:
        mid = re.search(r"^\s*id: '([^']+)'", b, re.M)
        md = re.search(r"\bdescriptionAr:\s*((?:%s\s*)+)," % LIT, b)
        mc = re.search(r"^\s*category: BookCategory\.(\w+),", b, re.M)
        if not (mid and md and mc):
            raise SystemExit("a LibraryBook is missing id/description/category")
        chunks = [c[1:-1] for c in re.findall(LIT, md.group(1))]
        text = "".join(chunks).replace("\\'", "'").replace('\\"', '"')
        yield mid.group(1), text, mc.group(1), md.group(0)


def arabic_blurbs():
    """id -> Arabic blurb, for the ones that are prose rather than template."""
    src = io.open(CAT, encoding="utf-8").read()
    out = {}
    for bid, text, _cat, _raw in _blocks(src):
        if not TEMPLATE.match(text.strip()):
            out[bid] = text
    return out


def main():
    src = io.open(CAT, encoding="utf-8").read()

    tpl = bespoke = 0
    for bid, text, cat, raw in _blocks(src):
        m = TEMPLATE.match(text.strip())
        if m:
            word = m.group(3)
            expect = CATEGORY_WORD.get(word)
            if expect is None:
                raise SystemExit("%s: unknown category word %r" % (bid, word))
            if expect != cat:
                raise SystemExit(
                    "%s: the sentence says «%s» (%s) but the book is filed "
                    "under BookCategory.%s — refusing to swap in the enum's "
                    "label, that would change what the card says"
                    % (bid, word, expect, cat))
            new = "pages: %s," % m.group(2)
            tpl += 1
        else:
            new = "descKey: 'book_desc.%s'," % bid
            bespoke += 1
        src = src.replace(raw, new, 1)

    src = src.replace("""  final String descriptionAr;
""", """  /// The printed page count, which used to live inside the generated blurb
  /// sentence and nowhere else. 0 for a book whose blurb is prose.
  final int pages;

  /// `book_desc.<id>` for the 29 books with a written blurb; empty for the
  /// 197 whose blurb was the generated sentence, which [description] writes
  /// from `library.book_desc_generated` instead.
  final String descKey;
""", 1)
    src = src.replace("""    required this.descriptionAr,
""", """    this.pages = 0,
    this.descKey = '',
""", 1)

    src = src.replace("""  /// «توفي 852 هـ» / "Died 852 AH\"""",
                      """  /// What the card says about the book.
  ///
  /// 197 of the 226 blurbs were one generated sentence with three slots, and
  /// all three are already translated elsewhere: the author's name is written
  /// in the reader's script by [properName], the category has its own key, and
  /// the page count is a number. So they share one key instead of 197.
  String description() => descKey.isNotEmpty
      ? descKey.tr()
      : 'library.book_desc_generated'.tr(args: [
          properName(authorAr, authorEn),
          '$pages',
          category.labelKey.tr(),
        ]);

  /// «توفي 852 هـ» / "Died 852 AH\"""", 1)

    src = src.replace("import 'package:easy_localization/easy_localization.dart';",
                      "import 'package:easy_localization/easy_localization.dart';\n\n"
                      "import '../../../core/i18n/proper_name.dart';", 1)

    # A comment at the top of the seerah block explains what the generated
    # line used to be; rewrite it rather than leave a comment describing a
    # field that no longer exists.
    src = src.replace(
        "  // descriptionAr here is a short factual line (author + category +",
        "  // The blurb here was the generated line (author + category +", 1)
    left = [l for l in src.split(chr(10)) if "descriptionAr" in l]
    if left:
        raise SystemExit("descriptionAr still present: %s" % left[:3])

    io.open(CAT, "w", encoding="utf-8", newline="").write(src)
    print("template %d, bespoke %d" % (tpl, bespoke))

    # The one render site.
    scr = os.path.join(ROOT, "rafeeq_app", "lib", "features", "library",
                       "presentation", "screens", "library_screen.dart")
    s = io.open(scr, encoding="utf-8").read()
    old = """            ArabicText(book.descriptionAr,
                style: const TextStyle(fontSize: 13)),"""
    new = """            Text(book.description(),
                style: const TextStyle(fontSize: 13)),"""
    if s.count(old) != 1:
        raise SystemExit("library_screen: blurb render site not found")
    io.open(scr, "w", encoding="utf-8", newline="").write(s.replace(old, new))
    print("library_screen updated")


if __name__ == "__main__":
    main()
