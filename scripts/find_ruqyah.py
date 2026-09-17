"""Find the six ruqyah duas inside an-Nawawi's al-Adhkar.

`ruqyah_catalog.dart` addresses them by Hisn al-Muslim row id. Rebuilding
`azkar_items` from a different book would leave those six ids pointing at
whatever happens to land on that row — «a mis-typed id shows up as a missing
dua, not a wrong one» stops being true the moment the table is rebuilt. So each
one has to be located in the new source first, by its text.
"""
import json, re, io, sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# Distinctive fragments, diacritics stripped — the catalogue's own comments.
WANTED = {
    176: "لا بأس طهور",
    177: "رب العرش العظيم أن يشفيك",
    274: "من شر ما أجد وأحاذر",
    247: "التامات من شر ما خلق",
    278: "لا يجاوزهن بر ولا فاجر",
    137: "التامة من غضبه وعقابه",
}

DIAC = re.compile(r"[ً-ْٰـ]")


def bare(s):
    s = DIAC.sub("", s)
    for a, b in (("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ى", "ي"), ("ة", "ه")):
        s = s.replace(a, b)
    return re.sub(r"\s+", " ", s)


doc = json.load(open("_azkar_adhkar.json", encoding="utf-8"))
for old_id, frag in WANTED.items():
    f = bare(frag)
    hits = []
    for si, s in enumerate(doc["sections"]):
        for ii, it in enumerate(s["items"]):
            if f in bare(it["text"]):
                hits.append((si, ii, s["title"], it["no"], it["text"]))
    print("=" * 78)
    print("old id %d  «%s»  -> %d hit(s)" % (old_id, frag, len(hits)))
    for si, ii, title, no, text in hits[:3]:
        print("   section %d item %d  (no=%s)  «%s»" % (si, ii, no, title))
        i = bare(text).find(f)
        print("      …%s…" % text[max(0, i - 160):i + 220])
