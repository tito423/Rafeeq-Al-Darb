# -*- coding: utf-8 -*-
"""Every user-visible string in the app that is NOT going through `.tr()`.

The owner's requirement is absolute: «كل شاشة وكل كارت منفصلا ومنفردا يجب انه
يكون مترجما ترجمة صحيحة كاملة للغة المختارة بكل سطر كود في التطبيق». This is
the measurement that makes that checkable instead of a claim - run it again
after every batch of fixes, and drive `chrome` to zero.

THREE BUCKETS, because they need three different kinds of work:

  chrome   UI text hardcoded in a widget or a notification. Mechanical: give
           it a key and translate the key into all seven locales.
  content  Arabic the app itself authors - book blurbs, imam biographies, the
           new-Muslim guide, channel descriptions. Needs real translation, not
           a key.
  (dropped) A literal used to LOOK SOMETHING UP is not display text, and two
           shapes cover every case here: a map key (`'الصباح': Icons.sunny`)
           and a comparison (`title.contains('الصباح')`).

Files whose Arabic is an ALGORITHM's data are excluded by name in
NOT_USER_VISIBLE, with the reason recorded, rather than silently by a pattern.
"""

import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "rafeeq_app", "lib")

ARABIC = re.compile(r"[؀-ۿ]")

def _scan(src, i, raw):
    """Consume the Dart string literal whose opening quote is at `src[i]`.

    Returns `(end, verbatim, residue)`: the index just past the closing quote,
    the literal's body as written, and the body with every interpolation
    replaced by a space.

    A regex cannot do this. `'${book?.nameAr ?? ''} · ${'k'.tr()} ${n}'` is one
    Dart literal containing four quote characters, and a regex reading quotes
    pairwise splits it into fragments that look like hardcoded text - which is
    exactly how three "untranslated strings" that were nothing of the kind
    stayed on the list.
    """
    n = len(src)
    q = src[i] * 3 if src.startswith(src[i] * 3, i) else src[i]
    i += len(q)
    verbatim, residue = [], []
    while i < n:
        if src.startswith(q, i):
            return i + len(q), "".join(verbatim), "".join(residue)
        c = src[i]
        if c == "\\" and not raw:
            verbatim.append(src[i:i + 2])
            residue.append(" ")
            i += 2
            continue
        if c == "$" and not raw:
            if i + 1 < n and src[i + 1] == "{":
                depth, j = 1, i + 2
                while j < n and depth:
                    if src[j] in "'\"":
                        j = _scan(src, j, False)[0]
                        continue
                    if src[j] == "{":
                        depth += 1
                    elif src[j] == "}":
                        depth -= 1
                    j += 1
            else:
                j = i + 1
                while j < n and (src[j].isalnum() or src[j] == "_"):
                    j += 1
            verbatim.append(src[i:j])
            residue.append(" ")
            i = j
            continue
        if c == "\n" and len(q) == 1:
            # An unterminated single-quoted literal means the scan is out of
            # step; stop here rather than swallowing the rest of the file.
            return i, "".join(verbatim), "".join(residue)
        verbatim.append(c)
        residue.append(c)
        i += 1
    return n, "".join(verbatim), "".join(residue)


IDENT_CHAR = re.compile(r"[A-Za-z0-9_]")


def literals(src):
    """Yield `(start, end, verbatim, residue)` for every string literal."""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c in "'\"":
            raw = (i > 0 and src[i - 1] in "rR"
                   and (i < 2 or not IDENT_CHAR.match(src[i - 2])))
            end, verbatim, residue = _scan(src, i, raw)
            yield (i - 1 if raw else i), end, verbatim, residue
            i = max(end, i + 1)
        else:
            i += 1

# A literal that lands in one of these slots is rendered.
SLOT = re.compile(
    r"\b(?:Text|SelectableText|ArabicText)\s*\(\s*$"
    r"|\b(?:label|title|subtitle|hintText|labelText|tooltip|semanticLabel"
    r"|helperText|errorText|contentTitle|contentText|ticker)\s*:\s*$"
)

SKIP_IF_CONTAINS = (
    "assets/", "http://", "https://", "package:", ".png", ".jpg", ".json",
    ".db", ".mp3", ".mp4", ".svg", ".ttf", ".zip", "\\u",
)

NOT_USER_VISIBLE = {
    "core/utils/arabic_normalize.dart":
        "regex character classes for stripping harakat - never rendered",
    "core/utils/buckwalter.dart":
        "the Buckwalter transliteration table - a mapping, not text",
    "features/quran/data/quran_grammar_parser.dart":
        "Quranic-corpus grammar tags mapped to their Arabic names; rendered "
        "in the i'rab tab and tracked as its own task, not as loose strings",
}

MAP_KEY = re.compile(r"^\s*r?['\"].*['\"]\s*:")
LOOKUP = re.compile(r"\.(?:contains|startsWith|endsWith|indexOf|split)\s*\(")
COMPARE = re.compile(r"[=!]=\s*r?['\"]")

