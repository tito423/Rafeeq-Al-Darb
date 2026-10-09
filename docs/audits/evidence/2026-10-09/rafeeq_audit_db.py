from pathlib import Path
import sqlite3,json,sys,zipfile,importlib.util
root=Path('E:/My Projects/Rafiq-Al-Darb');out=root/'docs/audits/evidence/2026-10-09'
spec=importlib.util.spec_from_file_location('types',root/'scripts/db_type_audit.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
mod.REPORT=str(out/'db-type-audit.log');code=mod.main()
result=[]
for p in sorted((root/'rafeeq_app/assets/data').glob('*.db')):
    con=sqlite3.connect(p.as_uri()+'?mode=ro',uri=True)
    tables=[r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
    entry={'file':str(p.relative_to(root)),'bytes':p.stat().st_size,'quick_check':con.execute('PRAGMA quick_check').fetchone()[0],'indexes':[r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='index'")],'rows':{}}
    for t in tables:
        if not t.replace('_','').isalnum():continue
        try:entry['rows'][t]=con.execute('SELECT count(*) FROM "'+t+'"').fetchone()[0]
        except sqlite3.DatabaseError:pass
    result.append(entry);con.close()
(out/'db-census.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
con=sqlite3.connect(':memory:')
con.execute('CREATE TABLE user_state(updated_at INTEGER)')
con.execute('INSERT INTO user_state VALUES (?)',('far-future-text',))
poison={'stored_type':con.execute('SELECT typeof(updated_at) FROM user_state').fetchone()[0],'numeric_update_is_greater':bool(con.execute('SELECT ? > updated_at FROM user_state',(1791564000000,)).fetchone()[0])}
(out/'sqlite-timestamp-proof.json').write_text(json.dumps(poison,indent=2),encoding='utf-8')
print('DB type audit exit',code,'census DBs',len(result),'timestamp proof',json.dumps(poison))
