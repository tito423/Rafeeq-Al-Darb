"""Can a phone-sized recogniser hear a recitation well enough to check it?

Measured before anything was built, and before anything was promised
(§1.1). «نعمل الاتنين ونجرب» (2026-09-22): this is the «نجرب».

WHAT IS MEASURED. Real recitations — the very MP3s the app downloads from
everyayah (Husary, 128 kbps) — are fed to a Whisper model fine-tuned on
Qur'an recitation, and what comes back is compared with the ayah as
`quran_local.db` holds it. Two numbers, because two things are being asked:

  * EXACT: the recognised word is the ayah's word letter for letter;
  * SAME SKELETON: the two differ only in the long vowels the Uthmani script
    leaves out — «السموت» for «السماوات», «العلمين» for «العالمين». For
    telling a reciter «you skipped a word», that is the same word.

Measured 2026-09-22 on 5 ayahs / 94 s of audio (al-Fatiha 1-2, al-Baqarah
255, al-Kahf 1, al-Ikhlas 1), model `OdyAsh/faster-whisper-base-ar-quran`
(a CTranslate2 build of `tarteel-ai/whisper-base-ar-quran`, Apache-2.0,
model.bin 145 MB int8):

    73 words: exact 67 (91.8%), same skeleton 72 (98.6%)
    94.1 s of audio in 12.1 s  ->  7.8x real time on this CPU

TWO TRAPS THIS RUN ALREADY HIT, both in the MEASUREMENT and not the model:
  * `quran_local.db` writes alif wasla (U+0671), which a naive
    «keep ا-ي only» filter deletes — «ٱللَّه» became «لله» and every such
    word was counted wrong. The first run read 51%; it was the ruler that
    was bent, not the model.
  * the database's ayah 1 of a surah carries the basmala, and the audio
    file does not — al-Ikhlas scored 0% until that was taken off.

SECOND RUN, `--hard` (2026-09-22): does it hold up, and does it catch a
mistake? Measured the same way, with ffmpeg making the harder inputs:

    same reciter (Husary), clean            al-Kahf 1   11/11 = 100%
    ANOTHER reciter (Alafasy)               al-Kahf 1   11/11 = 100%
    ANOTHER reciter (Alafasy)               al-Baqarah 255  49/50 = 98%
    phone-like (band-limited to 8 kHz, quieter)  al-Kahf 1   11/11 = 100%
    stopped after 12 s of a 60 s ayah        al-Baqarah 255   9/50 = 18%
      -> names the skipped words: «سنه ولا نوم له ما في السموت وما …»
    the WRONG ayah played against al-Kahf 1               1/11 = 9%
      -> rejects it instead of accepting anything

So it is not tied to one reciter, a phone's narrow band does not break it,
and both kinds of mistake a tasmee' screen must catch — a skip and a wrong
passage — show up as a plain drop in matched words.

WHAT IT DOES NOT MEASURE: a phone's CPU (this is a desktop), a learner's
voice (every file here is a professional reciter in a studio), and tajweed —
a mistake in madd or ghunnah is not a wrong WORD and nothing here would
catch it.

    py -3 -m pip install faster-whisper
    py -3 scripts/measure_quran_asr.py [--hard]
"""
import io
import os
import re
import sqlite3
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "rafeeq_app", "assets", "data", "quran_local.db")
WORK = os.path.join(ROOT, "scripts", "asr_probe")
FFMPEG = r"C:\Program Files\ShareX\ffmpeg.exe"
UA = "RafeeqAlDarb/3.56 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
MODEL = "OdyAsh/faster-whisper-base-ar-quran"
RECITER = "Husary_128kbps"
AYAHS = [(1, 1), (1, 2), (2, 255), (18, 1), (112, 1)]
# --hard: (label, file built by _build_hard, the ayah it is checked against)
HARD = [("same reciter, clean", "018001.wav", (18, 1)),
        ("another reciter (Alafasy)", "al_018001.wav", (18, 1)),
        ("another reciter (Alafasy)", "al_002255.wav", (2, 255)),
        ("phone-like: band-limited 8k, quieter", "noisy_018001.wav", (18, 1)),
        ("stopped after 12 s (a skip)", "half_002255.wav", (2, 255)),
        ("the WRONG ayah, against al-Kahf 1", "112001.wav", (18, 1))]

MARKS = re.compile(r"[\u064b-\u065f\u0670\u06d6-\u06ed\u0640]")
SUBS = [("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ى", "ي"), ("ة", "ه"),
        ("ؤ", "و"), ("ئ", "ي")]


def norm(t):
    t = t.replace("\u0671", "ا")  # alif wasla is a LETTER, not a mark
    t = MARKS.sub("", t)
    t = re.sub(r"[^\u0621-\u064a\s]", " ", t)
    for a, b in SUBS:
        t = t.replace(a, b)
    return [w for w in t.split() if w]


def skeleton(w):
    return re.sub(r"[اوي]", "", w)


def _check(exp, got):
    """What a tasmee' screen would say: how many words matched, which ones
    it would report as skipped, and what it heard in their place."""
    i = j = ok = 0
    missed, instead = [], []
    while i < len(exp) and j < len(got):
        if skeleton(exp[i]) == skeleton(got[j]):
            ok += 1
            i += 1
            j += 1
        elif j + 1 < len(got) and skeleton(exp[i]) == skeleton(got[j + 1]):
            instead.append(got[j])
            j += 1
        elif i + 1 < len(exp) and skeleton(exp[i + 1]) == skeleton(got[j]):
            missed.append(exp[i])
            i += 1
        else:
            missed.append(exp[i])
            instead.append(got[j])
            i += 1
            j += 1
    return ok, missed + exp[i:], instead


