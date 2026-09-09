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

LITERAL = re.compile(
    r"r?'''(?:[^']|'(?!''))*'''"
    r'|r?"""(?:[^"]|"(?!""))*"""'
    r"|r?'(?:\\.|[^'\\\n])*'"
    r'|r?"(?:\\.|[^"\\\n])*"'
)

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


def keyed_spans(src):
    """Ranges covered by a `'key'.tr(...)` call - those are already handled."""
    return [(m.start(), m.end())
            for m in re.finditer(r"(['\"])((?:\\.|(?!\1).)*)\1\s*\.tr\b", src)]


def audit_file(path, short):
    src = strip_comments(io.open(path, encoding="utf-8").read())
    ok = keyed_spans(src)
    lines = src.split("\n")
    found = []

    for m in LITERAL.finditer(src):
        text = m.group(0)
        body = text.strip("rR").strip("'\"")
        if any(s in text for s in SKIP_IF_CONTAINS):
            continue
        if any(a <= m.start() < b for a, b in ok):
            continue

        arabic = bool(ARABIC.search(text))
        before = src[max(0, m.start() - 40):m.start()]
        rendered = bool(SLOT.search(before))
        if not arabic and not rendered:
            continue
        if not arabic and not re.search(r"[A-Za-z]{2,}", body):
            continue
        if len(body.strip()) < 2:
            continue

        line_no = src[: m.start()].count("\n") + 1
        line = lines[line_no - 1] if line_no - 1 < len(lines) else ""
        if MAP_KEY.match(line) or LOOKUP.search(line) or COMPARE.search(line):
            continue

        bucket = ("content"
                  if ("/data/" in short or short.endswith("_catalog.dart")
                      or short.endswith("_bios.dart")
                      or short.endswith("_content.dart"))
                  else "chrome")
        found.append((bucket, line_no, body[:90]))
    return found


def main():
    per_file, total = {}, 0
    for dirpath, _dirs, files in os.walk(LIB):
        for f in sorted(files):
            if not f.endswith(".dart"):
                continue
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, ROOT).replace("\\", "/")
            short = rel.split("lib/", 1)[-1]
            if short in NOT_USER_VISIBLE:
                continue
            found = audit_file(p, short)
            if found:
                per_file[rel] = found
                total += len(found)

    chrome = sum(1 for v in per_file.values() for b, _, _ in v if b == "chrome")
    out = io.StringIO()
    out.write("UNTRANSLATED USER-VISIBLE STRINGS: %d in %d files\n" %
              (total, len(per_file)))
    out.write("   chrome  (UI text that must go through .tr()): %d\n" % chrome)
    out.write("   content (Arabic the app authors, needs translating): %d\n\n"
              % (total - chrome))
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
    io.open(os.path.join(ROOT, "i18n_audit.txt"), "w",
            encoding="utf-8").write(out.getvalue())
    print("wrote i18n_audit.txt  -  %d total, %d chrome, %d content"
          % (total, chrome, total - chrome))
    return chrome


if __name__ == "__main__":
    main()
