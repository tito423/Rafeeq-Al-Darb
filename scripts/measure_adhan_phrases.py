"""Measure where each bundled adhan recording actually speaks.

The adhan screen used to lay its text over the WHOLE recording in proportion
to each phrase's length in letters. A muezzin does not recite in proportion
to letters — he holds «حيّ على الصلاة» far longer than «الله أكبر», pauses
between breaths, and recordings open and close on silence — so the text ran
ahead or behind: «ظهور النص بتاع الأذان ساعات بيقدّم أو يتأخر».

This reads each file with ffmpeg's `silencedetect` and writes, per asset:

* `speech`: the non-silent intervals, in ms, at the threshold that was used;
* `lines`: when the number of speech intervals equals the number of breaths
  the adhan is recited in (12, or 14 with «الصلاة خير من النوم»), the start
  of each subtitle line in ms. Otherwise absent — and the app falls back to
  proportional timing over the first-to-last speech span, never inventing a
  boundary it did not measure.

Breaths per line, as the adhan is recited in these recordings:
الله أكبر ×4 → 2 · الشهادتان → 2 + 2 · الحيعلتان → 2 + 2 · [الصلاة خير من
النوم → 2] · الله أكبر ×2 → 1 · لا إله إلا الله → 1.

    py -3 scripts/measure_adhan_phrases.py
"""
import json
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, 'rafeeq_app')
FFMPEG = r'C:\Program Files\ShareX\ffmpeg.exe'
OUT = os.path.join(APP, 'assets', 'data', 'catalogs', 'adhan_phrase_timings.json')

BREATHS = [2, 2, 2, 2, 2, 1, 1]
BREATHS_FAJR = [2, 2, 2, 2, 2, 2, 1, 1]


def speech_intervals(path, noise, gap):
    r = subprocess.run(
        [FFMPEG, '-hide_banner', '-i', path, '-af',
         f'silencedetect=noise={noise}dB:d={gap}', '-f', 'null', '-'],
        capture_output=True, text=True, encoding='utf-8', errors='replace')
    err = r.stderr
    dur = re.search(r'Duration: (\d+):(\d+):([\d.]+)', err)
    total = int(dur.group(1)) * 3600 + int(dur.group(2)) * 60 + float(dur.group(3))
    starts = [float(x) for x in re.findall(r'silence_start: ([\d.]+)', err)]
    ends = [float(x) for x in re.findall(r'silence_end: ([\d.]+)', err)]
    silences = list(zip(starts, ends + [total] * (len(starts) - len(ends))))
    speech = []
    t = 0.0
    for s, e in silences:
        if s - t > 0.25:
            speech.append((t, s))
        t = e
    if total - t > 0.25:
        speech.append((t, total))
    return total, speech


def lines_from(speech, breaths):
    if len(speech) != sum(breaths):
        return None
    out, i = [], 0
    for b in breaths:
        out.append(int(speech[i][0] * 1000))
        i += b
    return out


def main():
    catalog = json.load(open(os.path.join(APP, 'assets', 'data', 'catalogs', 'adhans.json'), encoding='utf-8'))
    result = {}
    for entry in catalog:
        asset = entry['asset']
        path = os.path.join(APP, *asset.split('/'))
        best = None
        for gap in (0.9, 0.7):
            for noise in range(-36, -13, 2):
                total, speech = speech_intervals(path, noise, gap)
                for fajr, breaths in ((False, BREATHS), (True, BREATHS_FAJR)):
                    lines = lines_from(speech, breaths)
                    if lines and best is None:
                        best = dict(noise=noise, gap=gap, fajr=fajr, total=total, speech=speech, lines=lines)
            if best:
                break
        if best is None:
            total, speech = speech_intervals(path, -30, 0.7)
            best = dict(noise=-30, gap=0.7, fajr=None, total=total, speech=speech, lines=None)
        rec = {
            'total_ms': int(best['total'] * 1000),
            'first_speech_ms': int(best['speech'][0][0] * 1000) if best['speech'] else 0,
            'last_speech_ms': int(best['speech'][-1][1] * 1000) if best['speech'] else int(best['total'] * 1000),
            'threshold_db': best['noise'],
            'min_gap_s': best['gap'],
        }
        if best['lines']:
            # A matching count can be a coincidence of the threshold. Keep the
            # lines only when every one lasts at least 3 s and none runs past
            # three times the median — azan12 matched 12 breaths with a last
            # line of 0.8 s and a second of 48 s, which is not an adhan.
            starts = best['lines']
            ends = starts[1:] + [rec['last_speech_ms']]
            durs = [e - s for s, e in zip(starts, ends)]
            med = sorted(durs)[len(durs) // 2]
            # And the closing «الله أكبر ×2» and «لا إله إلا الله» are one
            # breath each: longer than 0.8 of the other lines' median means
            # the boundaries fell in the wrong places.
            head = sorted(durs[:-2])[len(durs[:-2]) // 2]
            tail_ok = all(x <= 0.8 * head for x in durs[-2:])
            if all(x >= 3000 for x in durs) and max(durs) <= 3 * med and tail_ok:
                rec['lines_fajr' if best['fajr'] else 'lines'] = starts
                # AND the breath groups themselves, which is what the screen
                # actually needs. Collapsing twelve measured onsets into seven
                # line starts is why the text sat still while the muezzin
                # repeated: «الله أكبر» is recited four times in two breaths
                # and the screen only changed once. Twelve (or fourteen) is as
                # fine as this audio goes - the two takbirs inside one breath
                # have no silence between them to measure, and splitting them
                # would be inventing a boundary, which is the one thing this
                # script exists not to do.
                rec['breaths_fajr' if best['fajr'] else 'breaths'] = [
                    int(s0 * 1000) for s0, _ in best['speech']
                ]
            else:
                rec['rejected_lines'] = starts
        result[os.path.basename(asset)] = rec
        print(os.path.basename(asset), 'matched' if best['lines'] else 'span-only',
              'fajr' if best['fajr'] else '', len(best['speech']), 'intervals', rec['threshold_db'], 'dB')
    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump(result, fh, indent=1)
        fh.write('\n')


if __name__ == '__main__':
    main()
