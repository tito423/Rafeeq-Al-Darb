"""Download every page of one Shamela book, verbatim and resumably.

Pages are stored one JSON object per line exactly as the API returns them,
plus the pageId, so parsing is always a separate step: changing how a book is
parsed never costs another crawl of someone else's server.

    py -3 scripts/fetch_shamela_pages.py <book_id> <last_page> <out.jsonl>

`last_page` is found by binary search against the API (a missing page errors),
which is how 23,340 was measured for the Arna'ut Musnad.
"""
import io
import json
import os
import queue
import sys
import threading
import time
import urllib.request

WORKERS = 12               # polite enough for a public library's server

_lock = threading.Lock()
_done = 0


def fetch(book_id, pid, tries=5):
    url = f"https://shamela.ws/ajax/pageContent/{book_id}/{pid}"
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


def run(book_id, last_page, out_path):
    global _done
    have = set()
    if os.path.exists(out_path):
        with io.open(out_path, encoding="utf-8") as f:
            for line in f:
                try:
                    have.add(json.loads(line)["pageId"])
                except Exception:
                    pass
    todo = [p for p in range(1, last_page + 1) if p not in have]
    print(f"{len(have)} pages already stored, {len(todo)} to fetch")
    if not todo:
        return 0

    q = queue.Queue()
    for p in todo:
        q.put(p)
    out = io.open(out_path, "a", encoding="utf-8", newline="\n")

    def worker():
        global _done
        while True:
            try:
                pid = q.get_nowait()
            except queue.Empty:
                return
            d = fetch(book_id, pid)
            with _lock:
                if d is not None:
                    d["pageId"] = pid
                    out.write(json.dumps(d, ensure_ascii=False) + "\n")
                _done += 1
                if _done % 500 == 0:
                    out.flush()
                    print(f"  {_done}/{len(todo)}", flush=True)

    threads = [threading.Thread(target=worker, daemon=True) for _ in range(WORKERS)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    out.flush()
    out.close()
    print(f"done: {_done} pages into {out_path}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)
    sys.exit(run(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]))
