"""Read the splash's own wordmark aloud, correctly.

«غير الصوت لانه بيقرا غلط فغيره للنص المكتوب كله» — the clip's own voice
mispronounces the name, and a voice cannot be re-recorded here, so this speaks
exactly what the video writes on screen.

The machine's TLS is intercepted by Avast (CLAUDE.md trap #13), which breaks
every Python HTTPS client including the one underneath edge-tts. The fix is the
project's own: verify against the Windows trust store through
`r2_common.ca_bundle()` — the same bundle the R2 scripts use, and emphatically
NOT a disabled check.
"""
import asyncio
import os
import ssl
import sys

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts"))
sys.path.insert(0, r"E:\My Projects\Rafiq-Al-Darb\scripts")
from r2_common import ca_bundle  # noqa: E402

BUNDLE = ca_bundle()
_orig = ssl.create_default_context


def _patched(*a, **kw):
    ctx = _orig(*a, **kw)
    try:
        ctx.load_verify_locations(cafile=BUNDLE)
    except Exception:
        pass
    return ctx


ssl.create_default_context = _patched

import edge_tts  # noqa: E402

TEXT = sys.argv[1]
VOICE = sys.argv[2]
OUT = sys.argv[3]
RATE = sys.argv[4] if len(sys.argv) > 4 else "+0%"


async def main():
    c = edge_tts.Communicate(TEXT, VOICE, rate=RATE)
    await c.save(OUT)
    print("wrote", OUT, os.path.getsize(OUT), "bytes")


asyncio.run(main())
