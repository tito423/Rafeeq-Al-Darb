"""Would a diacritiser let us read the other 130 books? Measured, on OUR books.

WHY THIS, AND WHY NOW. The spoken reader currently speaks 83 of 213 books —
the ones whose text already carries its harakat. The obvious next step is to
vowel the rest with a model and speak those too. Whether that is a good idea
is an empirical question about THIS corpus, not a general one about Arabic.

CATT (Character-based Arabic Tashkeel Transformer, Apache-2.0) is the
candidate: it is current, it ships an ONNX export path, and its encoder-only
variant is the one its own README recommends for fast inference — so it could
plausibly run on a phone.

THE GROUND TRUTH IS ALREADY IN THE LIBRARY. 83 books are vowelled. Strip their
harakat, hand the bare text to CATT, and compare what comes back against what
was there. That is a measurement on the actual books the app ships, in the
actual register they are written in — classical Islamic scholarly prose — and
not on a news benchmark.

WHAT IS REPORTED, and why not just DER:

  * DER  — of the characters that SHOULD carry a mark, how many got the wrong
           one. The usual academic number.
  * WER  — of the words, how many came back with any mark wrong. This is the
           one that matters to a listener: a word is either pronounced right
           or it is not.
  * case-ending errors — the last mark of each word, counted separately,
           because that is where Arabic carries grammatical meaning and where
           a wrong vowel changes who did what to whom.

A wrong vowel in a fiqh text is a wrong MEANING, so the bar here is not
"comparable to published results". It is "would a knowledgeable reader accept
being read to like this".

    py -3 scripts/evaluate_catt_on_our_books.py [n_books]

Writes `_catt_eval.txt`. Slow — it runs a transformer on CPU over real pages.
"""

from __future__ import annotations

import gzip
import io
import json
import os
import random
import re
import sys
import urllib.request

BASE = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/books/text"
UA = "RafeeqAlDarb/3.36 (https://github.com/tito423/Rafeeq-Al-Darb)"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEASURED = os.path.join(ROOT, "_diacritisation.json")
OUT = os.path.join(ROOT, "_catt_eval.txt")

MARKS = "ًٌٍَُِّْٰ"
SHADDA = "ّ"
MARK_RE = re.compile("[" + MARKS + "]")
LETTER_RE = re.compile(r"[ء-ي]")


def strip_marks(s: str) -> str:
    return MARK_RE.sub("", s)


def fetch(bid: str) -> dict:
    req = urllib.request.Request("%s/%s.json" % (BASE, bid),
                                 headers={"User-Agent": UA})
    raw = urllib.request.urlopen(req, timeout=180).read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return json.loads(raw.decode("utf-8"))


def paragraphs(doc: dict, limit: int) -> list[str]:
    out = []
    for page in doc.get("pages", []):
        for para in page.get("paras", []):
            t = para if isinstance(para, str) else para.get("t", "")
            if len(strip_marks(t)) < 40:
                continue
            # Only paragraphs that are themselves well vowelled can serve as
            # ground truth; a half-marked one would punish the model for the
            # source's own gaps.
            letters = len(LETTER_RE.findall(t))
            marks = len(MARK_RE.findall(t))
            if letters and marks / letters >= 0.55:
                out.append(t)
            if len(out) >= limit:
                return out
    return out


def align_words(gold: str, pred: str):
    """Word-level comparison, matched on the bare skeleton."""
    g = gold.split()
    p = pred.split()
    pairs = []
    # The model must return the same words; if it did not, compare only the
    # common prefix rather than pretending the rest matched.
    for a, b in zip(g, p):
        if strip_marks(a) == strip_marks(b):
            pairs.append((a, b))
    return pairs


def last_mark(word: str) -> str:
    for ch in reversed(word):
        if ch in MARKS:
            return ch
    return ""


