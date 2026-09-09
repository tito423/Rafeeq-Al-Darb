"""Search al-Maktaba al-Shamela for a book by title, and print what it finds.

Written because the alternative is guessing Shamela book ids, and a guessed id
silently fetches *a different book*. Every title the owner asks for gets looked
up here first, and only the id this prints goes into a catalogue entry.

    py -3 scripts/shamela_search.py "الرحيق المختوم" ["another title" ...]

Output goes to a UTF-8 file as well as stdout, because the Windows console is
cp1256 and dies on Arabic with UnicodeEncodeError.
"""

import io
import json
import os
import re
import sys
import urllib.parse
import urllib.request

UA = {
    "User-Agent": "Mozilla/5.0 (rafeeq-al-darb content pipeline)",
    "Accept-Language": "ar",
}

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "shamela_search_out.txt")


def get(url, tries=3):
    req = urllib.request.Request(url, headers=UA)
    for i in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read().decode("utf-8", "replace")
        except Exception as e:
            if i == tries - 1:
                return f"__ERROR__ {e}"
    return None


def search(title):
    """Shamela's book search. Returns [(book_id, title, author)]."""
    q = urllib.parse.quote(title)
    html = get(f"https://shamela.ws/search/books?q={q}")
    if html is None or html.startswith("__ERROR__"):
        return [], html
    # Book links look like /book/<id>; the anchor text is the title.
    hits = re.findall(
        r'<a[^>]+href="(?:https://shamela\.ws)?/book/(\d+)"[^>]*>\s*(.*?)\s*</a>',
        html,
        re.S,
    )
    seen, out = set(), []
    for bid, label in hits:
        label = re.sub(r"<[^>]+>", " ", label)
        label = re.sub(r"\s+", " ", label).strip()
        if bid in seen or not label:
            continue
        seen.add(bid)
        out.append((bid, label))
    return out, None


def book_meta(book_id):
    """Title/author line from a book's own page, to confirm an id is right."""
    html = get(f"https://shamela.ws/book/{book_id}")
    if html is None or html.startswith("__ERROR__"):
        return None
    title = re.search(r"<title>(.*?)</title>", html, re.S)
    title = re.sub(r"\s+", " ", title.group(1)).strip() if title else "?"
    # The first pageContent id, needed by fetch_shamela_pages.py
    return {"title": title}


def main():
    titles = sys.argv[1:]
    if not titles:
        raise SystemExit(__doc__)
    lines = []
    for t in titles:
        lines.append(f"===== {t} =====")
        hits, err = search(t)
        if err:
            lines.append(f"  ERROR: {err}")
        elif not hits:
            lines.append("  (no results)")
        for bid, label in hits[:12]:
            lines.append(f"  {bid:>7}  {label}")
        lines.append("")
    text = "\n".join(lines)
    with io.open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
