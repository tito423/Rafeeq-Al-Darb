"""Contrast of the Home cards' text over their faint ornament photograph.

The sunnah-surahs and quote-of-the-day cards
(core/widgets/ornament_backdrop.dart) paint one of the bundled ornament
scans over the card's OWN theme ground at a low opacity, and the text keeps
the theme's own tones. This composites that (sRGB srcOver, as Flutter blends)
with each scan's 0.5 % most extreme pixels - the brightest under light text,
the darkest under dark text - and prints the worst ratio of every tone, per
theme, at the strength the widget uses. Body text and secondary text must
clear 4.5 : 1.

    py -3 scripts/check_ornament_card_contrast.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SCANS = ROOT / "rafeeq_app/assets/quote_backgrounds"

# Which scans each card uses (ornament_backdrop.dart).
CARDS = {
    "sunan": ["../card_ornaments/muqarnas_band.jpg"],
    "quote": [
        "l_ornement_polychrome_met_dp146521.jpg",
        "ornament_sborn_k_slohov_ch_ozdob_v_ech_obdob_um_.jpg",
        "turquoise_muqarna_mba_lyon_1969_331.jpg",
    ],
}


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


def h(x):
    return tuple(int(x[i:i + 2], 16) for i in (0, 2, 4))


# the card grounds in the theme, text tones, the strength used.
THEMES = {
    "dark": dict(
        grounds=[h("0C2135"), h("071625")],  # card; hadith frame's far stop
        tones=dict(onSurface=h("F2F5F4"), variant=h("B7C4C0")),
        strength=0.20, bright=True),
    "rgb": dict(
        grounds=[h("0C1322")],
        tones=dict(onSurface=h("EFFCFA"), variant=h("A9CCC7")),
        strength=0.20, bright=True),
    "light": dict(
        grounds=[h("FFFFFF"), h("F6F8F7")],
        tones=dict(onSurface=h("12241E"), variant=h("4A5B55")),
        strength=0.15, bright=False),
}


# The quote card tints its ground with one of six accents at 10 %
# (home_quote_card.dart, _accents); only that card has those grounds.
ACCENTS = [h(a) for a in ("D4AF37", "16A085", "6C5FBC", "3F7A8C", "D4785A",
                          "2E9D6F")]


# The quote card draws its scan fainter (OrnamentBackdrop.quoteDark/Light):
# its tinted grounds leave less room.
QUOTE_STRENGTH = {"dark": 0.16, "rgb": 0.16, "light": 0.13}


def grounds(t, card):
    if card != "quote":
        return t["grounds"]
    return [over(a, 0.10, t["grounds"][0]) for a in ACCENTS]


def extreme(img, bright):
    px = sorted(img.getdata(), key=lum)
    k = max(1, len(px) // 200)
    return px[-k] if bright else px[k - 1]


def main():
    bad = 0
    for card, scans in CARDS.items():
        for name, t in THEMES.items():
            k = QUOTE_STRENGTH[name] if card == "quote" else t["strength"]
            for tone, c in t["tones"].items():
                worst = (99.0, "")
                for scan in scans:
                    img = Image.open(SCANS / scan).convert("RGB")
                    img.thumbnail((300, 300))
                    p = extreme(img, t["bright"])
                    for g in grounds(t, card):
                        r = ratio(c, over(p, k, g))
                        worst = min(worst, (r, scan))
                bad += worst[0] < 4.5
                flag = "" if worst[0] >= 4.5 else "  <-- below 4.5"
                print(f"{card:6} {name:5} {tone:9} {worst[0]:5.2f} : 1 at "
                      f"{k} (worst on {worst[1][:30]}){flag}")
    print("FAIL" if bad else "OK - every tone >= 4.5 : 1")


if __name__ == "__main__":
    main()
