export interface Env {
	DB: D1Database;
}

const GOOGLE_CLIENT_ID = "227986327850-ha6gea87kueaeg2a3582ecpu3s0nbnh1.apps.googleusercontent.com";

interface TokenPayload {
	iss: string;
	sub: string;
	aud: string;
	exp: string;
}

async function verifyGoogleToken(idToken: string): Promise<string | null> {
	try {
		const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
		if (!response.ok) {
			return null;
		}
		const payload: TokenPayload = await response.json();
		
		const validIssuers = ['accounts.google.com', 'https://accounts.google.com'];
		if (!validIssuers.includes(payload.iss)) return null;
		if (payload.aud !== GOOGLE_CLIENT_ID) return null;
		
		const expTime = parseInt(payload.exp, 10);
		const currentTime = Math.floor(Date.now() / 1000);
		if (expTime < currentTime) return null;
		
		return payload.sub;
	} catch (e) {
		return null;
	}
}

const REVIEW_CORS: Record<string, string> = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
	'Access-Control-Allow-Headers': 'content-type',
	'Access-Control-Max-Age': '86400',
};

// ── Fences on /sync (audit 2026-09-24, B1) ─────────────────────────────
// One signed-in account could write unbounded rows of unbounded size. The
// app syncs exactly these keys (SyncService.syncedStateKeys /
// syncedCounterKeys); anything else is IGNORED, not refused, because older
// app versions sent every preference and a refusal would leave their queue
// retrying the same request for ever.
const SYNC_STATE_KEYS = new Set(['khatma_list_v1', 'ayah_notes_v1', 'quran_last_page', 'tasbeeh_custom_target']);
const SYNC_COUNTER_KEYS = new Set(['tasbeeh_total', 'azkar_total']);
const MAX_SYNC_BODY = 1_048_576; // bytes per request
const MAX_STATE_VALUE = 524_288; // bytes per stored value
const MAX_UPDATES = 100;
const MAX_COUNTERS = 1000;
const MAX_INCREMENT = 10_000_000;

const MAX_NAME = 60;
const MAX_ID = 120;
const MAX_NOTE = 4000;
const MAX_BATCH = 200;

function reviewJson(body: unknown, status = 200): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: { 'content-type': 'application/json; charset=utf-8', ...REVIEW_CORS },
	});
}

function clean(v: unknown, max: number): string {
	return typeof v === 'string' ? v.trim().slice(0, max) : '';
}

let reviewTableReady = false;