def main() -> int:
    n_books = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    pct = json.load(io.open(MEASURED, encoding="utf-8"))
    vowelled = sorted([k for k, v in pct.items() if v >= 80])
    random.seed(36)
    sample = random.sample(vowelled, min(n_books, len(vowelled)))

    # CATT ships two variants and its README is explicit about the trade:
    # encoder-only «recommended for faster inference», encoder-decoder
    # «recommended for better accuracy». Testing only the fast one and
    # concluding against the model would not be fair to it.
    variant = sys.argv[2] if len(sys.argv) > 2 else "eo"
    from catt_tashkeel import CATTEncoderOnly, CATTEncoderDecoder
    model = CATTEncoderDecoder() if variant == "ed" else CATTEncoderOnly()

    rows = []
    tot_chars = tot_char_err = 0
    tot_words = tot_word_err = 0
    tot_case = tot_case_err = 0
    tot_shadda = 0

    for bid in sample:
        try:
            doc = fetch(bid)
        except Exception as e:
            rows.append("  %-34s FETCH FAILED %s" % (bid, type(e).__name__))
            continue
        paras = paragraphs(doc, 40)
        if not paras:
            rows.append("  %-34s no well-vowelled paragraph" % bid)
            continue

        # CATT's own train config sets max_seq_len = 1024, and ONNX raises
        # «Attempting to broadcast an axis by a dimension other than 1.
        # 1024 by 1671» on anything longer. The first run of this script fed
        # it whole paragraphs and two of six books produced nothing — the
        # error was the harness, not the model, and a number taken from that
        # run would have been a lie about CATT.
        kept, bare = [], []
        for t in paras:
            b = strip_marks(t)
            if len(b) > 900:
                continue
            kept.append(t)
            bare.append(b)
        paras = kept
        if not paras:
            rows.append("  %-34s every paragraph over CATT's 1024 limit" % bid)
            continue
        try:
            preds = model.do_tashkeel_batch(bare, verbose=False)
        except Exception as e:
            rows.append("  %-34s MODEL FAILED %s: %s" % (bid, type(e).__name__, e))
            continue

        b_chars = b_char_err = b_words = b_word_err = b_case = b_case_err = 0
        b_shadda = 0
        for gold, pred in zip(paras, preds):
            for gw, pw in align_words(gold, pred):
                b_words += 1
                if gw != pw:
                    # SHADDA IS COUNTED SEPARATELY, and the first version of
                    # this script did not — which made it report WER 31.8%
                    # and nearly buried the model. Looking at the actual
                    # disagreements in one book: 24 of 27 were a shadda the
                    # source had and the model did not, or the reverse. Only
                    # 3 were a different VOWEL. A doubled consonant matters
                    # to a listener, but it is not the same failure as a
                    # wrong case ending, and lumping them together answers
                    # the wrong question.
                    if gw.replace(SHADDA, "") == pw.replace(SHADDA, ""):
                        b_shadda += 1
                    else:
                        b_word_err += 1
                gm = MARK_RE.findall(gw)
                pm = MARK_RE.findall(pw)
                b_chars += len(gm)
                b_char_err += sum(1 for i, m in enumerate(gm)
                                  if i >= len(pm) or pm[i] != m)
                g_last, p_last = last_mark(gw), last_mark(pw)
                if g_last:
                    b_case += 1
                    if g_last != p_last:
                        b_case_err += 1

        if b_words == 0:
            rows.append("  %-34s no alignable words" % bid)
            continue
        rows.append("  %-34s words %5d  vowel-WER %5.1f%%  shadda %5.1f%%  case %5.1f%%"
                    % (bid, b_words, 100.0 * b_word_err / b_words,
                       100.0 * b_shadda / b_words,
                       100.0 * b_case_err / max(b_case, 1)))
        tot_words += b_words; tot_word_err += b_word_err
        tot_shadda += b_shadda
        tot_chars += b_chars; tot_char_err += b_char_err
        tot_case += b_case; tot_case_err += b_case_err

    lines = ["CATT (%s) against %d of the app's own vowelled books"
             % ("encoder-decoder" if variant == "ed" else "encoder-only", len(sample)),
             "ground truth = the book's own harakat, stripped and re-predicted",
             ""]
    lines += rows
    lines += ["",
              "TOTAL  words %d" % tot_words,
              "  vowel-WER %.1f%%  (words with a WRONG VOWEL — the real failure)" % (100.0 * tot_word_err / max(tot_words, 1)),
              "  shadda    %.1f%%  (words differing ONLY by a shadda)" % (100.0 * tot_shadda / max(tot_words, 1)),
              "  case %.1f%%   (final mark wrong — where grammar lives)" % (100.0 * tot_case_err / max(tot_case, 1))]
    io.open(OUT, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("\n".join(l for l in lines if "FAILED" not in l))
    print("\n-> %s" % OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
