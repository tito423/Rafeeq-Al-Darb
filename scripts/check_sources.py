"""Are dorar.net and shamela.ws still read correctly? Runs the app's own
parsing rules (scripts/out/source_rules.json, built by
publish_source_rules.py from the Dart defaults) against the live sites.

    py -3 scripts/check_sources.py

Exit code 0 = every check passed, 1 = at least one failed (a site changed:
fix the rule in scripts/source_rules_overrides.json, bump its version,
publish_source_rules.py, run this again). Meant to run daily (Task
Scheduler); each failure names the rule to look at.
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RULES = os.path.join(HERE, "out", "source_rules.json")
UA = "RafeeqAlDarb (Android; personal library)"


def get(url, ajax=False):
    h = {"User-Agent": UA}
    if ajax:
        h["X-Requested-With"] = "XMLHttpRequest"
    with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=40) as r:
        return r.read().decode("utf-8", "replace")


def rx(rule, dotall=True):
    return re.compile(rule, re.S if dotall else 0)


def main():
    if not os.path.exists(RULES):
        os.system(f'py -3 "{os.path.join(HERE, "publish_source_rules.py")}" --dry-run')
    r = json.load(open(RULES, encoding="utf-8"))["rules"]
    results = []

    def check(name, rule_keys, fn):
        try:
            ok, detail = fn()
        except Exception as e:  # network or parse error
            ok, detail = False, f"{type(e).__name__}: {e}"
        results.append((ok, name, rule_keys, detail))

    def dorar_toc():
        h = get("https://dorar.net/aqeeda")
        if r["dorar.toc.start"] not in h:
            return False, "toc marker missing"
        links = [m for m in rx(r["dorar.toc.token"]).finditer(h)
                 if re.match(r"^/aqeeda/\d+$", m.group(1) or "")]
        return len(links) >= 1000, f"{len(links)} section links (expected >= 1000; 1,469 on 2026-09-26)"

    def dorar_section():
        h = get("https://dorar.net/aqeeda/37")
        a = h.find(r["dorar.section.start"])
        card = h.find(r["dorar.section.card"])
        t = rx(r["dorar.section.title"]).search(h[card:] if card >= 0 else h)
        notes = rx(r["dorar.section.footnote"]).findall(h)
        ok = a >= 0 and t is not None and len(notes) >= 1
        return ok, f"start={a >= 0} title={bool(t)} footnotes={len(notes)}"

    def dorar_api():
        q = urllib.parse.urlencode({"skey": "إنما الأعمال بالنيات"})
        j = json.loads(get(f'{r["dorar.api.url"]}?{q}'))
        html = j["ahadith"]["result"]
        blocks = rx(r["dorar.api.block"]).findall(html)
        graded = sum(r["dorar.api.label.grade"] in b[1] for b in blocks)
        named = sum(r["dorar.api.label.muhaddith"] in b[1] for b in blocks)
        return len(blocks) >= 5 and graded >= 5 and named >= 5, \
            f"{len(blocks)} results, {graded} with grade label, {named} with muhaddith label"

    def shamela_card():
        h = get("https://shamela.ws/book/9632")
        m = rx(r["shamela.card"]).search(h)
        if not m:
            return False, "card block missing"
        card = re.sub(r"<[^>]+>", "", re.sub(r"<br\s*/?>", "\n", m.group(1)))
        t = rx(r["shamela.card.title"], False).search(card)
        return bool(t) and "تحفة" in t.group(1), f"title={t.group(1).strip() if t else None}"

    def shamela_page():
        path = r["shamela.page.path"].replace("{book}", "9632").replace("{page}", "1")
        j = json.loads(get(f"https://shamela.ws{path}", ajax=True))
        nass = j.get("nass", "") if isinstance(j, dict) else ""
        return len(nass) > 50 and "nextId" in j, f"nass {len(nass)} chars, nextId={'nextId' in j}"

    check("Dorar encyclopaedia contents", "dorar.toc.*", dorar_toc)
    check("Dorar encyclopaedia section", "dorar.section.*", dorar_section)
    def dorar_tafseer():
        h = get("https://dorar.net/tafseer")
        surahs = rx(r["dorar.tafseer.surah"]).findall(h)
        p = get("https://dorar.net/tafseer/2/1")
        arts = rx(r["dorar.chain.article"]).findall(p)
        links = {re.sub(r"<[^>]+>|\s", "", t): u for u, t in rx(r["dorar.chain.link"]).findall(p)}
        ok = len(surahs) == 114 and len(arts) >= 5 and             links.get(r["dorar.chain.next"]) == "/tafseer/2/2"
        return ok, f"{len(surahs)} surahs, {len(arts)} sections, next={links.get(r['dorar.chain.next'])}"

    check("Dorar hadith grading API", "dorar.api.*", dorar_api)
    check("Dorar Tafseer surahs + chain", "dorar.tafseer.*, dorar.chain.*", dorar_tafseer)
    check("Shamela book card", "shamela.card*", shamela_card)
    check("Shamela page content", "shamela.page.path", shamela_page)

    for ok, name, keys, detail in results:
        print(f"{'OK  ' if ok else 'FAIL'} {name} [{keys}] - {detail}")
    failed = [x for x in results if not x[0]]
    print(f"{len(results) - len(failed)}/{len(results)} passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
