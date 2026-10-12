import { decodeJwt } from 'jose';
import { verifyGoogleToken } from './google_token';

export interface ReviewerIdentity {
  sub: string;
  reviewer: string;
  role: 'reviewer' | 'admin';
}

/** Trusted deployment configuration, never names or roles supplied by a request. */
function reviewerGrant(configuration: string | undefined, token: string, sub: string): ReviewerIdentity | null {
  try {
    if (!configuration || configuration.length > 32_768) return null;
    const grants: unknown = JSON.parse(configuration);
    if (!Array.isArray(grants) || !grants.length || grants.length > 100) return null;
    // Decode only AFTER verification of this same token. A sub grant is
    // stable; email grants additionally require Google's authoritative email.
    const payload = decodeJwt(token);
    if (payload.sub !== sub) return null;
    const email = typeof payload.email === 'string' ? payload.email.toLowerCase() : '';
    const authoritative = payload.email_verified === true &&
      (email.endsWith('@gmail.com') || email.endsWith('@googlemail.com') ||
        (typeof payload.hd === 'string' && payload.hd.length > 0));
    const names = new Set<string>();
    let found: ReviewerIdentity | null = null;
    for (const grant of grants) {
      if (!grant || typeof grant !== 'object') return null;
      const row = grant as Record<string, unknown>;
      if (typeof row.name !== 'string' || !row.name.length || row.name.length > 60 ||
          row.name.trim() !== row.name || names.has(row.name) ||
          (row.role !== 'reviewer' && row.role !== 'admin')) return null;
      names.add(row.name);
      const hasSub = typeof row.sub === 'string' && row.sub.length > 0 && row.sub.length <= 255;
      const hasEmail = typeof row.email === 'string' && row.email.length > 0 && row.email.length <= 254;
      if (!hasSub && !hasEmail) return null;
      if ((row.sub !== undefined && !hasSub) || (row.email !== undefined && !hasEmail)) return null;
      if (hasSub && row.sub !== sub) continue;
      if (hasEmail && ((!hasSub && !authoritative) || (row.email as string).toLowerCase() !== email)) continue;
      if (found) return null;
      found = { sub, reviewer: row.name, role: row.role };
    }
    return found;
  } catch { return null; }
}

export async function authenticateReviewer(request: Request, configuration: string | undefined): Promise<{
  identity: ReviewerIdentity | null; status: 401 | 403;
}> {
  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return { identity: null, status: 401 };
  const token = authorization.slice(7);
  const sub = await verifyGoogleToken(token);
  if (!sub) return { identity: null, status: 401 };
  return { identity: reviewerGrant(configuration, token, sub), status: 403 };
}
