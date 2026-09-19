"""Build the Google Play listing images from real screenshots of the app.

    py -3 scripts/build_store_screenshots.py

Input:  store/google_play/screenshots/raw/*.png - captured on emulator-5554
        (1080x2400, Android demo mode for a clean status bar).
Output: store/google_play/screenshots/phone/NN_*.png   1080x1920 (9:16)
        store/google_play/feature_graphic.png           1024x500

Why HTML + headless Chrome and not PIL: this machine's Pillow has no raqm
and no arabic_reshaper, so it draws Arabic as unjoined letters. Chrome
shapes Arabic properly, and the page uses the app's own bundled fonts
(Cairo for the captions, Amiri Quran for the name).

Play's rules this satisfies: 2-8 phone screenshots, PNG/JPEG, each side
320-3840 px, the long side at most twice the short one (the raw 1080x2400
captures break that rule, which is one reason they are framed), and a
1024x500 feature graphic.
"""
import os
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, 'store', 'google_play')
RAW = os.path.join(STORE, 'screenshots', 'raw')
OUT = os.path.join(STORE, 'screenshots', 'phone')
FONTS = os.path.join(ROOT, 'rafeeq_app', 'assets', 'fonts')
ICON = os.path.join(ROOT, 'rafeeq_app', 'assets', 'icon', 'app_icon.png')
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'

# (output name, raw capture, headline, line under it). Every line describes
# what the screenshot beneath it really shows.
SHOTS = [
    ('01_home', '01_home', 'رفيقك في يومك',
     'مواقيت الصلاة والتاريخ الهجري والصلاة القادمة في لمحة'),
    ('02_mushaf', '02_quran', 'المصحف الشريف',
     'طبعات مصوّرة ونصية، تعمل دون إنترنت بعد التنزيل'),
    ('03_adhan', '12_adhan', 'الأذان في وقته',
     'شاشة أذان هادئة، ونص الأذان متزامن مع صوت المؤذن'),
    ('04_azkar', '04_azkar', 'أذكار اليوم والليلة',
     'من «الأذكار» للإمام النووي، مع تخريجها'),
    ('05_hadith', '07_hadith', 'الكتب التسعة داخل التطبيق',
     'مسانيد وسنن كاملة، مبوّبة وقابلة للبحث'),
    ('06_tajweed', '11_lesson', 'تعلّم التجويد من المتون',
     'التحفة والجزرية والتمهيد، واسمع الحكم في آية'),
    ('07_hajj', '08_hajj', 'مناسك الحج والعمرة',
     'خطوة بخطوة من «الإيضاح» للإمام النووي، برسوم تفاعلية'),
    ('08_more', '10_more', 'كل ما تحتاجه في مكان واحد',
     'التلاوات والرقية والإهداءات والتذكيرات، بلا إعلانات'),
]

CSS = """
@font-face { font-family: Cairo; src: url('%(fonts)s/google_fonts/Cairo-Bold.ttf'); font-weight: 700; }
@font-face { font-family: Cairo; src: url('%(fonts)s/google_fonts/Cairo-Regular.ttf'); font-weight: 400; }
@font-face { font-family: AmiriQuran; src: url('%(fonts)s/AmiriQuran-Regular.ttf'); }
html, body { margin: 0; padding: 0; }
body { width: %(w)dpx; height: %(h)dpx; overflow: hidden; direction: rtl;
  font-family: Cairo, sans-serif; color: #fff;
  background: radial-gradient(ellipse at 50%% 0%%, #1d4458 0%%, #0e2233 45%%, #070f19 100%%); }
.pattern { position: absolute; inset: 0; opacity: .07;
  background-image: radial-gradient(circle at 25px 25px, #d4af37 2px, transparent 2.5px);
  background-size: 50px 50px; }
"""

SHOT_HTML = """<!doctype html><html><head><meta charset="utf-8"><style>%(css)s
.cap { position: absolute; top: 70px; left: 60px; right: 60px; text-align: center; }
.cap h1 { margin: 0; font-size: 76px; font-weight: 700; color: #f1d27a; line-height: 1.35; }
.cap p { margin: 18px 0 0; font-size: 38px; font-weight: 400; color: #cfe3ea; line-height: 1.5; }
.phone { position: absolute; left: 50%%; top: 400px; transform: translateX(-50%%);
  width: 660px; height: 1467px; border-radius: 58px; overflow: hidden;
  border: 7px solid #c9a227; box-shadow: 0 30px 80px rgba(0,0,0,.6), 0 0 60px rgba(212,175,55,.25); }
.phone img { width: 100%%; height: 100%%; display: block; }
</style></head><body><div class="pattern"></div>
<div class="cap"><h1>%(title)s</h1><p>%(line)s</p></div>
<div class="phone"><img src="%(img)s"></div></body></html>"""

FEATURE_HTML = """<!doctype html><html><head><meta charset="utf-8"><style>%(css)s
.wrap { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; gap: 56px; }
.wrap img { width: 250px; height: 250px; border-radius: 56px; box-shadow: 0 16px 50px rgba(0,0,0,.55); }
.t h1 { margin: 0 0 26px; font-family: AmiriQuran, serif; font-size: 84px; font-weight: 400; color: #f1d27a; line-height: 1.6; }
.t p { margin: 0; font-size: 32px; color: #cfe3ea; line-height: 1.6; }
</style></head><body><div class="pattern"></div>
<div class="wrap"><img src="%(icon)s"><div class="t"><h1>رفيق الدرب</h1>
<p>القرآن والصلاة والأذكار والحديث<br>بلا إعلانات ولا تتبّع</p></div></div></body></html>"""


def url(path):
    return 'file:///' + path.replace('\\', '/')


def render(html, out, w, h):
    with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False,
                                     encoding='utf-8') as f:
        f.write(html)
        page = f.name
    try:
        subprocess.run([CHROME, '--headless=new', '--disable-gpu',
                        '--hide-scrollbars', '--force-device-scale-factor=1',
                        '--allow-file-access-from-files',
                        f'--window-size={w},{h}', f'--screenshot={out}',
                        url(page)], check=True, capture_output=True,
                       timeout=120)
    finally:
        os.remove(page)


def main():
    os.makedirs(OUT, exist_ok=True)
    fonts = url(FONTS)
    for name, raw, title, line in SHOTS:
        css = CSS % {'fonts': fonts, 'w': 1080, 'h': 1920}
        html = SHOT_HTML % {'css': css, 'title': title, 'line': line,
                            'img': url(os.path.join(RAW, raw + '.png'))}
        render(html, os.path.join(OUT, name + '.png'), 1080, 1920)
    css = CSS % {'fonts': fonts, 'w': 1024, 'h': 500}
    render(FEATURE_HTML % {'css': css, 'icon': url(ICON)},
           os.path.join(STORE, 'feature_graphic.png'), 1024, 500)


if __name__ == '__main__':
    main()
