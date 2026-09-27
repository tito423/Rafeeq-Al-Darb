"""Move a Dart file inside rafeeq_app and fix every relative import.

    py -3 scripts/dart_move.py lib/core/services/x.dart lib/features/y/data/x.dart [...pairs]

The app imports its own files by RELATIVE path, so moving one breaks two
kinds of line: the imports that point AT it (in lib/ and test/, and
`package:rafeeq_app/...` ones in tests), and the imports INSIDE it. This
does the `git mv` and rewrites both, keeping each import's quote style and
any `show`/`hide`/`as` clause. Several moves in one call are applied
together, so files that move with each other still resolve.
Run `flutter analyze` afterwards - it is the proof.
"""
import glob
import os
import re
import subprocess
import sys

APP = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rafeeq_app")
IMPORT = re.compile(r"^((?:import|export|part)\s+')([^']+)(')", re.M)


def norm(p):
    return os.path.normpath(p).replace(os.sep, "/")


def resolve(importer, target):
    """The lib-relative path an import points at, or None for packages/sdk."""
    if target.startswith("package:rafeeq_app/"):
        return "lib/" + target[len("package:rafeeq_app/"):]
    if target.startswith(("package:", "dart:")):
        return None
    return norm(os.path.join(os.path.dirname(importer), target))


def spell(importer, target, was):
    """The import string for [target] from [importer], in the old style."""
    if was.startswith("package:rafeeq_app/"):
        return "package:rafeeq_app/" + target[len("lib/"):]
    rel = norm(os.path.relpath(target, os.path.dirname(importer)))
    return rel


def main(argv):
    pairs = list(zip(argv[0::2], argv[1::2]))
    if not pairs or len(argv) % 2:
        sys.exit(__doc__)
    os.chdir(APP)
    moves = {norm(a): norm(b) for a, b in pairs}
    files = [norm(f) for f in glob.glob("lib/**/*.dart", recursive=True) + glob.glob("test/**/*.dart", recursive=True)]
    # Rewrite every file as if the moves had happened, then move.
    for f in files:
        src = open(f, encoding="utf-8").read()
        new_home = moves.get(f, f)

        def fix(m):
            target = resolve(f, m.group(2))
            if target is None:
                return m.group(0)
            target = moves.get(target, target)
            return m.group(1) + spell(new_home, target, m.group(2)) + m.group(3)

        out = IMPORT.sub(fix, src)
        if out != src:
            open(f, "w", encoding="utf-8", newline="").write(out)
    for a, b in moves.items():
        os.makedirs(os.path.dirname(b), exist_ok=True)
        subprocess.check_call(["git", "mv", a, b])
        print(f"moved {a} -> {b}")


if __name__ == "__main__":
    main(sys.argv[1:])
