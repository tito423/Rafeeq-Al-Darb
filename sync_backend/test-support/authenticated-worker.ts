// Test entrypoint only. Production wrangler.toml selects src/index.ts.
let keys: unknown;
let reviewers: string | undefined;
const originalFetch = globalThis.fetch.bind(globalThis);
globalThis.fetch = async (input, init) => {
  const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
  if (url === 'https://www.googleapis.com/oauth2/v3/certs') {
    return Response.json(keys, { headers: { 'cache-control': 'max-age=300' } });
  }
  return originalFetch(input, init);
};

export default {
  async fetch(request: Request, env: Record<string, unknown>, context: ExecutionContext): Promise<Response> {
    const path = new URL(request.url).pathname;
    if (path === '/_test/setup') {
      const body = await request.json() as { keys: unknown; reviewers: unknown };
      keys = body.keys;
      reviewers = JSON.stringify(body.reviewers);
      return Response.json({ ready: true });
    }
    // Load after the test transport is installed, including on real workerd.
    const { default: worker } = await import('../src/index');
    return worker.fetch(request, { ...env, REVIEWERS: reviewers } as unknown as import('../src/index').Env, context);
  },
};
