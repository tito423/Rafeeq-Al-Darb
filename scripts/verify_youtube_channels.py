"""Verify a YouTube channel really exists, and read its real name, id, avatar
and subscriber count off the page.

Written because a web search returns four channels all described as "the
official one" and none of that is evidence. Nothing goes into the app's
channel list that has not answered here with a real channel id and a real
avatar URL — the same rule the mushaf catalogue learned the hard way when
eight editions shipped whose pages 404'd.

    py -3 scripts/verify_youtube_channels.py https://www.youtube.com/@handle ...

Writes a UTF-8 report (the Windows console is cp1256 and cannot print Arabic).
"""

import io
import json
import os
import re
import sys
import urllib.request

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "youtube_channels_out.txt")

UA = {
    # A real browser UA: YouTube serves a stripped consent page to anything
    # that looks like a script, and the stripped page has no ytInitialData.
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"
    ),
    "Accept-Language": "ar,en;q=0.8",
}


def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=90) as r:
        return r.read().decode("utf-8", "replace")


def extract(html):
    """Pull the channel's own metadata out of the page."""
    info = {}

    m = re.search(r'<meta itemprop="identifier" content="([^"]+)"', html)
    if not m:
        m = re.search(r'"externalId":"(UC[\w-]+)"', html)
    info["channel_id"] = m.group(1) if m else None

    m = re.search(r'"channelMetadataRenderer":\{"title":"(.*?)"', html)
    info["title"] = json.loads(f'"{m.group(1)}"') if m else None

    m = re.search(r'"vanityChannelUrl":"(.*?)"', html)
    info["vanity"] = json.loads(f'"{m.group(1)}"') if m else None

    # The avatar: take the largest thumbnail offered for the channel itself.
    avatars = re.findall(r'"url":"(https://yt3\.googleusercontent\.com/[^"]+?)"', html)
    info["avatar"] = json.loads(f'"{avatars[0]}"') if avatars else None

    m = re.search(r'"subscriberCountText":\{"simpleText":"(.*?)"', html)
    if not m:
        m = re.search(r'"([\d.,]+[KMB]? subscribers)"', html)
        info["subscribers"] = m.group(1) if m else None
    else:
        info["subscribers"] = json.loads(f'"{m.group(1)}"')

    m = re.search(r'"description":\{"simpleText":"(.*?)"\}', html)
    if m:
        try:
            info["description"] = json.loads(f'"{m.group(1)}"')[:220]
        except Exception:
            info["description"] = None

    info["is_verified"] = '"BADGE_STYLE_TYPE_VERIFIED"' in html
    return info


def main():
    urls = sys.argv[1:]
    if not urls:
        raise SystemExit(__doc__)
    lines = []
    for url in urls:
        lines.append(f"===== {url} =====")
        try:
            html = fetch(url)
        except Exception as e:
            lines.append(f"  FETCH FAILED: {e}\n")
            continue
        info = extract(html)
        for k in (
            "title", "channel_id", "vanity", "subscribers",
            "is_verified", "avatar", "description",
        ):
            lines.append(f"  {k:>13}: {info.get(k)}")
        lines.append("")
    text = "\n".join(lines)
    with io.open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
