"""Contrast of the Home prayer card's text on its washed photograph.

The card (home_prayer_card.dart) lays ONE prayer photograph under the whole
card and washes it with the theme's hero colours; text sits on the wash, and
the slides add a glass pane. This composites exactly that (sRGB srcOver, the
way Flutter blends) for every photograph and reports the worst contrast of
every text tone, using the photograph's 0.5 % most extreme pixels (brightest
under light text, darkest under dark text) at EVERY stop of the wash.

What is checked where, as the card really uses it:
  card  - the text drawn straight on the wash (onSurface, muted): 4.5 : 1
  pill  - the countdown's digits in the prayer's tone, on its pill: 4.5 : 1
  glass - a slide's name/time (onSurface, muted): 4.5 : 1; its prayer-tone
          icon: 3 : 1 (WCAG 1.4.11, non-text)

    py -3 scripts/check_prayer_card_contrast.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PHOTOS = ROOT / "rafeeq_app/assets/prayer_backgrounds"


def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lum(rgb):
    r, g, b = (lin(x) for x in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def over(top, alpha, under):
    return tuple(t * alpha + u * (1 - alpha) for t, u in zip(top, under))


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


THEMES = {
    "dark": {
        "wash": [(hexrgb("0B0F1A"), 0.76), (hexrgb("102A3A"), 0.83),
                 (hexrgb("1B1533"), 0.87)],
        "glass": ((0, 0, 0), 0.32),
        "pill": ((0, 0, 0), 0.45),
        "text": {
            "onSurface": hexrgb("FFFFFF"),
            "muted": hexrgb("B9C6C3"),
            "fajr": hexrgb("AE91FF"),
            "sunrise": hexrgb("B49F98"),
            "dhuhr": hexrgb("74AAC5"),
            "asr": hexrgb("5CB38F"),
            "maghrib": hexrgb("D4AF37"),
            "isha": hexrgb("15C7B0"),
        },
        "worst": "bright",
    },
    "light": {
        "wash": [(hexrgb("FAFDFC"), 0.80), (hexrgb("DFEFEA"), 0.84),
                 (hexrgb("E9E5F5"), 0.88)],
        "glass": ((255, 255, 255), 0.62),
        "pill": ((255, 255, 255), 0.60),
        "text": {
            "onSurface": hexrgb("10231D"),
            "muted": hexrgb("3A4B45"),
            "fajr": hexrgb("6742D4"),
            "sunrise": hexrgb("715B51"),
            "dhuhr": hexrgb("256684"),
            "asr": hexrgb("206C4D"),
            "maghrib": hexrgb("6D6023"),
            "isha": hexrgb("0D6C5F"),
        },
        "worst": "dark",
    },
}


def extreme(img, bright):
    px = sorted(img.convert("RGB").getdata(), key=lum)
    k = max(1, len(px) // 200)
    pick = px[-k:] if bright else px[:k]
    return pick[0] if bright else pick[-1]


def main():
    worst = {}
    for photo in sorted(PHOTOS.glob("*.jpg")):
        img = Image.open(photo).convert("RGB")
        img.thumbnail((300, 300))
        for name, t in THEMES.items():
            p = extreme(img, t["worst"] == "bright")
            for wash in t["wash"]:
                ground = over(wash[0], wash[1], p)
                for layer, g in (("card", ground),
                                 ("glass", over(*t["glass"], ground)),
                                 ("pill", over(*t["pill"], ground))):
                    for tone, c in t["text"].items():
                        if layer == "card" and tone not in ("onSurface", "muted"):
                            continue
                        r = ratio(c, g)
                        key = (name, layer, tone)
                        if key not in worst or r < worst[key][0]:
                            worst[key] = (r, photo.stem)
    bad = 0
    for (name, layer, tone), (r, stem) in sorted(worst.items()):
        need = 3.0 if layer == "glass" and tone not in ("onSurface", "muted") else 4.5
        flag = "" if r >= need else f"  <-- below {need}"
        bad += r < need
        print(f"{name:5} {layer:5} {tone:9} {r:5.2f} : 1  (worst on {stem}){flag}")
    print("FAIL" if bad else "OK - every tone clears its bar")


if __name__ == "__main__":
    main()
