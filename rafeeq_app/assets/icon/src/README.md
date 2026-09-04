# App icon — source

**P3‑39 update, current state:** the launcher icon is no longer generated
from the SVGs below. The owner sent a real AI-generated icon photo
(`E:\New folder\1788536019972.png`) with an explicit instruction to use it
**exactly, unedited** — not redrawn as vector art (an earlier attempt in
this same session added a bezel ring and touched-up detail on the old
SVG-based mark; the owner rejected that and asked for the literal photo
instead). The actual source now is that photo, square-cropped to just its
circular badge (dropping the "Rafeeq" text lockup below it, which isn't
part of the icon itself) with **no other processing** — no recolor, no
recomposite, no added ring — saved as `../app_icon.png` and
`../app_icon_foreground.png` (identical copies; `pubspec.yaml`'s
`adaptive_icon_background` is a plain solid color, `#071625`, not a second
image, so there's nothing else in the icon's visible art besides the
owner's own unedited pixels). `../../branding/app_mark.png` (the splash
badge) is the same crop too, so the badge in-app matches the launcher
icon exactly.

The SVG pipeline below (`icon_full.svg`/`icon_fg.svg`/`icon_bg.svg`) is
**not currently wired into the build** — kept as source history and a
reproducible fallback (e.g. if a future reference photo isn't licensed
for direct use), not as the live pipeline. Regenerating icons for the
*current* setup only needs re-cropping the reference photo and rerunning
`dart run flutter_launcher_icons`; the headless-Chrome steps below don't
apply until/unless the project switches back to the vector-art approach.

---

The launcher icon is designed as code so it stays reproducible.

| file | role |
|---|---|
| `icon_full.svg`  | full-bleed icon (teal→navy field + gold mark). Rendered to `../app_icon.png` (1024²) — used for iOS and the legacy Android icon. |
| `icon_fg.svg`    | adaptive **foreground**: the mark only, transparent, scaled into the centre safe zone. → `../app_icon_foreground.png`. |
| `icon_bg.svg`    | adaptive **background**: the teal→navy radial field. → `../app_icon_background.png`. |

The mark (2026‑09‑03 redesign) is a **mosque silhouette** — a central dome
topped with a crescent finial, two smaller flanking domes, two minarets, and
an arched doorway — standing in for "رفيق الدرب" (a place of prayer along the
path). Palette is the app's **actual** `AppColors` theme constants: night
navy `#071625`, primary teal `#0E7C61`/`#16A085`/`#0F3D33` for the background
glow, illuminated gold `#D4AF37`/`#E8C96A`-family gradients for the mark.

## Regenerate the PNGs (headless Chrome, no extra tooling)

```bash
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
BASE="$(pwd)"   # run from assets/icon/src/
for f in icon_full icon_bg; do
  "$CHROME" --headless --disable-gpu --no-sandbox --force-device-scale-factor=1 \
    --hide-scrollbars --screenshot="$BASE/$f.png" --window-size=1024,1024 "$BASE/$f.svg"
done
# icon_fg MUST render with a transparent page background, or Chrome bakes in
# an opaque white square that hides the adaptive background layer entirely
# (a real bug this project shipped once — caught 2026-09-03). The flag below
# is what fixes it:
"$CHROME" --headless --disable-gpu --no-sandbox --default-background-color=00000000 \
  --force-device-scale-factor=1 --hide-scrollbars \
  --screenshot="$BASE/icon_fg.png" --window-size=1024,1024 "$BASE/icon_fg.svg"
cp icon_full.png ../app_icon.png
cp icon_fg.png   ../app_icon_foreground.png
cp icon_bg.png   ../app_icon_background.png
```

Sanity-check `icon_fg.png` actually has alpha before relying on it — a corner
pixel should read `A=0`, not `A=255`:
```powershell
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile("icon_fg.png")
$img.GetPixel(10,10)   # expect Color [A=0, R=0, G=0, B=0]
```

Then regenerate the platform icons:

```bash
cd rafeeq_app && dart run flutter_launcher_icons
```

Config lives in `pubspec.yaml` under `flutter_launcher_icons:`.
`assets/icon/` is deliberately NOT in the Flutter `assets:` bundle — these
files are build-time only.
