from silma_tts.api import SilmaTTS
REF = 'E:/DevEnv/kids_voice/owner_ref_short_24k.wav'
REF_TEXT = 'يَا أَصْدِقَائِي الصِّغَارَ، تَعَالَوْا نَسْمَعْ مَعًا قِصَّةً جَمِيلَةً.'
tts = SilmaTTS(enable_normalizer=False, hf_cache_dir='E:/DevEnv/kids_voice/hf')
jobs = [('12a', 'فَأَنْجَى اللَّهُ نُوحًا وَمَنْ مَعَهُ فِي السَّفِينَةِ، وَجَعَلَهَا آيَةً لِلْعَالَمِينَ.', 0.85),
        ('12b', 'تَعَلَّمْنَا مِنْ نُوحٍ: الصَّبْرَ عَلَى الْخَيْرِ، وَأَنَّ طَاعَةَ اللَّهِ نَجَاةٌ.', 0.75)]
for name, text, sp in jobs:
    for seed in (23, 31):
        tts.infer(ref_file=REF, ref_text=REF_TEXT, gen_text=text, file_wave=f'e{name}_{seed}.wav',
                  normalize_numbers=False, nfe_step=32, speed=sp, seed=seed)
        print('DONE', name, seed, flush=True)