# Left in Arabic ON PURPOSE, each with the reason. These are NOT "things the
# audit can't see" - they are decisions, and a decision belongs in writing.
ALLOWLIST = {
    # A font sample is judged on how it looks, so the sample is the point.
    ("features/quran/presentation/widgets/mushaf_theme_picker.dart",
     "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"): "mushaf font sample",
    ("features/quran/presentation/widgets/mushaf_theme_picker.dart",
     "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ"): "mushaf font sample (highlighted)",
    ("features/settings/presentation/widgets/non_arabic_reading_card.dart",
     "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"):
        "the card's whole point is showing what Arabic looks like beside its "
        "transliteration - translating the sample would erase the feature",
    ("features/settings/presentation/widgets/non_arabic_reading_card.dart",
     "Bismi Allāhi r-Raḥmāni r-Raḥīm"):
        "the transliteration half of that same sample",
    ("features/settings/presentation/widgets/non_arabic_reading_card.dart",
     "Quran.com v4 API"): "the API's own name",

    # Arabic-Indic digits: the owner's decision, twice over - a mushaf's page
    # number is set in Arabic-Indic digits in every printing, and one clock
    # face is an Arabic-numeral face.
    ("features/quran/presentation/screens/quran_screen.dart",
     "٠١٢٣٤٥٦٧٨٩"): "Arabic-Indic digits for the mushaf's page number",
    ("features/home/presentation/widgets/digital_clock_faces.dart",
     "٠١٢٣٤٥٦٧٨٩"): "Arabic-Indic digits for the Arabic-numeral clock face",
    ("core/services/prayer_status_notification.dart",
     "٠١٢٣٤٥٦٧٨٩"): "Arabic-Indic digits for the Arabic locale's date line",
    ("features/home/presentation/widgets/analog_clock_faces.dart",
     "١٢"): "Arabic-numeral clock face",
    ("features/home/presentation/widgets/analog_clock_faces.dart",
     "١٠"): "Arabic-numeral clock face",
    ("features/home/presentation/widgets/analog_clock_faces.dart",
     "١١"): "Arabic-numeral clock face",

    # The owner's own name.
    ("features/settings/presentation/screens/about_screen.dart",
     "Tito Abo Malak"): "the owner's name",
}

# Whole categories of proper name, listed per file so a NEW hardcoded string in
# the same file is still reported. A name is not translated - it is rendered in
# its own direction instead (`ArabicText`), which is what these all do.
ALLOWLIST_NAMES = {
    "features/library/presentation/screens/library_screen.dart": (
        "the real names of Arabic-language dawah channels and Islamic sites; "
        "their DESCRIPTIONS are translated (dawah.*) and the names render "
        "through ArabicText",
        ("د. راغب السرجاني", "د. حسن الحسيني", "الشيخ أمجد سمير",
         "د. أحمد العربي", "د. هيثم طلعت", "قناة فاهم", "د. إياد قنيبي",
         "قناة مكاني", "م. أيمن عبدالرحيم", "قناة وعي",
         "الإسلام سؤال وجواب", "الدرر السنية", "طريق الإسلام",
         "صيد الفوائد", "شبكة الألوكة"),
    ),
    "features/settings/presentation/screens/sources_screen.dart": (
        "a credit names its source; renaming «مسند أحمد — ط الرسالة» in "
        "French would stop it being a credit (CLAUDE.md §1.2). Rendered "
        "through ArabicText so it reads right-to-left in a Latin UI",
        ("المكتبة الشاملة", "مسند أحمد — ط الرسالة",
         "سنن الدارمي — ت حسين أسد"),
    ),
}


def allowed(short, body):
    if (short, body) in ALLOWLIST:
        return True
    entry = ALLOWLIST_NAMES.get(short)
    return bool(entry) and body in entry[1]


def strip_comments(src):
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


KEYED = re.compile(r"\s*\.tr\b")


def audit_file(path, short):
    src = strip_comments(io.open(path, encoding="utf-8").read())
    lines = src.split("\n")
    found = []
    skipped = 0

    for start, end, body, rest in literals(src):
        if any(s in body for s in SKIP_IF_CONTAINS):
            continue
        # `'some.key'.tr()` - already going through the locale files.
        # The window is generous because dartfmt wraps a long call: the key
        # can sit on its own line with `.tr()` indented underneath it.
        if KEYED.match(src[end:end + 120]):
            continue

        arabic = bool(ARABIC.search(rest))
        before = src[max(0, start - 40):start]
        rendered = bool(SLOT.search(before))
        if not arabic and not rendered:
            continue
        if not arabic and not re.search(r"[A-Za-z]{2,}", rest):
            continue
        if len(rest.strip()) < 2:
            continue
        if allowed(short, body):
            skipped += 1
            continue

        line_no = src[:start].count("\n") + 1
        line = lines[line_no - 1] if line_no - 1 < len(lines) else ""
        if MAP_KEY.match(line) or LOOKUP.search(line) or COMPARE.search(line):
            continue

        bucket = ("content"
                  if ("/data/" in short or short.endswith("_catalog.dart")
                      or short.endswith("_bios.dart")
                      or short.endswith("_content.dart"))
                  else "chrome")
        found.append((bucket, line_no, body[:90]))
    return found, skipped