async function handleReview(request: Request, url: URL, env: Env): Promise<Response> {
	if (request.method === 'OPTIONS') {
		return new Response(null, { status: 204, headers: REVIEW_CORS });
	}

	// Once per isolate, not once per request (audit B5).
	if (!reviewTableReady) await env.DB.prepare(
		`CREATE TABLE IF NOT EXISTS review_notes (
			reviewer TEXT NOT NULL,
			item_id TEXT NOT NULL,
			note TEXT NOT NULL,
			done INTEGER NOT NULL DEFAULT 0,
			excerpt TEXT NOT NULL DEFAULT '',
			section TEXT NOT NULL DEFAULT '',
			updated_at INTEGER NOT NULL,
			PRIMARY KEY (reviewer, item_id)
		)`
	).run();
	reviewTableReady = true;

	// POST /review - one reviewer's notes, upserted by (reviewer, item).
	if (request.method === 'POST') {
		let body: any;
		try {
			body = await request.json();
		} catch {
			return reviewJson({ error: 'bad json' }, 400);
		}
		const reviewer = clean(body?.reviewer, MAX_NAME);
		if (!reviewer) return reviewJson({ error: 'reviewer required' }, 400);
		const notes = Array.isArray(body?.notes) ? body.notes.slice(0, MAX_BATCH) : [];
		if (!notes.length) return reviewJson({ saved: 0 });

		const now = Date.now();
		const statements: D1PreparedStatement[] = [];
		for (const n of notes) {
			const itemId = clean(n?.id, MAX_ID);
			if (!itemId) continue;
			const note = clean(n?.note, MAX_NOTE);
			const done = n?.done ? 1 : 0;
			// A row with neither a note nor a tick is the reviewer undoing
			// what he wrote; it is deleted rather than stored empty.
			if (!note && !done) {
				statements.push(
					env.DB.prepare('DELETE FROM review_notes WHERE reviewer = ? AND item_id = ?')
						.bind(reviewer, itemId)
				);
				continue;
			}
			statements.push(
				env.DB.prepare(
					`INSERT INTO review_notes (reviewer, item_id, note, done, excerpt, section, updated_at)
					 VALUES (?, ?, ?, ?, ?, ?, ?)
					 ON CONFLICT(reviewer, item_id) DO UPDATE SET
					 note = excluded.note, done = excluded.done,
					 excerpt = excluded.excerpt, section = excluded.section,
					 updated_at = excluded.updated_at`
				).bind(reviewer, itemId, note, done, clean(n?.excerpt, 300), clean(n?.section, 200), now)
			);
		}
		if (statements.length) await env.DB.batch(statements);
		return reviewJson({ saved: statements.length, at: now });
	}

	if (request.method !== 'GET') return reviewJson({ error: 'method' }, 405);

	// GET /review/reviewers - who has reviewed, and how much.
	if (url.pathname === '/review/reviewers') {
		const { results } = await env.DB.prepare(
			`SELECT reviewer, COUNT(*) AS items,
			        SUM(CASE WHEN note <> '' THEN 1 ELSE 0 END) AS notes,
			        SUM(done) AS done, MAX(updated_at) AS last
			 FROM review_notes GROUP BY reviewer ORDER BY last DESC`
		).all();
		return reviewJson({ reviewers: results });
	}

	// GET /review?reviewer=NAME - everything that reviewer wrote.
	const reviewer = clean(url.searchParams.get('reviewer'), MAX_NAME);
	if (!reviewer) return reviewJson({ error: 'reviewer required' }, 400);
	const { results } = await env.DB.prepare(
		`SELECT item_id, note, done, excerpt, section, updated_at
		 FROM review_notes WHERE reviewer = ? ORDER BY updated_at DESC`
	).bind(reviewer).all();
	return reviewJson({ reviewer, notes: results });
}

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		const url0 = new URL(request.url);

		// ── The content-review site ─────────────────────────────────────
		// https://tito423.github.io/rafeeq-review/ is where a scholar reads
		// every religious text the app ships and writes his notes on it.
		// These routes are deliberately OUTSIDE the Google check below: a
		// reviewer types his name and starts; asking him to hold a Google
		// account before he can correct a hadith grading is a wall in front
		// of the one thing we want him to do.
		//
		// The trade is that this is an open write endpoint, so it is fenced
		// rather than trusted: fixed short columns, a per-request size cap,
		// and a reviewer name that is stored as given but bounded. It holds
		// review notes and nothing else - no reader's data is reachable
		// from here.
		if (url0.pathname.startsWith('/review')) {
			return handleReview(request, url0, env);
		}

		const authHeader = request.headers.get('Authorization');
		if (!authHeader || !authHeader.startsWith('Bearer ')) {
			return new Response('Unauthorized', { status: 401 });
		}
		const token = authHeader.substring(7);
		const sub = await verifyGoogleToken(token);
		
		if (!sub) {
			return new Response('Unauthorized', { status: 401 });
		}

		const url = new URL(request.url);

		if (request.method === 'GET' && url.pathname === '/sync') {
			// Fetch state
			const { results: stateResults } = await env.DB.prepare(
				'SELECT key, value, updated_at FROM user_state WHERE sub = ?'
			).bind(sub).all();

			// Fetch counters (grouped by key to get totals)
			const { results: countersResults } = await env.DB.prepare(
				'SELECT key, SUM(increment_value) as total FROM user_counters WHERE sub = ? GROUP BY key'
			).bind(sub).all();

			return Response.json({
				state: stateResults,
				counters: countersResults
			});
		}

		if (request.method === 'POST' && url.pathname === '/sync') {
			const declared = Number(request.headers.get('content-length') ?? '0');
			if (declared > MAX_SYNC_BODY) return new Response('Payload Too Large', { status: 413 });
			try {
				const raw = await request.text();
				if (raw.length > MAX_SYNC_BODY) return new Response('Payload Too Large', { status: 413 });
				const body: any = JSON.parse(raw);
				
				const statements: D1PreparedStatement[] = [];

				if (Array.isArray(body.updates)) {
					for (const update of body.updates.slice(0, MAX_UPDATES)) {
						if (!SYNC_STATE_KEYS.has(update?.key)) continue;
						if (typeof update.value !== 'string' || update.value.length > MAX_STATE_VALUE) continue;
						if (update.key && update.value && update.updated_at !== undefined) {
							// For state, we upsert, but only if the incoming updated_at is greater
							// However, SQLite UPSERT (ON CONFLICT) is supported.
							// D1 uses SQLite.
							statements.push(
								env.DB.prepare(
									`INSERT INTO user_state (sub, key, value, updated_at) 
									 VALUES (?, ?, ?, ?) 
									 ON CONFLICT(sub, key) DO UPDATE SET 
									 value = excluded.value, 
									 updated_at = excluded.updated_at 
									 WHERE excluded.updated_at > user_state.updated_at`
								).bind(sub, update.key, update.value, update.updated_at)
							);
						}
					}
				}

				if (Array.isArray(body.counters)) {
					for (const counter of body.counters.slice(0, MAX_COUNTERS)) {
						if (!SYNC_COUNTER_KEYS.has(counter?.key)) continue;
						if (typeof counter.event_id !== 'string' || counter.event_id.length > 64) continue;
						const inc = counter.increment_value;
						if (!Number.isInteger(inc) || Math.abs(inc) > MAX_INCREMENT) continue;
						if (counter.key && counter.event_id && counter.increment_value !== undefined) {
							// Insert ignore using ON CONFLICT DO NOTHING
							statements.push(
								env.DB.prepare(
									`INSERT INTO user_counters (sub, key, event_id, increment_value) 
									 VALUES (?, ?, ?, ?) 
									 ON CONFLICT(sub, key, event_id) DO NOTHING`
								).bind(sub, counter.key, counter.event_id, counter.increment_value)
							);
						}
					}
				}

				if (statements.length > 0) {
					await env.DB.batch(statements);
				}

				return Response.json({ success: true });
			} catch (e) {
				return new Response('Bad Request', { status: 400 });
			}
		}

		return new Response('Not Found', { status: 404 });
	},
};
