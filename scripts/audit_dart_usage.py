"""Code-health numbers for rafeeq_app/lib, for the audit (AUDIT.md).

    py -3 scripts/audit_dart_usage.py

Prints: lib files nothing imports (dead code candidates), TODO/FIXME count,
print() calls, and files over 800 lines.
"""
import glob
import os
import re

APP = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rafeeq_app")


def rel(p):
    return os.path.relpath(p, APP).replace(os.sep, "/")


def main():
    os.chdir(APP)
    lib = [rel(f) for f in glob.glob("lib/**/*.dart", recursive=True)]
    everything = lib + [rel(f) for f in glob.glob("test/**/*.dart", recursive=True)]
    text = {f: open(f, encoding="utf-8").read() for f in everything}
    used = set()
    for f, t in text.items():
        for m in re.finditer(r"^(?:import|export|part)\s+'([^']+)'", t, re.M):
            imp = m.group(1)
            if imp.startswith("package:rafeeq_app/"):
                used.add("lib/" + imp[len("package:rafeeq_app/"):])
            elif not imp.startswith(("package:", "dart:")):
                used.add(os.path.normpath(os.path.join(os.path.dirname(f), imp)).replace(os.sep, "/"))
    dead = sorted(f for f in lib if f not in used and not f.endswith(("lib/main.dart", "lib/adhan_entry.dart")))
    print(f"unreferenced lib files: {len(dead)}")
    for d in dead:
        print("  " + d)
    todo = sum(len(re.findall(r"//\s*(?:TODO|FIXME|HACK)", text[f])) for f in lib)
    prints = {f: len(re.findall(r"(?<![A-Za-z_.])print\(", text[f])) for f in lib}
    print(f"TODO/FIXME/HACK: {todo}")
    print("print():", {f: n for f, n in prints.items() if n})
    big = sorted(((text[f].count("\n"), f) for f in lib), reverse=True)
    print("over 800 lines:", [(f, n) for n, f in big if n > 800])


if __name__ == "__main__":
    main()
