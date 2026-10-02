"""A live page for the R7 recitation copy (scripts/github_mirror_recitations.py).

Owner, 2026-10-03: «اعمللي حاجة انتراكتيف تعرضلي عملية النسخ والرفع عايز
اتابعهم». Read-only: it reads the two state files, the two run logs and the
watchdog task, and changes nothing.

    py -3 scripts/r7_dashboard.py            # http://127.0.0.1:8777

Numbers on the page are read from the files the copy itself writes:
  * files copied / bytes  = the per-file sizes in recitation_mirrors_state_<kind>.json
    (written by the copy after it verifies each upload)
  * sets finished         = `done` in the same file
  * totals                = the same lists the copy walks (reciters_full.json,
    recitation_source.dart × the mushaf's 6,236 ayahs)
  * speed                 = files in the log's «N/M» lines over the last hour
  * live                  = the copy's own temp files (%TEMP%\\tmp*\\<tag>_<file>):
    a file grows while it downloads, holds still while it uploads, and is
    deleted once GitHub has it. Polled every second here, so each file is seen
    as it moves - no request to GitHub, nothing added to the copy's quota.
"""
import json
import os
import re
import glob
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(HERE, 'out')
PORT = 8777
AYAHS = 6236


def _read(path):
    try:
        with open(path, encoding='utf-8') as f:
            return f.read()
    except OSError:
        return ''


def totals():
    cat = json.loads(_read(os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'catalogs',
                                        'reciters_full.json')) or '[]')
    surah = {}
    for r in cat:
        for m in r['moshaf']:
            n = len([x for x in m['surah_list'].split(',') if x.strip()])
            surah[str(m['id'])] = (r.get('name', ''), m.get('name', ''), n)
    src = _read(os.path.join(ROOT, 'rafeeq_app', 'lib', 'core', 'services',
                             'recitation_source.dart'))
    ayah = {}
    if '_everyAyahFolders = {' in src:
        body = src[src.index('_everyAyahFolders = {'):]
        body = body[:body.index('};')]
        for folder in re.findall(r"'ar\.[a-z]+':\s*'([^']+)'", body):
            ayah[folder] = (folder.replace('_', ' '), '', AYAHS)
    return {'surah': surah, 'ayah': ayah}


_TOTALS = None
_PROC = {'at': 0, 'value': None}


def processes():
    """The copy runs and the watchdog task, refreshed at most every 15 s."""
    if time.time() - _PROC['at'] < 15 and _PROC['value'] is not None:
        return _PROC['value']
    ps = ("$p = Get-CimInstance Win32_Process -Filter \"name='python.exe'\" | "
          "Where-Object { $_.CommandLine -like '*github_mirror_recitations.py*' } | "
          "ForEach-Object { @{ pid = $_.ProcessId; cmd = $_.CommandLine; "
          "start = $_.CreationDate.ToString('yyyy-MM-dd HH:mm') } }; "
          "$t = Get-ScheduledTask -TaskName RafeeqMirrorWatchdog -ErrorAction SilentlyContinue; "
          "@{ runs = @($p); watchdog = if ($t) { \"$($t.State)\" } else { 'missing' } } "
          "| ConvertTo-Json -Depth 4 -Compress")
    try:
        raw = subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True,
                             text=True, timeout=30, creationflags=0x08000000).stdout
        v = json.loads(raw or '{}')
    except Exception as e:  # noqa: BLE001 - shown on the page, never fatal
        v = {'runs': [], 'watchdog': f'unknown ({type(e).__name__})'}
    runs = v.get('runs') or []
    if isinstance(runs, dict):
        runs = [runs]
    v['runs'] = [{'pid': r.get('pid'), 'start': r.get('start'),
                  'kind': 'ayah' if '--only ayah' in (r.get('cmd') or '') else 'surah'}
                 for r in runs]
    _PROC.update(at=time.time(), value=v)
    return v


