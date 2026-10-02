import sys, time
from silma_tts.api import SilmaTTS
REF = 'E:/DevEnv/kids_voice/owner_ref_short_24k.wav'
REF_TEXT = 'يَا أَصْدِقَائِي الصِّغَارَ، تَعَالَوْا نَسْمَعْ مَعًا قِصَّةً جَمِيلَةً.'
tts = SilmaTTS(enable_normalizer=False, hf_cache_dir='E:/DevEnv/kids_voice/hf')
text = open(sys.argv[1], encoding='utf-8').read().strip()
t = time.time()
tts.infer(ref_file=REF, ref_text=REF_TEXT, gen_text=text, file_wave=sys.argv[2],
          normalize_numbers=False, nfe_step=32, speed=float(sys.argv[4]) if len(sys.argv) > 4 else 0.85, seed=int(sys.argv[3]) if len(sys.argv) > 3 else 7)
print('SECONDS', round(time.time() - t, 2))
