import json
d = json.load(open(r'e:\My Projects\Rafiq-Al-Darb\scripts\temp_phase1\tafsir_qc\91_ch1.json', encoding='utf-8-sig'))
open(r'e:\My Projects\Rafiq-Al-Darb\scripts\qc_sample.txt', 'w', encoding='utf-8').write(
    'TYPE:' + type(d).__name__ + ' KEYS:' + str(list(d.keys()) if isinstance(d, dict) else 'N/A')
    + ' SAMPLE:' + json.dumps(d, ensure_ascii=False)[:600])
print('OK')
