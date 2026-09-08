"""Fetch the whole Musnad Ahmad from the Arna'ut edition on Shamela.

Why this book needs its own fetch: the app's hadith database is built from
A7med3bdulBaset/hadith-json, whose Musnad Ahmad is only 1,374 hadiths in 8
chapters -- chapters 8 to 30 are simply absent upstream (the file's own
metadata says `length: 1374`, so it is not a truncated download). The owner
asked for two things that this one source answers together:

  * the missing content -- the real Musnad is ~27,000 hadiths, not 1,374;
  * a real takhrij, "زي الالباني ومحمود شاكر والاناؤوط".

`مسند أحمد - ط الرسالة` (Shamela book 25794, تحقيق شعيب الأرناؤوط ومن معه) is
the edition that carries both: the complete Musnad, its musnad-by-companion
structure, and Arna'ut's ruling printed under each hadith. Taking text,
structure and grading from one named edition also means the app can cite one
edition for all three rather than stitching sources together.

This script only downloads and stores pages verbatim, one JSON object per line,
and can be re-run to resume -- parsing is a separate step so a parser change
never costs another 23,340 requests.
"""
import io
import json
import os
import queue
import sys
import threading
import time
import urllib.error
import urllib.request

BOOK_ID = 25794
LAST_PAGE = 23340          # measured by binary search against the API
WORKERS = 12               # modest enough to stay polite; this is someone else's server
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "musnad_ahmad_arnaut_pages.jsonl")

_lock = threading.Lock()
_done = 0


def fetch(pid, tries=5):
    url = f"https://shamela.ws/ajax/pageContent/{BOOK_ID}/{pid}"
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (rafeeq-al-darb content pipeline)",
        "X-Requested-With": "XMLHttpRequest",
    })
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8", "replace"))
        except Exception:
            if attempt == tries - 1:
                return None
            time.sleep(1.5 * (attempt + 1))
    return None


def main():
    have = set()
    if os.path.exists(OUT):
        with io.open(OUT, encoding="utf-8") as f:
            for line in f:
                try:
                    have.add(json.loads(line)["pageId"])
                except Exception:
                    pass
    todo = [p for p in range(1, LAST_PAGE + 1) if p not in have]
    print(f"{len(have)} pages already stored, {len(todo)} to fetch")
    if not todo:
        return

    q = queue.Queue()
    for p in todo:
        q.put(p)
    out = io.open(OUT, "a", encoding="utf-8", newline="\n")

    def worker():
        global _done
        while True:
            try:
                pid = q.get_nowait()
            except queue.Empty:
                return
            d = fetch(pid)
            with _lock:
                if d is not None:
                    d["pageId"] = pid
                    out.write(json.dumps(d, ensure_ascii=False) + "\n")
                _done += 1
                if _done % 500 == 0:
                    out.flush()
                    print(f"  {_done}/{len(todo)}", flush=True)
            q.task_done()

    threads = [threading.Thread(target=worker, daemon=True) for _ in range(WORKERS)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    out.flush()
    out.close()
    print(f"done: {_done} pages fetched into {OUT}")


if __name__ == "__main__":
    sys.exit(main())
