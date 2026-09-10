# -*- coding: utf-8 -*-
"""Measure the things that decide whether this app is cheap to maintain.

Not a linter — `flutter analyze` already runs clean. This answers the
questions a person actually asks before touching an unfamiliar codebase:
how big are the files, is anything duplicated, is anything dead, and how much
of it is explained.

    py -3 scripts/code_health.py
"""

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "rafeeq_app", "lib")
TEST = os.path.join(ROOT, "rafeeq_app", "test")
REPORT = os.path.join(ROOT, "code_health.txt")


def dart_files(base):
    for dp, _dn, fn in os.walk(base):
        for f in fn:
            if f.endswith(".dart"):
                yield os.path.join(dp, f)


def rel(p):
    return os.path.relpath(p, os.path.join(ROOT, "rafeeq_app")).replace(
        os.sep, "/")


def read(p):
    return io.open(p, encoding="utf-8", errors="replace").read()


def main():
    out = io.open(REPORT, "w", encoding="utf-8", newline="\n")

    rows = []
    total_lines = doc_lines = code_lines = 0
    for p in dart_files(LIB):
        src = read(p)
        lines = src.splitlines()
        doc = sum(1 for l in lines if l.lstrip().startswith(("///", "//")))
        rows.append((len(lines), rel(p)))
        total_lines += len(lines)
        doc_lines += doc
        code_lines += sum(1 for l in lines if l.strip())
    rows.sort(reverse=True)

    tests = list(dart_files(TEST))
    test_lines = sum(len(read(p).splitlines()) for p in tests)

    out.write("SIZE\n")
    out.write("  %d files in lib, %d lines (median %d)\n"
              % (len(rows), total_lines, rows[len(rows) // 2][0]))
    out.write("  %d test files, %d lines  (%.0f%% of lib)\n"
              % (len(tests), test_lines, 100.0 * test_lines / total_lines))
    out.write("  %d comment lines (%.0f%% of non-blank)\n\n"
              % (doc_lines, 100.0 * doc_lines / code_lines))

    out.write("BIGGEST FILES (a file over ~800 lines is where a change starts\n"
              "to mean reading a lot before you can touch anything)\n")
    for n, p in rows[:15]:
        out.write("  %6d  %s\n" % (n, p))

    # A public declaration that nothing else in lib/ or test/ ever names.
    #
    # Read the hits, do not act on them. This is a text search, and Dart has
    # two constructs whose name never appears at the call site:
    #
    #   * an `extension` — you write `category.labelKey`, never
    #     `DownloadCategoryX`. `DownloadCategoryX` was reported here and is
    #     used on five lines.
    #   * an enum/class named only through a type annotation the analyser
    #     infers.
    #
    # `flutter analyze` reports genuinely unused *private* names already, so
    # anything this prints needs `grep` on its members before it is deleted.
    everything = "\n".join(read(p) for p in list(dart_files(LIB)) + tests)
    decl = re.compile(
        r"^(?:class|mixin|enum|extension)\s+([A-Z]\w+)|"
        r"^(?:final|const)\s+\w[\w<>,?\s]*\s([a-z]\w+)\s*=", re.M)
    unused = []
    for p in dart_files(LIB):
        src = read(p)
        for m in decl.finditer(src):
            name = m.group(1) or m.group(2)
            if not name or name.startswith("_"):
                continue
            # One mention is its own declaration.
            if len(re.findall(r"\b%s\b" % re.escape(name), everything)) <= 1:
                unused.append((name, rel(p)))
    out.write("\nPUBLIC NAMES NOTHING REFERENCES (%d)\n" % len(unused))
    for name, p in sorted(unused)[:30]:
        out.write("  %-38s %s\n" % (name, p))

    todos = []
    for p in dart_files(LIB):
        for i, l in enumerate(read(p).splitlines(), 1):
            if re.search(r"\b(TODO|FIXME|HACK|XXX)\b", l):
                todos.append("%s:%d  %s" % (rel(p), i, l.strip()[:96]))
    out.write("\nTODO / FIXME / HACK (%d)\n" % len(todos))
    for t in todos:
        out.write("  %s\n" % t)

    # Files with no doc comment at the top of their first declaration.
    undocumented = []
    for p in dart_files(LIB):
        src = read(p)
        m = re.search(r"^(class|mixin|enum)\s+\w+", src, re.M)
        if not m:
            continue
        before = src[:m.start()].rstrip().splitlines()
        if not before or not before[-1].lstrip().startswith("///"):
            undocumented.append(rel(p))
    out.write("\nTYPES WITH NO DOC COMMENT (%d of %d files)\n"
              % (len(undocumented), len(rows)))
    for p in sorted(undocumented)[:25]:
        out.write("  %s\n" % p)

    out.close()
    sys.stdout.write(io.open(REPORT, encoding="utf-8").read())


if __name__ == "__main__":
    main()