class Live:
    """Watches the copy's temp files once a second."""

    def __init__(self):
        self.lock = threading.Lock()
        self.files = {}      # path -> {tag, name, size, grew_at, seen_at}
        self.finished = []   # (time, tag, name, size) of files that left the temp dir
        threading.Thread(target=self.run, daemon=True).start()

    def scan(self):
        found = {}
        for d in glob.glob(os.path.join(tempfile.gettempdir(), 'tmp*')):
            for f in glob.glob(os.path.join(d, '*.mp3')):
                base = os.path.basename(f)
                if not base.startswith(('ayah-', 'surah-')) or '_' not in base:
                    continue
                try:
                    found[f] = os.path.getsize(f)
                except OSError:
                    pass
        return found

    def run(self):
        while True:
            try:
                found, now = self.scan(), time.time()
                with self.lock:
                    for f, size in found.items():
                        cur = self.files.get(f)
                        if cur is None:
                            base = os.path.basename(f)
                            tag, name = base.rsplit('_', 1)
                            self.files[f] = {'tag': tag, 'name': name, 'size': size,
                                             'grew_at': now, 'seen_at': now}
                        elif size != cur['size']:
                            cur.update(size=size, grew_at=now)
                    for f in [f for f in self.files if f not in found]:
                        x = self.files.pop(f)
                        self.finished.append((now, x['tag'], x['name'], x['size']))
                    self.finished = [e for e in self.finished if now - e[0] < 3600]
            except Exception:  # noqa: BLE001 - a missed scan is not worth a crash
                pass
            time.sleep(1)

    def snapshot(self):
        now = time.time()
        with self.lock:
            inflight = [{'tag': x['tag'], 'name': x['name'], 'size': x['size'],
                         'state': 'down' if now - x['grew_at'] < 2.5 else 'up',
                         'secs': int(now - x['seen_at'])}
                        for x in self.files.values()]
            fin = list(self.finished)
        recent = [{'ago': int(now - t), 'tag': tag, 'name': n, 'size': sz}
                  for t, tag, n, sz in reversed(fin[-12:])]
        last10 = [e for e in fin if now - e[0] <= 600]
        return {'inflight': sorted(inflight, key=lambda x: x['tag']), 'recent': recent,
                'per_10min': len(last10), 'bytes_10min': sum(e[3] for e in last10),
                'since': {tag: [t for t, tg, _, _ in fin if tg == tag]
                          for tag in {e[1] for e in fin}}}


LIVE = None

_PROGRESS = re.compile(r'^(\d\d):(\d\d):(\d\d) (\S+): (\d+)/(\d+)$')
_TODO = re.compile(r'^\d\d:\d\d:\d\d (\S+): (\d+) of (\d+) to copy$')


