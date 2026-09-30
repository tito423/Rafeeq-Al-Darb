import sys
from silma_tts.api import SilmaTTS
REF = 'E:/DevEnv/kids_voice/owner_ref_short_24k.wav'
REF_TEXT = 'يَا أَصْدِقَائِي الصِّغَارَ، تَعَالَوْا نَسْمَعْ مَعًا قِصَّةً جَمِيلَةً.'
tts = SilmaTTS(enable_normalizer=False, hf_cache_dir='E:/DevEnv/kids_voice/hf')
for line in open('fix.txt', encoding='utf-8'):
    if not line.strip(): continue
    name, text = line.strip().split('|', 1)
    for seed in (11, 23):
        tts.infer(ref_file=REF, ref_text=REF_TEXT, gen_text=text, file_wave=f'f{name}_{seed}.wav',
                  normalize_numbers=False, nfe_step=32, speed=0.85, seed=seed)
        print('DONE', name, seed, flush=True)
