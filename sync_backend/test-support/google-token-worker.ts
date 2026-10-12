// Test entrypoint only; wrangler.toml still selects src/index.ts for production.
import { createGoogleTokenVerifier } from '../src/google_token';

let keys: unknown;
let offline = false;
let keyRequests = 0;
const verify = createGoogleTokenVerifier({ fetch: async (input) => {
  if (input !== 'https://www.googleapis.com/oauth2/v3/certs') throw new Error('Unexpected key URL');
  keyRequests++;
  return offline ? new Response(null, { status: 503 }) : Response.json(keys, {
    headers: { 'cache-control': 'max-age=300' },
  });
} });

export default {
  async fetch(request: Request): Promise<Response> {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204 });
    if (new URL(request.url).pathname === '/test-control') {
      const body = await request.json() as { keys?: unknown; offline?: boolean };
      if (body.keys) keys = body.keys;
      offline = body.offline ?? false;
      return Response.json({ keyRequests });
    }
    const subject = await verify(await request.text());
    return Response.json({ subject, keyRequests }, { status: subject ? 200 : 401 });
  },
};