def kind_status(kind):
    global _TOTALS
    if _TOTALS is None:
        _TOTALS = totals()
    all_sets = _TOTALS[kind]
    st = json.loads(_read(os.path.join(OUT, f'recitation_mirrors_state_{kind}.json')) or '{}')
    done = [str(x) for x in (st.get('done') or {}).get(kind, [])]
    sizes = st.get('sizes') or {}
    files = sum(len(v) for k, v in sizes.items() if k.startswith(kind + ':'))
    nbytes = sum(int(s) for k, v in sizes.items() if k.startswith(kind + ':')
                 for s in v.values() if str(s).isdigit())
    total_files = sum(n for _, _, n in all_sets.values())
    log_path = os.path.join(OUT, f'gmr_{kind}.txt')
    lines = [ln.rstrip() for ln in _read(log_path).splitlines() if ln.strip()]
    # the set being copied now: the last «<tag>: X of Y to copy» and its last «N/M»
    current = None
    for ln in reversed(lines):
        m = _TODO.match(ln)
        if m:
            current = {'tag': m.group(1), 'todo': int(m.group(2)), 'of': int(m.group(3)),
                       'copied': 0}
            beat = None
            for later in lines[lines.index(ln) + 1:]:
                p = _PROGRESS.match(later)
                if p and p.group(4) == current['tag']:
                    current['copied'] = int(p.group(5))
                    beat = p
            # files that left the temp dir after that heartbeat's clock time
            if LIVE is not None:
                lt = time.localtime()
                today = time.mktime(lt[:3] + (0, 0, 0) + lt[6:])
                ref = beat or re.match(r'^(\d\d):(\d\d):(\d\d)', ln)
                t0 = today + int(ref.group(1)) * 3600 + int(ref.group(2)) * 60 + int(ref.group(3))
                if t0 > time.time() + 60:
                    t0 -= 86400
                done_after = [t for t in LIVE.snapshot()['since'].get(current['tag'], []) if t > t0]
                current['copied'] = min(current['todo'], current['copied'] + len(done_after))
            break
    # speed: «N/M» steps of the last hour (each step = files since the previous line)
    now = time.localtime()
    now_s = now.tm_hour * 3600 + now.tm_min * 60 + now.tm_sec
    per_hour, prev = 0, {}
    for ln in lines[-400:]:
        p = _PROGRESS.match(ln)
        if not p:
            m = _TODO.match(ln)
            if m:
                prev[m.group(1)] = 0
            continue
        t = int(p.group(1)) * 3600 + int(p.group(2)) * 60 + int(p.group(3))
        age = (now_s - t) % 86400
        tag, n = p.group(4), int(p.group(5))
        if age <= 3600:
            per_hour += max(0, n - prev.get(tag, 0))
        prev[tag] = n
    names = {sid: f'{a} {b}'.strip() for sid, (a, b, _) in all_sets.items()}
    left = total_files - files
    return {
        'kind': kind,
        'sets_done': len(done), 'sets_total': len(all_sets),
        'files_done': files, 'files_total': total_files, 'bytes': nbytes,
        'missing': len(st.get('missing') or {}),
        'current': current,
        'per_hour': per_hour,
        'eta_hours': round(left / per_hour, 1) if per_hour else None,
        'last_done': [names.get(s, s) for s in done[-8:]][::-1],
        'log_written': time.strftime('%Y-%m-%d %H:%M:%S',
                                     time.localtime(os.path.getmtime(log_path)))
        if os.path.exists(log_path) else None,
        'tail': lines[-14:],
    }


def status():
    return {'now': time.strftime('%Y-%m-%d %H:%M:%S'),
            'surah': kind_status('surah'), 'ayah': kind_status('ayah'),
            'proc': processes(), 'live': LIVE.snapshot() if LIVE else None}


