# App icon — source

The launcher icon is designed as code so it stays reproducible.

| file | role |
|---|---|
| `icon_full.svg`  | full-bleed icon (teal→navy field + gold mark). Rendered to `../app_icon.png` (1024²) — used for iOS and the legacy Android icon. |
| `icon_fg.svg`    | adaptive **foreground**: the mark only, transparent, scaled into the centre safe zone. → `../app_icon_foreground.png`. |
| `icon_bg.svg`    | adaptive **background**: the teal→navy radial field. → `../app_icon_background.png`. |

The mark is a **rub‑el‑hizb** (۞, the classic Qur'anic 8‑point star, two
overlapped squares) as a guiding star, with a receding **path** beneath it —
"رفيق الدرب" = companion of the path. Palette is the app's own night‑teal
(`#0C2C29`/`#06121E`) + illuminated gold (`#D4AF37`).

## Regenerate the PNGs (headless Chrome, no extra tooling)

```bash
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
for f in icon_full icon_fg icon_bg; do
  "$CHROME" --headless --disable-gpu --force-device-scale-factor=1 \
    --hide-scrollbars --screenshot="$f.png" --window-size=1024,1024 "$f.svg"
done
cp icon_full.png ../app_icon.png
cp icon_fg.png   ../app_icon_foreground.png
cp icon_bg.png   ../app_icon_background.png
```

Then regenerate the platform icons:

```bash
cd rafeeq_app && dart run flutter_launcher_icons
```

Config lives in `pubspec.yaml` under `flutter_launcher_icons:`.
`assets/icon/` is deliberately NOT in the Flutter `assets:` bundle — these
files are build-time only.