ANDROID = os.path.join(ROOT, "rafeeq_app", "android", "app", "src", "main")

# Kotlin comments and doc-comments are full of Arabic (they quote the very
# button labels they implement), so this reads string LITERALS only, after the
# comments are stripped by the same pass Dart gets.
KT_LITERAL = re.compile(r'"(?:\\.|[^"\\\n])*"')

# Kotlin that legitimately holds Arabic: the app's own name, as an Android
# resource, is picked by the DEVICE locale and that is correct - the launcher
# icon's label is not the app's in-app language.
NATIVE_ALLOWLIST = {
    "res/values-ar/strings.xml":
        "an Android resource, selected by the device locale - the launcher "
        "label is the one string that SHOULD follow the phone, not the app",
    "kotlin/com/tito/rafeeq_aldarb/NativeStrings.kt":
        "this file IS the fix: its Arabic is the fallback map, used only in "
        "the window before Dart has ever pushed the translated strings (a "
        "first launch whose alarm fires before the app is opened). Everything "
        "it serves is translated - see add_i18n_keys_native.py",
}


def audit_native():
    """Arabic that ANDROID renders - invisible to a Dart-only audit.

    This bucket existed unmeasured until the fifth session's chrome count hit
    zero and the notification shade was still Arabic on a French UI: three
    channel names, three descriptions, the adhan alert's title, body and its
    two action buttons, and the download service's notification. Fifteen
    strings, none of which had ever appeared in a report.
    """
    found = {}
    for dirpath, _dirs, files in os.walk(ANDROID):
        for f in sorted(files):
            if not f.endswith((".kt", ".java", ".xml")):
                continue
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, ANDROID).replace("\\", "/")
            if rel in NATIVE_ALLOWLIST:
                continue
            src = io.open(p, encoding="utf-8").read()
            if f.endswith(".xml"):
                hits = [(i + 1, l.strip()[:90])
                        for i, l in enumerate(src.split("\n"))
                        if ARABIC.search(l)]
            else:
                src = strip_comments(src)
                hits = []
                for m in KT_LITERAL.finditer(src):
                    if not ARABIC.search(m.group(0)):
                        continue
                    hits.append((src[:m.start()].count("\n") + 1,
                                 m.group(0).strip('"')[:90]))
            if hits:
                found[rel] = hits
    return found


def main():
    per_file, total, allowlisted = {}, 0, 0
    for dirpath, _dirs, files in os.walk(LIB):
        for f in sorted(files):
            if not f.endswith(".dart"):
                continue
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, ROOT).replace("\\", "/")
            short = rel.split("lib/", 1)[-1]
            if short in NOT_USER_VISIBLE:
                continue
            found, skipped = audit_file(p, short)
            allowlisted += skipped
            if found:
                per_file[rel] = found
                total += len(found)

    native = audit_native()
    native_count = sum(len(v) for v in native.values())

    chrome = sum(1 for v in per_file.values() for b, _, _ in v if b == "chrome")
    out = io.StringIO()
    out.write("UNTRANSLATED USER-VISIBLE STRINGS: %d in %d files\n" %
              (total + native_count, len(per_file) + len(native)))
    out.write("   chrome  (UI text that must go through .tr()): %d\n" % chrome)
    out.write("   native  (Arabic that ANDROID renders, not Dart): %d\n"
              % native_count)
    out.write("   content (Arabic the app authors, needs translating): %d\n"
              % (total - chrome))
    out.write("   allowlisted (deliberate, with a reason in this script): %d\n\n"
              % allowlisted)
    for rel in sorted(native, key=lambda k: -len(native[k])):
        out.write("%-70s %4d  (native)\n" % ("android/.../" + rel,
                                             len(native[rel])))
    for rel in sorted(per_file, key=lambda k: -len(per_file[k])):
        v = per_file[rel]
        c = sum(1 for b, _, _ in v if b == "chrome")
        out.write("%-70s %4d  (chrome %d, content %d)\n"
                  % (rel, len(v), c, len(v) - c))
    out.write("\n\n---- detail ----\n\n")
    for rel in sorted(per_file):
        out.write("== %s\n" % rel)
        for bucket, line, text in per_file[rel]:
            out.write("   %-8s :%-5d %s\n" % (bucket, line, text))
        out.write("\n")
    for rel in sorted(native):
        out.write("== android/.../%s\n" % rel)
        for line, text in native[rel]:
            out.write("   %-8s :%-5d %s\n" % ("native", line, text))
        out.write("\n")
    io.open(os.path.join(ROOT, "i18n_audit.txt"), "w",
            encoding="utf-8").write(out.getvalue())
    print("wrote i18n_audit.txt  -  %d total, %d chrome, %d native, %d content"
          % (total + native_count, chrome, native_count, total - chrome))
    return chrome + native_count


if __name__ == "__main__":
    main()
