"""Copy the app's recitations to its own GitHub repository (R7).

    py -3 scripts/github_mirror_recitations.py --only ayah     # ayah sets, resumable (one kind per run;
                                                               # an ayah run and a surah run may go side by side)
    py -3 scripts/github_mirror_recitations.py --only surah    # whole-surah sets only
    py -3 scripts/github_mirror_recitations.py --set ayah:Husary_128kbps
    py -3 scripts/github_mirror_recitations.py --publish-only  # re-upload the manifest

Owner, 2026-10-02: «مش هنقدر نعتمد على سيرفيرات التحميل الخارجية», and for
where: «GitHub بس، ببلاش». The copies go to tito423/rafeeq-recitations, not
the app's own repository, so its releases page stays the app's.

Layout (the app computes the same names - lib/core/services/recitation_mirrors.dart):
  ayah-<everyayah folder>-p<N>/SSSAAA.mp3   N = 1..7, by AYAH_PART_STARTS
  surah-<mp3quran moshaf id>/SSS.mp3
A release holds at most 1000 assets, so a 6,236-ayah set is split by surah
into seven parts of at most 996 files.

A set is listed in the manifest (config/recitation_mirrors.json on R2 and
on the app repo's content-mirror release) only after EVERY file of it is on
GitHub with the exact byte count the source served. A file the source does
not have (404) leaves its set unlisted, and is printed. The app reads the
manifest at launch, so a set finished after a release is used without one.

Secondary rate limits: GitHub documents «no more than 80 content-generating
requests per minute and no more than 500 per hour» (docs.github.com, read
2026-10-02). Every upload is paced and a 403/429 waits for retry-after.
"""
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse

import requests

