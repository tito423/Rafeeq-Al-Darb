"""al-Da'as's own phrase on a word (quran_sciences.db irab_daas), cut from the
«quote» that names the word to the next «, and at the first full stop.
Used for the `daas` alt kept under every word changed by write_surah.GROUPB,
so the alt is the book's text, not our paraphrase of it."""
import os, re, sqlite3
from write_surah import H
_d = sqlite3.connect(os.path.join(H, '..', '..', 'rafeeq_app', 'assets', 'data', 'quran_sciences.db'))
_DI = re.compile('[\u064B-\u0652\u0670\u0653-\u0655\u06D6-\u06ED]')
# where the first matching quote is not the one about this word
NEEDLE = {(11, 19, 'هم'): '«هُمْ» ضمير فصل', (12, 4, 'سجدين'): '«ساجِدِينَ»',
          (17, 59, 'بٱلأيت'): '«بِالْآياتِ»', (25, 49, 'أنعما'): '«أَنْعاماً»',
          (4, 4, 'هنيـا'): '«هَنِيئاً مَرِيئاً»', (4, 4, 'مريـا'): '«هَنِيئاً مَرِيئاً»',
          (20, 110, 'علما'): '«عِلْماً»', (2, 170, 'ءاباءنا'): '«آباءَنا»'}
# where al-Da'as's sentence runs on past the next quote: cut at the full stop
EXTEND = {(3, 54, 'وٱلله'), (7, 186, 'من')}


def _b(t):
    return _DI.sub('', t).replace('ٱ', 'ا').replace('آ', 'ا').replace('أ', 'ا').replace('إ', 'ا').replace('ـ', '')


def quote(s, a, w):
    text = ' '.join(' '.join(t.split()) for (t,) in _d.execute(
        'select text from irab_daas where surah=? and ayah_from<=? and ayah_to>=?', (s, a, a)))
    start = text.find(NEEDLE[(s, a, w)]) if (s, a, w) in NEEDLE else -1
    if start < 0:
        for m in re.finditer('«([^»]*)»', text):
            q = _b(m.group(1)).replace(' ', '')
            if _b(w) in q:
                start = m.start()
                break
    if start < 0:
        return None
    end = text.find('«', text.find('»', start) + 1)
    if (s, a, w) in EXTEND:
        end = text.find('.', start) + 1
    cut = text[start: end if end > 0 else len(text)].strip()
    if '.' in cut:
        cut = cut[:cut.index('.') + 1]
    return cut
