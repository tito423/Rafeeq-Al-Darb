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

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
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
			try {
				const body: any = await request.json();
				
				const statements: D1PreparedStatement[] = [];

				if (Array.isArray(body.updates)) {
					for (const update of body.updates) {
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
					for (const counter of body.counters) {
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
