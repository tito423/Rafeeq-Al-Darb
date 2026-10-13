// The review site's only credential: a random key the Worker issues the first
// time a name is claimed. No account, no list (owner, 2026-10-13) - the
// reviewer writes his name once; this browser keeps the key that lets it
// write under that name, so nobody else can write under it.
(function (root) {
  const NAME = 'reviewer';
  const KEY = 'reviewer_key_v1';

  function create({ api, storage, fetch }) {
    const get = (k) => { try { return storage.getItem(k); } catch { return null; } };
    const set = (k, v) => { try { storage.setItem(k, v); } catch { /* private mode */ } };
    const drop = (k) => { try { storage.removeItem(k); } catch { /* private mode */ } };
    return {
      get name() { return get(NAME); },
      get hasKey() { return !!get(KEY); },

      /** {ok, reviewer} | {ok:false, error:'taken'|'short'|'failed'} */
      async register(raw) {
        const name = String(raw || '').trim().replace(/\s+/g, ' ').slice(0, 60);
        if (name.length < 3) return { ok: false, error: 'short' };
        let res;
        try {
          res = await fetch(api + '/register', {
            method: 'POST', headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ reviewer: name }),
          });
        } catch { return { ok: false, error: 'failed' }; }
        if (res.status === 409) return { ok: false, error: 'taken' };
        if (!res.ok) return { ok: false, error: 'failed' };
        const data = await res.json();
        set(NAME, data.reviewer);
        set(KEY, data.token);
        return { ok: true, reviewer: data.reviewer };
      },

      /** POSTs notes with the key. A 401 means the key is gone: forget it. */
      async post(notes) {
        const res = await fetch(api, {
          method: 'POST',
          headers: { 'content-type': 'application/json', Authorization: 'Bearer ' + get(KEY) },
          body: JSON.stringify({ reviewer: get(NAME), notes }),
        });
        if (res.status === 401) drop(KEY);
        return res;
      },
    };
  }

  root.RafeeqReviewKey = { create };
})(globalThis);
