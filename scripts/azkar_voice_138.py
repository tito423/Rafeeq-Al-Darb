"""Voice dhikr 138 (sleep): «يقرأ الم تنزيل (السجدة) وتبارك الذي بيده الملك (الملك)».

azkar_voice_all.py skipped it on purpose (SKIP = {138}): its «...» are surah
titles, an instruction to recite two whole surahs, not words of the dhikr.
The listen button therefore plays those two surahs complete - basmala, then
As-Sajdah 32:1-30; basmala, then Al-Mulk 67:1-30 - from the same reciter and
source as every other Qur'an passage in the adhkar (Mishary Alafasy,
everyayah.com 128 kbps, one whole-ayah file each). Nothing synthetic, no
instruction line voiced. Updates items.json and quran_map.json.

    py -3 scripts/azkar_voice_138.py            (from the repo root)
"""
import hashlib, json, os, sqlite3, subprocess

from azkar_voice_all import FF, ITEMS, OUT, ayah_mp3, secs, to_wav

ITEM = 138
SURAHS = (32, 67)


def main():
    q = sqlite3.connect('rafeeq_app/assets/data/quran_local.db')
    gap = f'{OUT}/gap.wav'
    if not os.path.exists(gap):
        subprocess.run([FF, '-y', '-loglevel', 'error', '-f', 'lavfi', '-i', 'anullsrc=r=24000:cl=mono',
                        '-t', '0.5', gap], check=True)
    basmala = to_wav(ayah_mp3(1, 1), f'{OUT}/q001001.wav')
    parts, qs = [], []
    for s in SURAHS:
        count = q.execute('select count(*) from ayahs where surah_id = ?', (s,)).fetchone()[0]
        parts += [basmala, gap]
        for a in range(1, count + 1):
            parts.append(to_wav(ayah_mp3(s, a), f'{OUT}/q{s:03d}{a:03d}.wav'))
            qs.append((s, a))
        parts.append(gap)
        print(f'surah {s}: {count} ayahs', flush=True)
    mp3 = f'{ITEMS}/{ITEM}.mp3'
    lst = f'{ITEMS}/{ITEM}.txt'
    open(lst, 'w', encoding='utf-8').write(''.join(f"file '{os.path.abspath(p)}'\n" for p in parts))
    subprocess.run([FF, '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', lst,
                    '-ac', '1', '-ar', '44100', '-b:a', '96k', mp3], check=True)
    os.remove(lst)
    data = open(mp3, 'rb').read()
    items_path = f'{OUT}/items.json'
    items = json.load(open(items_path, encoding='utf-8'))
    items[str(ITEM)] = {'seconds': round(secs(mp3), 2), 'bytes': len(data),
                        'sha1': hashlib.sha1(data).hexdigest()}
    json.dump(items, open(items_path, 'w', encoding='utf-8'), indent=1)
    qmap_path = f'{OUT}/quran_map.json'
    qmap = json.load(open(qmap_path, encoding='utf-8'))
    qmap[str(ITEM)] = qs
    json.dump(qmap, open(qmap_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'{ITEM} ok {items[str(ITEM)]["seconds"]} s, {len(qs)} ayahs, items {len(items)}', flush=True)


if __name__ == '__main__':
    main()
