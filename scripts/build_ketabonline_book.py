"""Builds a Library text edition from جامع الكتب الإسلامية (ketabonline.com),
in the same JSON as build_book_text.py, for books Shamela does not carry.

WHY. Owner, 2026-10-03: «لو مش لقيت اللي انت عايزه في الشاملة شوفوا في اي
حتة». The Azhari aqidah shuruh - al-Bajuri's تحفة المريد, his شرح كفاية
العوام, نور الظلام - are not in Shamela's 8,598 books (searched by title,
rafeeq-control results/library/shamela_books.json); ketabonline has them.

HOW KETABONLINE SERVES A BOOK (read 2026-10-03 from book 102863):
    https://s2.ketabonline.com/books/<id>/<id>.data.zip
      -> <id>.data.json: {"meta": [{name, value}], "authors", "index": [{title,
         page_id, title_level}], "pages": [{"id", "page", "content": "<html>"}]}
  content markup: p.g-paragraph (a paragraph), p.g-title (a heading),
  div.g-table > div.g-cell (a line of verse, two halves), span.g-aya (Qur'an),
  span.g-square-brackets (a reference). A paragraph «••» divides a page's
  matn from its sharh; it is dropped. A line of underscores opens the
  muhaqqiq's footnotes (Shamela's convention, which ketabonline's texts come
  from); everything after it on the page is dropped, as build_book_text.py
  drops Shamela's hamesh.

    py -3 scripts/build_ketabonline_book.py <ketab_id> <book_id>
      -> scripts/book_text_build/<book_id>.json  (+ the raw zip in scripts/ketab_raw/)
"""
import gzip
import html
import io
import json
import os
import re
import sys
import urllib.request
import zipfile
from html.parser import HTMLParser
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "book_text_build")
RAW = os.path.join(HERE, "ketab_raw")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/126.0 (rafeeq-al-darb content pipeline)"

_CELL = re.compile(r'<div class="g-cell">(.*?)</div>', re.S)
_AYA = re.compile(r'<span class="g-aya">(.*?)</span>', re.S)
_REF = re.compile(r'<span class="g-square-brackets">(.*?)</span>', re.S)
_TAG = re.compile(r"<[^>]+>")
_RULE = re.compile(r"^[\s_ـ—–-]{5,}$")
# ketabonline's own page-number line, «صفحة ٥», set as a paragraph of the
# text in some books (نور الظلام: 162 of 162 pages)
_PAGE_MARK = re.compile(r"^صفحة\s+[٠-٩0-9]+\s*")


def text(h):
    return re.sub(r"\s+", " ", html.unescape(_TAG.sub("", h))).strip()


def fetch(kid):
    os.makedirs(RAW, exist_ok=True)
    path = os.path.join(RAW, f"{kid}.data.zip")
    if not os.path.exists(path):
        req = urllib.request.Request(
            f"https://s2.ketabonline.com/books/{kid}/{kid}.data.zip", headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=300) as r:
            data = r.read()
        # a read that timed out once left half a zip here, and every later
        # build failed on it («File is not a zip file», tahqiq_al_maqam)
        zipfile.ZipFile(io.BytesIO(data)).testzip()
        open(path + ".part", "wb").write(data)
        os.replace(path + ".part", path)
    z = zipfile.ZipFile(path)
    name = next(n for n in z.namelist() if n.endswith(".json"))
    return json.loads(z.read(name))


class _Blocks(HTMLParser):
    """Splits a page into its top-level blocks: (class, inner html)."""

    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.blocks, self.depth, self.cls, self.buf = [], 0, None, []

    def handle_starttag(self, tag, attrs):
        if self.depth == 0:
            self.cls, self.buf = dict(attrs).get("class") or "", []
        else:
            self.buf.append(self.get_starttag_text())
        self.depth += 1

    def handle_endtag(self, tag):
        self.depth -= 1
        if self.depth == 0:
            self.blocks.append((self.cls, "".join(self.buf)))
        else:
            self.buf.append(f"</{tag}>")

    def handle_data(self, data):
        if self.depth:
            self.buf.append(data)

    def handle_entityref(self, name):
        self.handle_data(f"&{name};")

    def handle_charref(self, name):
        self.handle_data(f"&#{name};")


def blocks(content):
    b = _Blocks()
    b.feed(content)
    b.close()
    return b.blocks