PAGE = r"""<!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>متابعة نسخ التلاوات</title>
<style>
:root{--bg:#f6f4ef;--card:#fff;--fg:#1d2a24;--mut:#6b756f;--line:#e4e0d6;--acc:#1f7a55;--acc2:#c08a2b;--bad:#b23b3b}
@media (prefers-color-scheme:dark){:root{--bg:#121614;--card:#1b211e;--fg:#e9efe9;--mut:#93a097;--line:#2b332f;--acc:#3fbf88;--acc2:#e0aa4a;--bad:#e06a6a}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.6 "Segoe UI",Tahoma,sans-serif}
main{max-width:1100px;margin:0 auto;padding:16px}
h1{font-size:22px;margin:4px 0 2px}.sub{color:var(--mut);font-size:13px}
.top{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0}
.pill{border:1px solid var(--line);background:var(--card);border-radius:999px;padding:4px 12px;font-size:13px}
.ok{color:var(--acc)}.bad{color:var(--bad)}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px}
.card h2{margin:0 0 10px;font-size:18px;display:flex;justify-content:space-between;align-items:center}
.big{font-size:30px;font-weight:700}
.bar{height:12px;background:var(--line);border-radius:99px;overflow:hidden;margin:6px 0 12px}
.bar>i{display:block;height:100%;background:var(--acc);transition:width .6s}
.bar.cur>i{background:var(--acc2)}
.kv{display:grid;grid-template-columns:1fr 1fr;gap:6px 14px;font-size:14px}
.kv b{font-variant-numeric:tabular-nums}
.k{color:var(--mut)}
details{margin-top:10px}summary{cursor:pointer;color:var(--mut)}
pre{direction:ltr;text-align:left;background:var(--bg);border-radius:8px;padding:8px;font-size:12px;overflow:auto;max-height:260px;margin:6px 0 0}
ul{margin:4px 0 0;padding-inline-start:18px;font-size:13px}
button{font:inherit;border:1px solid var(--line);background:var(--card);color:var(--fg);border-radius:8px;padding:4px 10px;cursor:pointer}
</style></head><body><main>
<h1>متابعة نسخ ورفع التلاوات (R7)</h1>
<div class="sub">النسخ إلى مستودع rafeeq-recitations على GitHub. الصفحة بتتحدث لوحدها كل ثانيتين. آخر تحديث: <span id="now">…</span></div>
<div class="top" id="top"></div>
<div class="card" id="live" style="margin-bottom:14px"></div>
<div class="grid" id="grid"></div>
<p class="sub">الأرقام مقروءة من ملفات الحالة والسجل اللي برنامج النسخ بيكتبها بنفسه (scripts/out). الصفحة دي بتقرا بس ومبتغيرش أي حاجة.</p>
</main>
<script>
const nf=new Intl.NumberFormat('ar-EG');
const fmtB=b=>b>=1e9?nf.format((b/1e9).toFixed(2))+' جيجا':b>=1e6?nf.format((b/1e6).toFixed(1))+' ميجا':nf.format(Math.round(b/1e3))+' ك.ب';
const pct=(a,b)=>b?Math.min(100,a*100/b):0;
const label={surah:'السور الكاملة',ayah:'آية بآية'};
let open={};
function card(s){
  const p=pct(s.files_done,s.files_total), c=s.current;
  const cp=c?pct(c.copied,c.todo):0;
  const eta=s.eta_hours==null?'—':(s.eta_hours>48?nf.format((s.eta_hours/24).toFixed(1))+' يوم':nf.format(s.eta_hours)+' ساعة');
  return `<div class="card"><h2>${label[s.kind]}<span class="sub">${s.log_written?'آخر سطر في السجل '+s.log_written.slice(11):''}</span></h2>
  <div class="big">${nf.format(p.toFixed(1))}٪</div>
  <div class="bar"><i style="width:${p}%"></i></div>
  <div class="kv">
   <span class="k">الملفات المنسوخة</span><b>${nf.format(s.files_done)} من ${nf.format(s.files_total)}</b>
   <span class="k">المجموعات المكتملة</span><b>${nf.format(s.sets_done)} من ${nf.format(s.sets_total)}</b>
   <span class="k">الحجم المرفوع</span><b>${fmtB(s.bytes)}</b>
   <span class="k">السرعة (آخر ساعة)</span><b>${nf.format(s.per_hour)} ملف/ساعة</b>
   <span class="k">الوقت المتبقي تقريبًا</span><b>${eta}</b>
   <span class="k">ملفات ناقصة في المصدر</span><b>${nf.format(s.missing)}</b>
  </div>
  ${c?`<div style="margin-top:12px" class="sub">الشغال دلوقتي: <b style="direction:ltr;unicode-bidi:isolate">${c.tag}</b> — ${nf.format(c.copied)} من ${nf.format(c.todo)}</div>
  <div class="bar cur"><i style="width:${cp}%"></i></div>`:''}
  <details data-k="${s.kind}-done" ${open[s.kind+'-done']?'open':''}><summary>آخر المجموعات اللي خلصت</summary><ul>${s.last_done.map(x=>`<li>${x}</li>`).join('')||'<li>لسه</li>'}</ul></details>
  <details data-k="${s.kind}-log" ${open[s.kind+'-log']?'open':''}><summary>آخر سطور السجل</summary><pre>${s.tail.join('\n').replace(/</g,'&lt;')}</pre></details>
  </div>`;
}
async function tick(){
  try{
    const s=await (await fetch('/api',{cache:'no-store'})).json();
    document.getElementById('now').textContent=s.now;
    const runs=s.proc.runs||[];
    const has=k=>runs.some(r=>r.kind===k);
    const wd=s.proc.watchdog;
    document.getElementById('top').innerHTML=
      ['surah','ayah'].map(k=>`<span class="pill ${has(k)?'ok':'bad'}">${label[k]}: ${has(k)?'شغال ●':'واقف ○'}</span>`).join('')+
      `<span class="pill ${wd==='Ready'||wd==='Running'?'ok':'bad'}">المراقب التلقائي: ${wd==='Ready'||wd==='Running'?'مفعّل':wd==='Disabled'?'متوقف':wd}</span>`+
      `<span class="pill">الإجمالي: ${nf.format(pct(s.surah.files_done+s.ayah.files_done,s.surah.files_total+s.ayah.files_total).toFixed(1))}٪ — ${fmtB(s.surah.bytes+s.ayah.bytes)}</span>`;
    document.querySelectorAll('details').forEach(d=>open[d.dataset.k]=d.open);
    const L=s.live;
    if(L){
      const row=f=>`<tr><td>${f.state==='down'?'⬇ بينزل من المصدر':'⬆ بيترفع على GitHub'}</td><td style="direction:ltr;text-align:left">${f.tag} / ${f.name}</td><td>${fmtB(f.size)}</td><td>${nf.format(f.secs)} ث</td></tr>`;
      const rec=f=>`<li>${nf.format(f.ago)} ث — <span style="direction:ltr;unicode-bidi:isolate">${f.tag} / ${f.name}</span> (${fmtB(f.size)})</li>`;
      document.getElementById('live').innerHTML=`<h2>دلوقتي حالًا <span class="sub">${nf.format(L.per_10min)} ملف في آخر ١٠ دقايق — ${fmtB(L.bytes_10min)}</span></h2>
      ${L.inflight.length?`<table style="width:100%;border-collapse:collapse;font-size:13px">${L.inflight.map(row).join('')}</table>`:'<div class="sub">مفيش ملف في الطريق اللحظة دي (بين ملف والتاني، أو مستني حد الرفع).</div>'}
      <details data-k="recent" ${open['recent']?'open':''}><summary>آخر الملفات اللي اترفعت (من ساعة ما اللوحة اشتغلت)</summary><ul>${L.recent.map(rec).join('')||'<li>لسه</li>'}</ul></details>`;
    }
    document.getElementById('grid').innerHTML=card(s.surah)+card(s.ayah);
  }catch(e){document.getElementById('now').textContent='تعذّر القراءة: '+e}
}
tick();setInterval(tick,2000);
</script></body></html>"""


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/api'):
            body = json.dumps(status(), ensure_ascii=False).encode('utf-8')
            ctype = 'application/json; charset=utf-8'
        else:
            body, ctype = PAGE.encode('utf-8'), 'text/html; charset=utf-8'
        self.send_response(200)
        self.send_header('Content-Type', ctype)
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


if __name__ == '__main__':
    import sys
    if '--once' in sys.argv:  # a self-check: print what the page would show
        s = status()
        for k in ('surah', 'ayah'):
            x = s[k]
            print(k, 'files', x['files_done'], '/', x['files_total'], 'sets', x['sets_done'], '/',
                  x['sets_total'], 'bytes', x['bytes'], 'per_hour', x['per_hour'], 'current',
                  x['current'], 'eta_h', x['eta_hours'])
        print('proc', s['proc'])
    else:
        LIVE = Live()
        ThreadingHTTPServer(('127.0.0.1', PORT), H).serve_forever()