def _build_hard():
    """The harder inputs, made with ffmpeg from files already fetched: a
    second reciter, a phone-like narrow band, and a recitation cut short."""
    for name in ("002255", "018001"):
        mp3 = os.path.join(WORK, "al_" + name + ".mp3")
        wav = os.path.join(WORK, "al_" + name + ".wav")
        if not os.path.exists(wav):
            subprocess.run(["curl", "-sS", "-A", UA, "-o", mp3,
                            f"https://everyayah.com/data/Alafasy_128kbps/{name}.mp3"],
                           check=True)
            subprocess.run([FFMPEG, "-v", "quiet", "-y", "-i", mp3,
                            "-ar", "16000", "-ac", "1", wav], check=True)
    noisy = os.path.join(WORK, "noisy_018001.wav")
    if not os.path.exists(noisy):
        subprocess.run([FFMPEG, "-v", "quiet", "-y", "-i",
                        os.path.join(WORK, "018001.wav"), "-af",
                        "highpass=f=200,lowpass=f=3400,volume=0.6,"
                        "aresample=8000,aresample=16000",
                        "-ar", "16000", "-ac", "1", noisy], check=True)
    half = os.path.join(WORK, "half_002255.wav")
    if not os.path.exists(half):
        subprocess.run([FFMPEG, "-v", "quiet", "-y", "-i",
                        os.path.join(WORK, "002255.wav"), "-t", "12",
                        "-ar", "16000", "-ac", "1", half], check=True)


def main():
    from faster_whisper import WhisperModel

    os.makedirs(WORK, exist_ok=True)
    con = sqlite3.connect(DB)
    basmala = norm("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")

    def expected(s, a):
        row = con.execute(
            "select text_uthmani from ayahs where surah_id=? and ayah_number=?",
            (s, a)).fetchone()
        w = norm(row[0])
        # the file starts at the ayah; the database's first ayah carries the
        # basmala with it
        if s != 1 and a == 1 and w[:len(basmala)] == basmala:
            w = w[len(basmala):]
        return w

    model = WhisperModel(MODEL, device="cpu", compute_type="int8")

    def heard(wav):
        segs, _ = model.transcribe(os.path.join(WORK, wav), language="ar",
                                   beam_size=5)
        return norm(" ".join(x.text for x in segs))

    if "--hard" in sys.argv:
        _build_hard()
        rep = io.open(os.path.join(WORK, "hard.txt"), "w", encoding="utf-8")
        for label, wav, (s, a) in HARD:
            exp = expected(s, a)
            t0 = time.time()
            got = heard(wav)
            dt = time.time() - t0
            ok, missed, instead = _check(exp, got)
            rep.write(f"\n{label}  [{s}:{a}]  {ok}/{len(exp)} words = "
                      f"{100 * ok / len(exp):.0f}%   {dt:.1f}s\n")
            if missed:
                rep.write("   reported as skipped/mistaken: "
                          + " ".join(missed[:8]) + "\n")
            if instead:
                rep.write("   heard instead: " + " ".join(instead[:8]) + "\n")
        rep.close()
        sys.stdout.buffer.write(open(os.path.join(WORK, "hard.txt"), "rb").read())
        return

    out = io.open(os.path.join(WORK, "report.txt"), "w", encoding="utf-8")
    total = exact = loose = 0
    audio = proc = 0.0
    for s, a in AYAHS:
        name = f"{s:03d}{a:03d}"
        mp3 = os.path.join(WORK, name + ".mp3")
        wav = os.path.join(WORK, name + ".wav")
        if not os.path.exists(mp3):
            subprocess.run(["curl", "-sS", "-A", UA, "-o", mp3,
                            f"https://everyayah.com/data/{RECITER}/{name}.mp3"],
                           check=True)
        if not os.path.exists(wav):
            subprocess.run([FFMPEG, "-v", "quiet", "-y", "-i", mp3,
                            "-ar", "16000", "-ac", "1", wav], check=True)
        exp = expected(s, a)
        dur = os.path.getsize(wav) / 32000.0
        t0 = time.time()
        segs, _ = model.transcribe(wav, language="ar", beam_size=5)
        got = norm(" ".join(x.text for x in segs))
        dt = time.time() - t0
        audio += dur
        proc += dt
        i = j = e = l = 0
        while i < len(exp) and j < len(got):
            if exp[i] == got[j]:
                e += 1
                l += 1
                i += 1
                j += 1
            elif skeleton(exp[i]) == skeleton(got[j]):
                l += 1
                i += 1
                j += 1
            elif j + 1 < len(got) and skeleton(exp[i]) == skeleton(got[j + 1]):
                j += 1
            elif i + 1 < len(exp) and skeleton(exp[i + 1]) == skeleton(got[j]):
                i += 1
            else:
                i += 1
                j += 1
        total += len(exp)
        exact += e
        loose += l
        out.write(f"{s}:{a}  {len(exp)} words  exact {e}  same-skeleton {l}  {dt:.1f}s\n")
        out.write(f"   expected: {' '.join(exp)}\n   heard   : {' '.join(got)}\n")
    out.write(f"\nwords {total}: exact {exact} ({100 * exact / total:.1f}%), "
              f"same skeleton {loose} ({100 * loose / total:.1f}%)\n")
    out.write(f"{audio:.1f}s of audio in {proc:.1f}s -> {audio / proc:.1f}x real time\n")
    out.close()
    sys.stdout.buffer.write(open(os.path.join(WORK, "report.txt"), "rb").read())


if __name__ == "__main__":
    main()
