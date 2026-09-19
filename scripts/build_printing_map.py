"""Build a scanned printing's OWN ayah map, page by page, from its own scan.

    py -3 scripts/build_printing_map.py <edition> [--pages a-b] [--draw p,p]

Why: the scans borrowed the Madinah (hafs_kfqc) polygons, stretched onto
each page by an affine. The printings do not break their lines at the same
words, and on some pages the stretch sits a whole line off (page 77 of
Qatar: every predicted ayah end one line below its printed marker). The
owner photographed exactly that. So nothing here trusts the borrowed layer
for position; it is used only for WHICH ayahs a page holds and which of its
15 line slots are banner or basmala rather than ayah text.

Per page:
 1. The 15 line baselines are found on the scan: the borrowed layer gives a
    first guess of the grid, and the grid (offset and pitch) is then fitted
    to the scan's own ink row profile, each baseline refined locally.
 2. Every ayah marker is found by template matching on a local-contrast ink
    mask (digit masked out), line by line. The count must equal the number
    of ayahs on the page, or the page is rejected.
 3. Each ayah runs from the previous marker (or the start of its first line)
    to its own marker, line by line; each line's ink start and end are
    measured on the scan. Rings are whole line bands, the shape the app's
    PageLineGrid expects, so it draws them exactly as it draws Madinah.
 4. Checks before a page is accepted: marker count; markers in reading
    order; each ayah's end line within one line of the Madinah end line;
    every ring has ink under it; the rings cover >= 97% of the text ink of
    the ayah lines. Any failure = no entry for that page = no highlight.

Output: rafeeq_app/build/hl/own_<edition>.json {pages: {p: [[s,a,[ring,...]]]},
aspect: {p: a}} and own_<edition>_report.json.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audit_highlight as A  # noqa: E402
import printing_ayah_map as M  # noqa: E402

# Madinah calibration (hafs_kfqc): the baseline sits 0.705 of a pitch below
# a line band's top (derived from rect centre = baseline - 0.25 h, h = 0.82
# pitch after the app's 0.09-pitch inset on each side).
ALPHA, BETA = 0.705, 0.295


# Madinah line-slot centres (hafs_kfqc, pages 3-604, medians of 550-600
# lines each): the 15 lines sit at the same place on every page.
SLOT_CY = [0.0368, 0.1064, 0.1724, 0.238, 0.3033, 0.3683, 0.4335, 0.4989,
           0.5636, 0.6286, 0.6939, 0.7589, 0.8243, 0.8903, 0.9597]


def slot_of(cy):
    return min(range(15), key=lambda k: abs(SLOT_CY[k] - cy))


def hafs_slots(hafs_entry):
    """Per ayah (first slot, end slot), and the slots that carry ayah text."""
    info = {}
    used = set()
    for a in hafs_entry['ayahs']:
        ks = [slot_of((r[1] + r[3]) / 2) for r in a['r']]
        info[(a['s'], a['a'])] = (min(ks), max(ks))
        used.update(ks)
    return info, used


def fit_grid(ink, xa, xb, pred):
    """Refine the 15 predicted baselines on the scan's ink row profile.

    The prediction (Madinah's absolute line slots through the page's fit) is
    right to within a fraction of a line, so only a small global
    offset/scale and then a per-line snap to the densest ink row - the
    Arabic baseline - are searched. `ink` must already have printed ruling
    removed (build_page does it): on the gold printing the rule under each
    line was the densest row and pulled every band half a line low.
    """
    prof = ink[:, xa:xb].sum(axis=1).astype(float)
    prof = np.convolve(prof, np.ones(3) / 3, mode='same')
    pred = np.array(pred, float)
    pitch = np.median(np.diff(pred))
    mid = pred.mean()
    n = len(prof)
    best = None
    for sc in np.arange(0.98, 1.021, 0.005):
        for o in np.arange(-0.3 * pitch, 0.3 * pitch + 1, 1.0):
            b = mid + sc * (pred - mid) + o
            idx = np.clip(b.round().astype(int), 0, n - 1)
            score = prof[idx].sum()
            if best is None or score > best[0]:
                best = (score, b, sc * pitch)
    base, pitch = best[1], best[2]
    out = []
    for y in base:
        lo, hi = int(max(0, y - 0.15 * pitch)), int(min(n, y + 0.15 * pitch))
        out.append(lo + int(np.argmax(prof[lo:hi])) if hi > lo else y)
    return np.array(out, float), pitch


VERT_MAX = float(os.environ.get('VERT_MAX', '0.03'))
HEADER_THR = 0.35
HEADER_REF = {}
STRIPS_OUT = None


def line_strip(ink, b, pitch, xa, xb):
    """One text line, normalised to 400 x 40, for comparing whole lines."""
    import cv2
    y0, y1 = int(max(0, b - 0.75 * pitch)), int(b + 0.3 * pitch)
    return cv2.resize(ink[y0:y1, xa:xb], (400, 40), interpolation=cv2.INTER_AREA)


def similarity(a, b):
    a = a - a.mean()
    b = b - b.mean()
    return float((a * b).sum() / np.sqrt((a * a).sum() * (b * b).sum() + 1e-9))


def header_reference(ed, data, tpl):
    """The printing's surah banner and basmala, as it draws them: lines 0 and
    1 of page 50, where Al Imran opens under both in all four printings
    (drawn and checked). Header lines elsewhere are recognised by likeness
    to these (> 0.35; ayah lines measured 0.05-0.19, headers 0.53-0.55)."""
    global STRIPS_OUT
    STRIPS_OUT = []
    HEADER_REF[ed] = (np.zeros((40, 400), np.float32),) * 2
    build_page(ed, 50, data[ed]['pages']['50'], data['hafs_kfqc']['pages']['50'], tpl)
    HEADER_REF[ed] = (STRIPS_OUT[0], STRIPS_OUT[1])
    STRIPS_OUT = None


def build_page(ed, p, entry, hafs_entry, tpl):
    f = A.page_file(ed, p)
    box, _ = A.compose(Image.open(f), entry['aspect'])
    ink_raw = M.ink_of(box)
    ink = ink_raw
    # Printed ruling (the gold printing rules a line under every text line)
    # is the densest "ink row" on its page and pulled every baseline onto
    # the rule, half a line low - seen on the device on page 4. Long thin
    # horizontal runs are found by a morphological opening and removed.
    import cv2
    rules = cv2.morphologyEx(ink, cv2.MORPH_OPEN,
                             cv2.getStructuringElement(cv2.MORPH_RECT, (120, 1)))
    ink = np.clip(ink - rules, 0, 1)
    bh = ink.shape[0]
    info, used = hafs_slots(hafs_entry)
    # the borrowed layer's slot centres, mapped onto this scan: only a guess
    mrects = [r for a in entry['ayahs'] for r in a['r']]
    mlines = A.lines_of(mrects)
    hlines = A.lines_of([r for a in hafs_entry['ayahs'] for r in a['r']])
    if len(mlines) < 3 or len(hlines) != len(mlines):
        return None, 'line grouping differs'
    kk = np.array([slot_of(l['cy']) for l in hlines], float)
    mcy = np.array([l['cy'] * bh for l in mlines])
    A1, B1 = np.polyfit(kk, mcy, 1)
    nslots = 15
    pred_base = [A1 * k + B1 + (ALPHA - 0.5) * A1 for k in range(nslots)]
    xs = [r[0] for r in mrects] + [r[2] for r in mrects]
    xa, xb = int(max(0, (min(xs) - 0.015) * A.BW)), int(min(A.BW, (max(xs) + 0.015) * A.BW))
    base, pitch = fit_grid(ink, xa, xb, pred_base)

    # line extents on the scan
    ext = {}
    for k in range(nslots):
        # the letters' bodies around the baseline only: a wider band caught
        # the frame's rule and the next line's ascenders, and a centred
        # basmala then measured as a full-width line
        y0, y1 = int(base[k] - 0.42 * pitch), int(base[k] + 0.10 * pitch)
        cols = np.where(ink[max(0, y0):y1, xa:xb].sum(axis=0) >= 3)[0]
        if len(cols):
            ext[k] = (xa + cols[0], xa + cols[-1])
    # Header lines, from the scan itself - the printings do not put their
    # banners and basmalas on the same lines as Madinah (Qatar sets al-Nisa's
    # banner at the foot of page 76; Madinah opens page 77 with it). The
    # basmala is a short line centred in the block; the banner is the line
    # right above a basmala.
    blockL = np.median([v[0] for v in ext.values()])
    blockR = np.median([v[1] for v in ext.values()])
    wid = blockR - blockL
    strips = [line_strip(ink, base[k], pitch, xa, xb) for k in range(nslots)]
    if HEADER_REF.get(ed) is None:
        return None, 'no header reference'
    ban_ref, bas_ref = HEADER_REF[ed]

    def best(k, ref, ends_only):
        # a little vertical play; for a banner, only its two decorated ends,
        # because the surah's name in the middle differs from page to page
        sc = -1.0
        for d in (-0.2, -0.1, 0.0, 0.1, 0.2):
            st = line_strip(ink, base[k] + d * pitch, pitch, xa, xb)
            a, b = (np.hstack([st[:, :90], st[:, -90:]]),
                    np.hstack([ref[:, :90], ref[:, -90:]])) if ends_only else (st, ref)
            sc = max(sc, similarity(a, b))
        return sc
    basm = {k for k in range(nslots) if best(k, bas_ref, False) > HEADER_THR}
    banners = {k for k in range(nslots) if best(k, ban_ref, True) > HEADER_THR}
    header = basm | banners
    if STRIPS_OUT is not None:
        STRIPS_OUT[:] = strips
    empty = {k for k in range(nslots) if k not in ext}
    text_lines = [k for k in range(nslots) if k not in header and k not in empty]
    # markers, line by line, on text lines only
    want = len(entry['ayahs'])
    found = None
    for thr in (0.55, 0.5, 0.46, 0.43, 0.40, 0.37):
        cand = []
        for k in text_lines:
            band = (int(max(0, base[k] - 0.8 * pitch)), int(min(bh, base[k] + 0.4 * pitch)))
            for m in M.find_markers(ink_raw, band, tpl, thr):
                if xa <= m[0] <= xb:
                    cand.append((k, m))
        cand.sort(key=lambda t: (t[0], -t[1][0]))
        if len(cand) > want:
            break
        if len(cand) == want:
            found = cand
            break
    if found is None:
        return None, 'marker count'
    ayahs = entry['ayahs']
    # A header line (banner/basmala) can only sit where a surah starts on
    # this page - between the previous marker and a surah's first ayah - or
    # below the page's last marker (the next surah's banner). Anywhere else
    # a "header" is a misread ayah line (page 4 of the gold printing lost
    # «أبصارهم كلما أضاء» that way), and the coverage check must see it.
    allowed = set(range(found[-1][0] + 1, nslots))
    for i, ((k, _), ay) in enumerate(zip(found, ayahs)):
        if ay['a'] == 1:
            allowed |= set(range((found[i - 1][0] if i else -1) + 1, k + 1))
    header &= allowed
    text_lines = [k for k in range(nslots) if k not in header and k not in empty]
    rings_out = []
    prev = None  # (line, x) of the previous marker's left edge

    def next_text_line(k, surah_start, surah):
        """The first ayah line after line k (exclusive)."""
        j = k + 1
        if surah_start and surah == 9:
            # at-Tawbah: a banner and no basmala
            while j < nslots and (j in header or j in empty):
                j += 1
            return j + 1 if j not in header else j
        while j < nslots and (j in header or j in empty):
            j += 1
        return j

    def rings_for(s0, start_x, k, end_x, skip=frozenset()):
        rings = []
        for j in range(s0, k + 1):
            if j in header or j in skip or j not in ext:
                continue
            L, R = ext[j]
            right = min(R, start_x) if j == s0 else R
            left = max(L, end_x) if j == k else L
            if right - left < 4:
                continue
            top, bot = base[j] - ALPHA * pitch, base[j] + BETA * pitch
            rings.append([[left / A.BW, top / bh], [right / A.BW, top / bh],
                          [right / A.BW, bot / bh], [left / A.BW, bot / bh]])
        return rings

    hl = {(a['s'], a['a']): sum(r[2] - r[0] for r in a['r']) / 0.973
          for a in hafs_entry['ayahs']}
    length = lambda rings: sum(r[1][0] - r[0][0] for r in rings) * A.BW / wid
    segs = []
    for (k, m), ay in zip(found, ayahs):
        hs0, hs1 = info[(ay['s'], ay['a'])]
        if abs(k - hs1) > 1:
            return None, f'{ay["s"]}:{ay["a"]} ends on line {k}, Madinah {hs1}'
        size = m[2]
        end_x = m[0] - 0.62 * size
        starts_surah = ay['a'] == 1
        if prev is None:
            s0 = next_text_line(-1, starts_surah, ay['s'])
            start_x = ext.get(s0, (0, xb))[1]
            after = -1
        else:
            s0, start_x = prev
            after = s0
            closed = s0 not in ext or start_x <= ext[s0][0] + 0.3 * size
            if closed or starts_surah:
                s0 = next_text_line(s0, starts_surah, ay['s'])
                start_x = ext.get(s0, (0, xb))[1]
        if s0 > k:
            return None, f'{ay["s"]}:{ay["a"]} starts after its marker'
        segs.append([ay, s0, start_x, k, end_x, starts_surah, after])
        prev = (k, end_x)
    # the page's density against Madinah, from ayahs that do not open a surah
    plain = [(length(rings_for(s0, sx, k, ex)), hl[(ay['s'], ay['a'])])
             for ay, s0, sx, k, ex, st, _ in segs if not st]
    dens = (sum(x for x, _ in plain) / max(1e-6, sum(y for _, y in plain))) if plain else 1.0
    # An ayah that opens a surah starts after the banner and basmala. Where
    # those were not recognised, the lines to skip (0, 1 or 2 after the
    # previous marker) are the ones that make its length agree with
    # Madinah's - a banner and a basmala are a whole line each.
    for seg in segs:
        ay, s0, sx, k, ex, st, after = seg
        if not st:
            continue
        want_len = dens * hl[(ay['s'], ay['a'])]
        cands = [j for j in range(after + 1, k + 1) if j in ext][:3]
        best = None
        for j in cands:
            skipped = frozenset(range(after + 1, j))
            ln = length(rings_for(j, ext[j][1], k, ex, skipped))
            if best is None or abs(ln - want_len) < abs(best[1] - want_len):
                best = (j, ln, skipped)
        if best:
            seg[1], seg[2] = best[0], ext[best[0]][1]
            header |= set(best[2])
    rings_out = []
    for ay, s0, sx, k, ex, st, _ in segs:
        rings = rings_for(s0, sx, k, ex)
        for r in rings:
            l, t, rr, bt = r[0][0] * A.BW, r[0][1] * bh, r[1][0] * A.BW, r[2][1] * bh
            if ink[int(t):int(bt), int(l):int(rr)].any(axis=0).mean() < 0.5:
                return None, f'{ay["s"]}:{ay["a"]} ring over blank'
        if not rings:
            return None, f'{ay["s"]}:{ay["a"]} has no ring'
        rings_out.append([ay['s'], ay['a'], rings])
    # Vertical check, per ayah line: the line's dense CORE - the contiguous
    # rows around its densest row that carry at least half that density,
    # i.e. the letter bodies on the baseline - must lie inside the band.
    # A band half a line off cuts the core; letters that nearly touch the
    # next line (Tajweed) or a rule under the line (gold) do not move it.
    prof = np.convolve(ink[:, xa:xb].sum(axis=1).astype(float), np.ones(3) / 3, mode='same')
    lines_used = sorted({round((r[0][1] * bh + ALPHA * pitch)) for _, _, rr in rings_out for r in rr})
    for y in lines_used:
        top, bot = y - ALPHA * pitch, y + BETA * pitch
        lo, hi = int(max(0, y - 0.5 * pitch)), int(min(bh, y + 0.4 * pitch))
        pk = lo + int(np.argmax(prof[lo:hi]))
        c0 = c1 = pk
        while c0 > lo and prof[c0 - 1] >= 0.5 * prof[pk]:
            c0 -= 1
        while c1 < hi - 1 and prof[c1 + 1] >= 0.5 * prof[pk]:
            c1 += 1
        out_by = max(top - c0, c1 - bot, 0) / pitch
        if out_by > VERT_MAX and not os.environ.get('NO_VERT'):
            return None, f'vertical line core {out_by:.2f} pitch outside its band'
    # coverage of the ayah lines' ink
    cov = np.zeros_like(ink, dtype=bool)
    for _, _, rings in rings_out:
        for r in rings:
            cov[int(r[0][1] * bh):int(r[2][1] * bh), int(r[0][0] * A.BW):int(r[1][0] * A.BW)] = True
    text = np.zeros_like(cov)
    # every page ends at an ayah end, so a line after the last marker is the
    # next surah's banner or basmala, never ayah text
    last_line = found[-1][0]
    first_line = min(seg[1] for seg in segs)
    for k in text_lines:
        if k in ext and first_line <= k <= last_line and k not in header:
            text[int(base[k] - 0.5 * pitch):int(base[k] + 0.2 * pitch), ext[k][0]:ext[k][1]] = True
    text &= ink.astype(bool)
    recall = (text & cov).sum() / max(1, text.sum())
    if recall < 0.97:
        return None, f'coverage {recall:.3f}'
    # Independent check: an ayah is the same text in every printing, so its
    # highlighted length (in line widths) must match Madinah's to within a
    # quarter of a line. A boundary on the wrong marker makes two
    # neighbouring ayahs disagree by far more than that.
    hl = {}
    for a in hafs_entry['ayahs']:
        hl[(a['s'], a['a'])] = sum(r[2] - r[0] for r in a['r']) / 0.973
    mine = {(s_, a_): sum(r[1][0] - r[0][0] for r in rings) * A.BW / wid
            for s_, a_, rings in rings_out}
    # the page's own density against Madinah's (Qatar sets page 76's ayahs
    # in 14 lines where Madinah uses 15)
    dens = sum(mine.values()) / max(1e-6, sum(hl[k] for k in mine))
    worst = 0.0
    for k, v in mine.items():
        diff = abs(v - dens * hl[k])
        worst = max(worst, diff)
        if diff > 0.35 + 0.08 * hl[k] and not os.environ.get('NO_LEN'):
            return None, f'length {k[0]}:{k[1]} {v:.2f} vs Madinah {dens * hl[k]:.2f} lines'
    return {'rings': rings_out, 'aspect': entry['aspect'], 'recall': round(float(recall), 4),
            'len_worst': round(worst, 3)}, 'ok'


def draw(ed, p, entry, res, out):
    box, _ = A.compose(Image.open(A.page_file(ed, p)), entry['aspect'])
    bh = box.size[1]
    over = Image.new('RGBA', box.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for i, (_, _, rings) in enumerate(res['rings']):
        c = (40, 200, 120, 95) if i % 2 == 0 else (230, 160, 40, 95)
        for r in rings:
            d.rectangle([r[0][0] * A.BW, r[0][1] * bh, r[2][0] * A.BW, r[2][1] * bh],
                        fill=c, outline=(200, 0, 0, 255))
    Image.alpha_composite(box.convert('RGBA'), over).convert('RGB').save(out)


def main():
    ed = sys.argv[1]
    rng = range(1, 605)
    if '--pages' in sys.argv:
        a, b = sys.argv[sys.argv.index('--pages') + 1].split('-')
        rng = range(int(a), int(b) + 1)
    drawn = []
    if '--draw' in sys.argv:
        drawn = [int(x) for x in sys.argv[sys.argv.index('--draw') + 1].split(',')]
    data = json.load(open(os.path.join(A.HL, 'rects.json'), encoding='utf-8'))
    tpl = M.template(ed)
    header_reference(ed, data, tpl)
    pages, aspects, report = {}, {}, {}
    for p in rng:
        e = data[ed]['pages'].get(str(p))
        he = data['hafs_kfqc']['pages'].get(str(p))
        if not e or not he or p <= 2:
            continue  # pages 1-2 are set in a different, centred block
        try:
            res, why = build_page(ed, p, e, he, tpl)
        except Exception as ex:  # a page that breaks the builder is a rejected page
            res, why = None, f'error {type(ex).__name__}: {ex}'
        report[p] = why if not res else f"ok {res['len_worst']}"
        if res:
            pages[str(p)] = res['rings']
            aspects[str(p)] = res['aspect']
            if p in drawn:
                draw(ed, p, e, res, os.path.join(A.HL, f'own_{ed}_{p:03d}.png'))
    json.dump({'pages': pages, 'aspect': aspects},
              open(os.path.join(A.HL, f'own_{ed}.json'), 'w'))
    json.dump(report, open(os.path.join(A.HL, f'own_{ed}_report.json'), 'w'), indent=0)
    ok = sum(1 for v in report.values() if v.startswith('ok'))
    print(f'{ed}: built {ok}/{len(report)} pages')
    reasons = {}
    for v in report.values():
        if not v.startswith('ok'):
            key = v.split(' ')[0] if not v.startswith('coverage') else 'coverage'
            reasons[key] = reasons.get(key, 0) + 1
    print('  rejected by:', reasons)


if __name__ == '__main__':
    main()