sys.stdout.reconfigure(encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPO = 'tito423/rafeeq-recitations'
APP_REPO = 'tito423/Rafeeq-Al-Darb'
# One state file per kind, so an ayah run and a surah run can go side by side.
STATE_OF = lambda kind: os.path.join(HERE, 'out', f'recitation_mirrors_state_{kind}.json')
MANIFEST = os.path.join(HERE, 'out', 'recitation_mirrors.json')
KEY = 'config/recitation_mirrors.json'
LOG = os.path.join(HERE, 'out', 'github_mirror_recitations.log')
UA = 'Mozilla/5.0 (RafeeqAlDarb recitation mirror; github.com/tito423/Rafeeq-Al-Darb)'

# First surah of each ayah part (<= 1000 ayahs each, Hafs counts from
# quran_local.db). Must equal RecitationMirrors.ayahPartStarts in Dart.
AYAH_PART_STARTS = [1, 7, 16, 25, 37, 53, 80]

TOKEN = subprocess.run(['gh', 'auth', 'token'], capture_output=True, text=True, check=True).stdout.strip()
API = requests.Session()
API.headers.update({'Authorization': f'Bearer {TOKEN}', 'Accept': 'application/vnd.github+json',
                    'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': UA})
SRC = requests.Session()
SRC.headers.update({'User-Agent': UA})
_lock = threading.Lock()


def log(msg):
    line = time.strftime('%H:%M:%S ') + msg
    print(line, flush=True)
    with _lock, open(LOG, 'a', encoding='utf-8') as f:
        f.write(line + '\n')


def ayah_counts():
    import sqlite3
    c = sqlite3.connect(os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_local.db'))
    return [r[0] for r in c.execute('select ayahs_count from surahs order by id')]


def part_of(surah):
    return max(i + 1 for i, s in enumerate(AYAH_PART_STARTS) if surah >= s)


def ayah_sets():
    src = open(os.path.join(ROOT, 'rafeeq_app', 'lib', 'core', 'services', 'recitation_source.dart'), encoding='utf-8').read()
    body = src[src.index('_everyAyahFolders = {'):]
    body = body[:body.index('};')]
    folders = re.findall(r"'ar\.[a-z]+':\s*'([^']+)'", body)
    counts = ayah_counts()
    sets = []
    for folder in folders:
        files = {}
        for s, n in enumerate(counts, 1):
            for a in range(1, n + 1):
                name = f'{s:03d}{a:03d}.mp3'
                files.setdefault(f'ayah-{folder}-p{part_of(s)}', []).append(
                    (name, f'https://everyayah.com/data/{folder}/{name}'))
        sets.append(('ayah', folder, files))
    return sets


def surah_sets():
    cat = json.load(open(os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'catalogs', 'reciters_full.json'), encoding='utf-8'))
    sets = []
    for r in cat:
        for m in r['moshaf']:
            surahs = [int(x) for x in m['surah_list'].split(',') if x.strip()]
            files = [(f'{s:03d}.mp3', f"{m['server']}{s:03d}.mp3") for s in surahs]
            sets.append(('surah', str(m['id']), {f"surah-{m['id']}": files}))
    return sets


# ---- GitHub -------------------------------------------------------------

def gh_call(method, url, **kw):
    for attempt in range(12):
        try:
            r = API.request(method, url, timeout=600, **kw)
        except requests.exceptions.RequestException as e:
            # a dropped connection (seen 2026-10-02 13:3x: RemoteDisconnected
            # killed the ayah run) is retried, not fatal
            log(f'{method} {url.split("?")[0]}: {type(e).__name__} - retry in {30 * (attempt + 1)}s')
            time.sleep(30 * (attempt + 1))
            continue
        if r.status_code in (403, 429) and ('rate limit' in r.text.lower() or 'retry-after' in r.headers):
            wait = int(r.headers.get('retry-after') or 0)
            if not wait and r.headers.get('x-ratelimit-remaining') == '0':
                wait = max(5, int(r.headers.get('x-ratelimit-reset', '0')) - int(time.time()))
            wait = max(wait, 60 * (attempt + 1))
            log(f'rate limited ({r.status_code}) - waiting {wait}s')
            time.sleep(wait)
            continue
        if r.status_code >= 500:
            time.sleep(10 * (attempt + 1))
            continue
        return r
    raise RuntimeError(f'{method} {url}: gave up after rate limits')


def release(tag):
    r = gh_call('GET', f'https://api.github.com/repos/{REPO}/releases/tags/{tag}')
    if r.status_code == 200:
        return r.json()
    r = gh_call('POST', f'https://api.github.com/repos/{REPO}/releases',
                json={'tag_name': tag, 'name': tag, 'target_commitish': 'main', 'make_latest': 'false',
                      'body': 'Recitation files mirrored byte for byte for the Rafeeq Al-Darb app; see the README.'})
    r.raise_for_status()
    return r.json()


def assets(rel):
    out, page = {}, 1
    while True:
        r = gh_call('GET', f"https://api.github.com/repos/{REPO}/releases/{rel['id']}/assets",
                    params={'per_page': 100, 'page': page})
        r.raise_for_status()
        batch = r.json()
        for a in batch:
            out[a['name']] = (a['size'], a['state'], a['id'])
        if len(batch) < 100:
            return out
        page += 1


class Pace:
    """At most [per_hour] uploads an hour, spread evenly."""
    def __init__(self, per_hour):
        self.gap = 3600.0 / per_hour
        self.next = 0.0
        self.lock = threading.Lock()

    def wait(self):
        with self.lock:
            now = time.time()
            t = max(now, self.next)
            self.next = t + self.gap
        if t > now:
            time.sleep(t - now)


PACE = None


def upload(rel, name, path):
    PACE.wait()
    url = rel['upload_url'].split('{')[0] + '?' + urllib.parse.urlencode({'name': name})
    with open(path, 'rb') as f:
        data = f.read()
    r = gh_call('POST', url, data=data, headers={'Content-Type': 'audio/mpeg'})
    if r.status_code == 422 and 'already_exists' in r.text:
        return
    r.raise_for_status()


# ---- source -------------------------------------------------------------

def fetch(url, dest):
    """Downloads [url]; returns its size, or None when the source has no such file."""
    for attempt in range(5):
        try:
            with SRC.get(url, stream=True, timeout=120, allow_redirects=True) as r:
                if r.status_code == 404:
                    return None
                r.raise_for_status()
                want = int(r.headers.get('Content-Length', '-1'))
                n = 0
                with open(dest, 'wb') as f:
                    for chunk in r.iter_content(1 << 16):
                        f.write(chunk)
                        n += len(chunk)
                if want >= 0 and n != want:
                    raise IOError(f'short read {n}/{want}')
                if n == 0:
                    raise IOError('empty')
                return n
        except Exception as e:  # noqa: BLE001 - retried, then reported
            err = e
            time.sleep(5 * (attempt + 1))
    raise RuntimeError(f'{url}: {err}')


def source_size(url):
    for attempt in range(5):
        try:
            r = SRC.get(url, headers={'Range': 'bytes=0-0'}, timeout=60, allow_redirects=True)
            if r.status_code == 206:
                return int(r.headers['Content-Range'].split('/')[-1])
            if r.status_code == 200:
                return int(r.headers['Content-Length'])
        except Exception:  # noqa: BLE001 - retried
            pass
        time.sleep(5 * (attempt + 1))
    raise RuntimeError(f'{url}: no size')


# ---- state + manifest ---------------------------------------------------

def load_state(kind):
    if os.path.exists(STATE_OF(kind)):
        st = json.load(open(STATE_OF(kind), encoding='utf-8'))
    else:
        st = {'sizes': {}, 'done': {'ayah': [], 'surah': []}, 'missing': {}}
    st['kind'] = kind
    return st


def save_state(st):
    path = STATE_OF(st['kind'])
    tmp = path + '.tmp'
    json.dump(st, open(tmp, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    os.replace(tmp, path)


_publish_lock = threading.Lock()


def publish(_st=None):
    # Both kinds' finished sets, read from their own state files.
    a, s = load_state('ayah'), load_state('surah')
    doc = {'version': int(time.time()), 'repo': REPO, 'ayahPartStarts': AYAH_PART_STARTS,
           'ayah': sorted(a['done']['ayah']), 'surah': sorted(int(x) for x in s['done']['surah'])}
    json.dump(doc, open(MANIFEST, 'w', encoding='utf-8'), indent=1)
    sys.path.insert(0, HERE)
    from r2_common import BUCKET, r2_client
    r2_client().upload_file(MANIFEST, BUCKET, KEY, ExtraArgs={
        'ContentType': 'application/json; charset=utf-8', 'CacheControl': 'max-age=3600'})
    mirror = os.path.join(HERE, 'out', KEY.replace('/', '__'))
    json.dump(doc, open(mirror, 'w', encoding='utf-8'), indent=1)
    subprocess.run(['gh', 'release', 'upload', 'content-mirror', mirror, '--clobber', '-R', APP_REPO],
                   check=True, capture_output=True)
    log(f"manifest published: {len(doc['ayah'])} ayah sets, {len(doc['surah'])} surah sets")


# ---- one set ------------------------------------------------------------

def mirror_set(kind, sid, parts, st, tmpdir):
    if sid in st['done'][kind]:
        return True
    sizes = st['sizes'].setdefault(f'{kind}:{sid}', {})
    missing = []
    for tag, files in parts.items():
        rel = release(tag)
        have = assets(rel)
        todo = [(n, u) for n, u in files if not (n in have and have[n][1] == 'uploaded'
                                                  and str(have[n][0]) == str(sizes.get(n, have[n][0])))]
        for n, _ in todo:  # a broken earlier upload is replaced
            if n in have:
                gh_call('DELETE', f'https://api.github.com/repos/{REPO}/releases/assets/{have[n][2]}')
        if todo:
            log(f'{tag}: {len(todo)} of {len(files)} to copy')

        def one(item):
            n, u = item
            path = os.path.join(tmpdir, f'{tag}_{n}')
            try:
                size = fetch(u, path)
                if size is None:
                    return n, None
                upload(rel, n, path)
                return n, size
            finally:
                if os.path.exists(path):
                    os.remove(path)

        with cf.ThreadPoolExecutor(4) as ex:
            for k, (n, size) in enumerate(ex.map(one, todo), 1):
                if size is None:
                    missing.append(f'{tag}/{n}')
                else:
                    sizes[n] = size
                if k % 50 == 0:
                    # a heartbeat: the watchdog takes a silent log for a hang
                    log(f'{tag}: {k}/{len(todo)}')
                    save_state(st)
        save_state(st)
        # Verify: every file there, each with the byte count the source served.
        have = assets(rel)
        for n, u in files:
            if f'{tag}/{n}' in missing:
                continue
            if n not in sizes and n in have:
                # uploaded by a run that stopped before saving its sizes:
                # ask the source for the byte count instead of trusting it
                sizes[n] = source_size(u)
                save_state(st)
            if n not in have or have[n][1] != 'uploaded' or (n in sizes and have[n][0] != sizes[n]):
                log(f'{tag}/{n}: NOT VERIFIED (have {have.get(n)}, source {sizes.get(n)})')
                return False
        first = files[0][0]
        code = requests.get(f'https://github.com/{REPO}/releases/download/{tag}/{first}',
                            headers={'Range': 'bytes=0-1023', 'User-Agent': UA}, timeout=60).status_code
        if code != 206:
            log(f'{tag}/{first}: range request answered {code}')
            return False
    if missing:
        st['missing'][f'{kind}:{sid}'] = missing
        save_state(st)
        log(f'{kind} {sid}: source lacks {len(missing)} file(s) - NOT listed: {missing[:5]}')
        return False
    st['done'][kind].append(sid)
    save_state(st)
    log(f'{kind} {sid}: complete and verified')
    return True


def main():
    global PACE
    args = sys.argv[1:]
    os.makedirs(os.path.join(HERE, 'out'), exist_ok=True)
    if '--publish-only' in args:
        publish()
        return
    per_hour = int(args[args.index('--per-hour') + 1]) if '--per-hour' in args else 450
    PACE = Pace(per_hour)
    only = args[args.index('--only') + 1] if '--only' in args else None
    one_set = args[args.index('--set') + 1] if '--set' in args else None
    kind = only or (one_set.split(':')[0] if one_set else None)
    if kind not in ('ayah', 'surah'):
        sys.exit('--only ayah|surah (or --set kind:id): one kind per run')
    st = load_state(kind)
    sets = []
    if only in (None, 'ayah'):
        sets += ayah_sets()
    if only in (None, 'surah'):
        sets += surah_sets()
    if one_set:
        sets = [s for s in sets if f'{s[0]}:{s[1]}' == one_set]
    log(f'{len(sets)} sets, pace {per_hour}/h')
    with tempfile.TemporaryDirectory() as tmp:
        for kind_, sid, parts in sets:
            if mirror_set(kind_, sid, parts, st, tmp):
                if sid not in st.get('published', []):
                    publish(st)
                    st.setdefault('published', []).append(sid)
                    save_state(st)
    # read by scripts/recitation_mirror_watchdog.ps1: this kind is finished
    left = [f'{k}:{i}' for k, i, _ in sets if i not in st['done'][k]]
    log(f'ALL {kind} SETS PROCESSED - {len(left)} not listed (source gaps: {sorted(st["missing"])})')


if __name__ == '__main__':
    main()
