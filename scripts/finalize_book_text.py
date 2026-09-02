"""Post-processes the files in scripts/book_text_build/:
  * adds meta.printReliable (was added to the builder after the first run)
  * re-serialises compactly
  * prints the size + reliability of each, and a `catalog approxSizeBytes`
    line to paste into book_catalog.dart

    python scripts/finalize_book_text.py
"""
import io
import json
import os

BUILD_DIR = os.path.join(os.path.dirname(__file__), "book_text_build")


def print_reliable(pages, print_matches):
    nums = [p["p"] for p in pages if p["p"]]
    if not print_matches or len(nums) < 10:
        return False
    deltas = [b - a for a, b in zip(nums, nums[1:])]
    ok = sum(1 for d in deltas if d >= 0)
    return ok / len(deltas) >= 0.985 and min(deltas) >= -3


def main():
    for name in sorted(os.listdir(BUILD_DIR)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(BUILD_DIR, name)
        with io.open(path, "r", encoding="utf-8") as f:
            doc = json.load(f)
        meta = doc["meta"]
        meta["printReliable"] = print_reliable(doc["pages"], meta["printMatches"])
        with io.open(path, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
        size = os.path.getsize(path)
        nums = [p["p"] for p in doc["pages"] if p["p"]]
        mono = (
            sum(1 for a, b in zip(nums, nums[1:]) if b >= a) / (len(nums) - 1)
            if len(nums) > 1 else 0
        )
        print(f"{doc['id']:32}  {size:>8} B  pages={meta['pageCount']:>4}  "
              f"sections={meta['sectionCount']:>4}  "
              f"printReliable={meta['printReliable']!s:5}  monotonic={mono:.3f}")
        print(f"      approxSizeBytes: {size}, // built {name}")


if __name__ == "__main__":
    main()
