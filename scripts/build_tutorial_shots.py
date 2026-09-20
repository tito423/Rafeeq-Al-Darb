"""Resize the Play-Store screenshots into the gallery the app bundles.

«حط بالله الصور بتاعة البلاي استور في شرح ميزات التطبيق» (2026-09-21).

`store/google_play/screenshots/phone/` holds eight 1080x1920 PNGs, 6.70 MB
together - too much to put in an install that has just spent a day getting
smaller. At 540x960 JPEG q82 the same eight are 0.42 MB, and a screenshot of
a phone screen shown INSIDE a phone screen has no use for the other pixels.

    py -3 scripts/build_tutorial_shots.py

Run it again whenever the store set is reshot; `FeatureGalleryScreen` reads
whatever is in `assets/tutorial_shots/` by name.
"""
import glob
import os

from PIL import Image

SRC = os.path.join('store', 'google_play', 'screenshots', 'phone')
DST = os.path.join('rafeeq_app', 'assets', 'tutorial_shots')
BOX = (540, 960)
QUALITY = 82


def main() -> int:
    shots = sorted(glob.glob(os.path.join(SRC, '*.png')))
    if not shots:
        print('no screenshots in %s' % SRC)
        return 1
    os.makedirs(DST, exist_ok=True)

    raw = 0
    packed = 0
    for path in shots:
        raw += os.path.getsize(path)
        image = Image.open(path).convert('RGB')
        image.thumbnail(BOX, Image.LANCZOS)
        name = os.path.basename(path).replace('.png', '.jpg')
        out = os.path.join(DST, name)
        image.save(out, 'JPEG', quality=QUALITY, optimize=True,
                   progressive=True)
        size = os.path.getsize(out)
        packed += size
        print('%-18s %-10s %8d B' % (name, '%dx%d' % image.size, size))

    print('%d shots: %.2f MB -> %.2f MB'
          % (len(shots), raw / 1048576, packed / 1048576))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