# Read 2026-10-03 off the raw HTML of 102632 / 103078 (rafeeq-control
# results/library/ketab_raw_peek.txt): a page's footnotes follow a block
# holding <div class="g-page-separator"> + <div class="g-page-footer">, and
# each is called from the text by <a class="g-footnote-link">(١)</a>, in
# منح الروض الأزهر inside a g-parentheses span of its own. Those footnotes
# are the modern editor's (al-Ghawji's «التعليق الميسر», d. 1434), so they
# go with their calls. Where a page has footnotes, a bare «[١]» at the end
# of a paragraph is a call too (نور الظلام).
_SEP = re.compile(r'class="g-page-(separator|footer)"')
_FN_CALL = re.compile(
    r'<span class="g-parentheses">\s*<a [^>]*g-footnote-link[^>]*>.*?</a>\s*</span>'
    r'|<a [^>]*g-footnote-link[^>]*>.*?</a>', re.S)
_FN_BARE = re.compile(r'<span class="g-square-brackets">\s*\[[٠-٩0-9]+\]\s*</span>')
_INNER_TITLE = re.compile(r'<div class="g-title[^"]*"\s*>(.*?)</div>', re.S)


def paras(content):
    out = []
    has_notes = bool(_SEP.search(content))
    for cls, inner in blocks(content):
        if _SEP.search(inner):
            break  # the editor's footnotes follow
        if "g-table" in cls:
            cells = [text(c) for c in _CELL.findall(inner)]
            t = " ... ".join(c for c in cells if c)
            if t:
                out.append({"t": t, "k": "body"})
            continue
        inner = _FN_CALL.sub("", inner)
        if has_notes:
            inner = _FN_BARE.sub("", inner)
        # a heading set inside the paragraph it opens (تحقيق المقام)
        for h in _INNER_TITLE.findall(inner):
            if text(h):
                out.append({"t": text(h), "k": "head"})
        inner = _INNER_TITLE.sub("", inner)
        # «••» divides matn from sharh; inside a paragraph (تحفة المريد) it
        # joins the two, so it splits them
        for part in inner.split("••"):
            _para(out, cls, part)
        if out and _RULE.match(out[-1]["t"]):
            out.pop()
            break  # the muhaqqiq's footnotes follow
    return out


def _para(out, cls, inner):
    t = _PAGE_MARK.sub("", text(inner))
    if not t:
        return
    if _RULE.match(t):
        out.append({"t": t, "k": "body"})  # paras() stops on it
        return
    if "g-title" in cls:
        out.append({"t": t, "k": "head"})
        return
    ayas = [text(a) for a in _AYA.findall(inner)]
    if ayas and sum(len(a) for a in ayas) >= 0.6 * len(t):
        ref = next((text(r) for r in _REF.findall(inner) if text(r)), "")
        out.append({"t": " ".join(ayas), "k": "aya", **({"r": ref} if ref else {})})
        return
    out.append({"t": t, "k": "body"})


def build(kid, book_id):
    d = fetch(kid)
    meta = {m["name"]: (m.get("value") or "") for m in d.get("meta") or []}
    card = "\n".join(f"{k}: {v}" if v else k for k, v in meta.items())
    pages, at = [], {}
    for pg in d["pages"]:
        at[pg["id"]] = len(pages)
        pages.append({"p": int(pg.get("page") or 0), "paras": paras(pg.get("content") or "")})
    toc = []
    for e in d.get("index") or []:
        i = at.get(e.get("page_id"))
        if i is None:
            continue
        toc.append({"title": e["title"].strip(), "page": pages[i]["p"], "pageIndex": i,
                    "level": max(0, int(e.get("title_level") or 1) - 1)})
    matches = "(موافق للمطبوع)" in meta
    doc = {
        "id": book_id,
        "schema": 1,
        "meta": {
            "titleAr": meta.get("الكتاب", d.get("title", "")),
            "authorAr": meta.get("المؤلف", ""),
            "sourceLabel": "جامع الكتب الإسلامية — " + "، ".join(
                v for v in (meta.get("الكتاب"), meta.get("المؤلف"), meta.get("الناشر") or meta.get("مطبعة"),
                            meta.get("الطبعة")) if v),
            "ketabId": kid,
            "ketabUrl": f"https://ketabonline.com/ar/books/{kid}",
            "printMatches": matches,
            "printReliable": matches,
            "editionCard": card,
            "pageCount": len(pages),
            "sectionCount": len(toc),
            "builtAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "builtFrom": "scripts/build_ketabonline_book.py (ketabonline.com data.zip)",
        },
        "toc": toc,
        "pages": pages,
    }
    os.makedirs(OUT, exist_ok=True)
    raw = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    path = os.path.join(OUT, book_id + ".json")
    open(path, "wb").write(gzip.compress(raw, compresslevel=9, mtime=0))
    return doc, path


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    doc, path = build(int(sys.argv[1]), sys.argv[2])
    n = sum(len(p["paras"]) for p in doc["pages"])
    print(f"{sys.argv[2]}: {len(doc['pages'])} pages, {len(doc['toc'])} sections, {n} paragraphs, "
          f"{os.path.getsize(path)} B\n{doc['meta']['editionCard']}")
