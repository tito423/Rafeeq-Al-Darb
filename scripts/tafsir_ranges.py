"""Which ayahs each cached tafsir passage covers.

api.quran.com (`tafsirs/{id}/by_chapter`) keys a passage that explains
several ayahs by the FIRST ayah of the group: Muyassar's commentary on
37:161-163 comes back once, as `37:161`, and the next passage is `37:164`.
Checked live 2026-10-21 against `by_ayah`, whose `verses` list gives the
real group: 13 of 13 sampled groups in Muyassar, al-Tantawi and al-Qurtubi
start at the key and end the ayah before the next key. In Ibn Kathir,
al-Tabari and al-Sa'di the API answers 503 for an ayah inside a gap; their
cached text shows the earlier passage covering it (al-Tabari 26:16 cites
«فأتيا فرعون فقولا ... الآية» for 26:16-17, Ibn Kathir 53:14 quotes
53:13-15), the same rule.

Until 2026-10-21 `build_sciences_db.py` read the key as the LAST ayah, so a
grouped passage was attached to the ayahs before it: 37:162 showed the
commentary on 37:164-166. Measured on the shipped v2 pack: Muyassar 897
ayahs wrong or empty, al-Tantawi 119, al-Sa'di 56, al-Tabari 40, Ibn Kathir
31, al-Qurtubi 1.

CONFIRMED vs not. For Muyassar, al-Tantawi and al-Qurtubi the API answers
an inner ayah with the whole group (200 + `verses`), so a gap IS a group and
the passage runs to the ayah before the next key (and the surah's last
passage to the surah's end; 12 of 12 sampled tails matched). For Ibn
Kathir, al-Tabari and al-Sa'di the API answers 503 for every sampled gap
ayah, and a gap there is sometimes missing data, not a group: al-Tabari
comments on 37:12-24 ayah by ayah in print, yet the API holds only 37:11 for
that stretch. So for those three a gap ayah joins the passage before it
only while that passage QUOTES it (`quoted`: three consecutive words of the
ayah, spelling-insensitive, inside the passage); the first unquoted ayah
ends the passage and it and the rest of the gap get no row - no tafsir
from that source rather than another ayah's.

The cache is complete (every chapter starts at ayah 1; per_page=300, see
`fetch_tafsirs_complete.py`); `ranges` refuses a chapter that does not
start at 1 instead of stretching a partial one.
"""
import re


def covered_for(src, surah):
    return {a for s, c, a in VERIFIED_COVERED if s == src and c == surah}


UNCONFIRMED = frozenset({'ibn_kathir', 'tabari', 'sadi'})

# Gap ayahs read by hand (2026-10-21) and found covered by the passage
# before them although no three words of the ayah are quoted in it:
#   al-Sa'di 79:45 explains 45-46 and closes the surah with «[تمت]».
#   al-Sa'di 109:3 ends «ثم كرر ذلك ...», his comment on the repetition
#   in 109:4 (109:5 has its own entry).
# (al-Sa'di 12:110 was read too: it does not reach 12:111, so 12:111 stays
# without al-Sa'di.)
VERIFIED_COVERED = frozenset({('sadi', 79, 46), ('sadi', 109, 4)})


def _norm(t):
    t = re.sub(r'<[^>]+>', ' ', t)
    t = re.sub('[ؐ-ًؚ-ٰٟۖ-ۭـ]', '', t)
    # Uthmani rasm vs the books' imla'i spelling differ mostly in alifs,
    # hamza seats and weak letters (ٱلْأَلْبَٰبِ / الألباب): drop them on both.
    t = re.sub('[اأإآٱءئؤىيو]', '', t).replace('ة', 'ه')
    return ' '.join(re.sub(r'[^ء-ي ]', ' ', t).split())


def quoted(passage, ayah_text):
    """True when three consecutive words of the ayah appear in the passage."""
    p = _norm(passage)
    w = _norm(ayah_text).split()
    if len(w) < 3:
        return ' '.join(w) in p
    return any(' '.join(w[j:j + 3]) in p for j in range(len(w) - 2))


def ranges(keys_texts, surah_len, ayah_text=None, covered=()):
    """[(ayah_key, text)] -> [(start, end, text)] for one surah.

    Entries with empty text are the inner ayahs of a group (al-Tantawi sends
    them), so they belong to the passage before them and are dropped.
    `ayah_text` (ayah -> text) switches on the UNCONFIRMED rule above: a gap
    ayah stays with the passage only while the passage quotes it, or is in
    `covered` (the surah's ayahs from VERIFIED_COVERED).
    """
    rows = sorted((a, t) for a, t in keys_texts if t)
    if not rows:
        return []
    if rows[0][0] != 1:
        raise ValueError('chapter does not start at ayah 1: %r' % rows[0][0])
    out = []
    for i, (a, t) in enumerate(rows):
        end = rows[i + 1][0] - 1 if i + 1 < len(rows) else surah_len
        if end < a:
            raise ValueError('bad range %d-%d' % (a, end))
        if ayah_text is not None:
            last = a
            while last < end and (last + 1 in covered
                                  or quoted(t, ayah_text[last + 1])):
                last += 1
            end = last
        out.append((a, end, t))
    return out
