"""Inventory Flutter screens that Rafeeq may need to open.

This is deliberately a source inventory, not a guessed feature catalogue. It
reads public ``*Screen`` declarations and ``MaterialPageRoute`` builders, then
prints the current ``AssistantScreen`` enum beside them for human
classification. Run from the repository root:

    py -3 scripts/inventory_assistant_screens.py
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "rafeeq_app" / "lib"
INTENT = LIB / "features" / "assistant" / "data" / "assistant_intent.dart"

CLASS_RE = re.compile(r"\bclass\s+([A-Z][A-Za-z0-9_]*Screen)\b")
ROUTE_RE = re.compile(
    r"MaterialPageRoute(?:<[^>]+>)?\s*\("
    r"(?:(?!MaterialPageRoute)[\s\S]){0,500}?"
    r"builder\s*:\s*\([^)]*\)\s*=>\s*(?:const\s+)?"
    r"([A-Z][A-Za-z0-9_]*Screen)\s*\(",
)
ENUM_RE = re.compile(r"enum\s+AssistantScreen\s*\{([\s\S]*?)\}")

# Human classification is intentional: a constructor name cannot tell whether
# a destination is useful on its own or needs a book, surah, reciter, etc.
SUPPORTED = {
    "AyahDownloadScreen", "AzkarScreen", "DownloadsScreen", "DorarHubScreen",
    "HajjScreen", "HifzScreen", "HomeScreen", "LibraryScreen", "MoreScreen",
    "QiblaScreen", "QuranAudioScreen", "QuranScreen", "RuqyahAudioScreen",
    "ShamelaScreen", "TajweedLevelsScreen", "TasbeehScreen",
}
MISSING_TOP_LEVEL = {
    "AboutScreen", "AdhanBackgroundScreen", "AdhanSettingsScreen",
    "BooksSearchScreen", "DedicationsScreen", "DorarHistoryScreen",
    "DorarScreen", "DorarSearchScreen", "DorarTafseerScreen",
    "JazariyyahLevelScreen", "KhatmaScreen", "MakharijScreen",
    "OnboardingScreen", "PrayerAdjustmentsScreen", "PrayerLocationScreen",
    "RuqyahScreen", "SciencesPackScreen", "SourcesScreen",
    "SplashPreviewScreen", "SupportScreen", "TamhidLevelScreen",
    "TuhfaLevelScreen",
}
NEEDS_DETAILS = {
    "AyahReciterScreen", "AzanPlayerScreen", "AzkarSectionScreen",
    "BookTextReaderScreen", "DorarChainScreen", "DorarSectionScreen",
    "DorarTocScreen", "HadeethEncCategoryScreen", "HadeethEncDetailScreen",
    "HadithBookScreen", "HadithChapterScreen", "HadithDetailScreen",
    "HifzSessionScreen", "LinkListManageScreen", "QuoteCardScreen",
    "ReciterScreen", "SearchScreen", "SingleSurahScreen",
}
INTERNAL_OR_LIFECYCLE = {
    "CardScreen", "PermissionsIntroScreen", "QuranAudioPlayerScreen",
    "SplashScreen",
}


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def main() -> None:
    declarations: dict[str, str] = {}
    routes: dict[str, set[str]] = {}
    for path in LIB.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        for name in CLASS_RE.findall(text):
            if not name.startswith("_"):
                declarations[name] = relative(path)
        for name in ROUTE_RE.findall(text):
            routes.setdefault(name, set()).add(relative(path))

    intent_text = INTENT.read_text(encoding="utf-8")
    match = ENUM_RE.search(intent_text)
    if match is None:
        raise SystemExit("AssistantScreen enum not found")
    enum_values = [
        value.strip()
        for value in match.group(1).split(",")
        if value.strip()
    ]
    categories = {
        **{name: "supported" for name in SUPPORTED},
        **{name: "missing top-level" for name in MISSING_TOP_LEVEL},
        **{name: "needs details" for name in NEEDS_DETAILS},
        **{name: "internal/lifecycle" for name in INTERNAL_OR_LIFECYCLE},
    }
    unclassified = sorted(set(declarations) - set(categories))
    stale = sorted(set(categories) - set(declarations))
    if unclassified or stale:
        raise SystemExit(
            f"classification mismatch: unclassified={unclassified}, stale={stale}"
        )

    print(f"Public *Screen classes: {len(declarations)}")
    print(f"MaterialPageRoute destinations: {len(routes)}")
    print(f"AssistantScreen values: {len(enum_values)}")
    print()
    print("| Screen class | Classification | Declared in | Route callers |")
    print("|---|---|---|---:|")
    for name, source in sorted(declarations.items()):
        callers = routes.get(name, set())
        print(f"| `{name}` | {categories[name]} | `{source}` | {len(callers)} |")
    print()
    print("AssistantScreen: " + ", ".join(f"`{v}`" for v in enum_values))


if __name__ == "__main__":
    main()
