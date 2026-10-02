import sys, time
from silma_tts.api import SilmaTTS
REF = 'E:/DevEnv/kids_voice/owner_ref_short_24k.wav'
REF_TEXT = 'يَا أَصْدِقَائِي الصِّغَارَ، تَعَالَوْا نَسْمَعْ مَعًا قِصَّةً جَمِيلَةً.'
tts = SilmaTTS(enable_normalizer=False, hf_cache_dir='E:/DevEnv/kids_voice/hf')
lines = [l.strip() for l in open('lines.txt', encoding='utf-8') if l.strip()]
for i, text in enumerate(lines, 1):
    t = time.time()
    tts.infer(ref_file=REF, ref_text=REF_TEXT, gen_text=text, file_wave=f'n{i:02d}.wav',
              normalize_numbers=False, nfe_step=32, speed=0.85, seed=7)
    print('LINE', i, round(time.time() - t, 1), flush=True)
