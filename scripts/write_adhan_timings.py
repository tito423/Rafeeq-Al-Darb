"""Write `adhan_phrase_timings.json` from the listening verdicts.

Reads the reports `finalize_adhan_timings.py` wrote and keeps, per recording,
the timeline that read back best — only if it read back well enough. A
recording with no accepted timeline keeps its length and nothing else, and the
app then writes the whole adhan out instead of guessing line by line.

    py -3 scripts/write_adhan_timings.py <out.json> <report.json>[=<rename map>] ...

A rename map is `src.mp3:dst.mp3,...` for recordings judged under their
archive.org name and shipped under an `azanN` one.
"""
import json
import sys

MIN_MEAN = 0.55   # same bar as finalize_adhan_timings.py
MAX_WRONG = 2
BREATHS = [2, 2, 2, 2, 2, 1, 1]
BREATHS_FAJR = [2, 2, 2, 2, 2, 2, 1, 1]


def lines_from(breaths, per_line):
    out, k = [], 0
    for n in per_line:
        out.append(breaths[k])
        k += n
    return out


def main():
    out_path = sys.argv[1]
    result = {}
    for arg in sys.argv[2:]:
        path, _, ren = arg.partition('=')
        rename = dict(p.split(':') for p in ren.split(',') if p)
        report = json.load(open(path, encoding='utf-8'))
        for key, r in report.items():
            if rename and key not in rename:
                continue
            name = rename.get(key, key)
            ok = {n: j for n, j in r['judged'].items()
                  if j['mean'] >= MIN_MEAN and j['wrong'] <= MAX_WRONG}
            total_ms = int(round(r['total_s'] * 1000))
            entry = {'total_ms': total_ms}
            if ok:
                pick = max(ok, key=lambda n: ok[n]['mean'])
                ms = [int(round(t * 1000)) for t in r['candidates'][pick]]
                suffix = '_fajr' if r['fajr'] else ''
                per = BREATHS_FAJR if r['fajr'] else BREATHS
                entry.update({
                    'first_speech_ms': ms[0],
                    'last_speech_ms': total_ms,
                    'breaths' + suffix: ms,
                    'lines' + suffix: lines_from(ms, per),
                    'checked': {'timeline': pick, 'mean': ok[pick]['mean'],
                                'wrong': ok[pick]['wrong']},
                })
            else:
                entry.update({
                    'first_speech_ms': 0,
                    'last_speech_ms': total_ms,
                    'checked': {'timeline': None,
                                'note': 'no timeline read back well enough; '
                                        'the app shows the whole adhan'},
                })
            if r['fajr']:
                entry['fajr'] = True
            result[name] = entry
    with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
        f.write('\n')
    for k, v in result.items():
        print(k, v['checked'].get('timeline'), 'fajr' if v.get('fajr') else '')


if __name__ == '__main__':
    main()
