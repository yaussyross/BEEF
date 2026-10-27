import { timingSafeEqual } from 'node:crypto';
/** Exact account allowlist, independent of JWT claims and proxy headers. */
export class AccessGateError extends Error {
  constructor(public status: number, public code: string, message: string) { super(message); }
}
export function closedTestPolicy(env: Record<string, string | undefined> = process.env) {
  const mode = env.BEEF_ACCESS_MODE ?? 'closed_test';
  if (mode === 'open') return { closed: false, emails: new Set<string>() };
  if (mode !== 'closed_test') throw new AccessGateError(503, 'access_unavailable', 'Test access is unavailable.');
  const entries = (env.BEEF_CLOSED_TEST_EMAILS ?? '').split(',').map(s => s.trim().toLowerCase());
  if (!entries.length || entries.length > 100 || entries.some(s => !s || s.length > 254 ||
      !/^[^\s@*,]+@[^\s@*,]+\.[^\s@*,]{2,}$/.test(s))) {
    throw new AccessGateError(503, 'access_unavailable', 'Test access is unavailable.');
  }
  return { closed: true, emails: new Set(entries) };
}
export function requireAllowedTestEmail(email: unknown): void {
  const policy = closedTestPolicy();
  if (policy.closed && (typeof email !== 'string' || !policy.emails.has(email.trim().toLowerCase()))) {
    throw new AccessGateError(403, 'closed_test_only', 'This service is restricted to approved test accounts.');
  }
}

/** Publicly known fixture addresses are not account-creation credentials. */
export function registrationSource(request: Request, env: Record<string, string | undefined> = process.env) {
  if (!closedTestPolicy(env).closed) return 'direct';
  const expected = env.BEEF_CLOSED_TEST_SETUP_KEY ?? '';
  const supplied = request.headers.get('X-BEEF-Test-Setup-Key') ?? '';
  if (expected.length < 32 || expected.length > 256 || supplied.length > 256 ||
      Buffer.byteLength(expected) !== Buffer.byteLength(supplied) ||
      !timingSafeEqual(Buffer.from(expected), Buffer.from(supplied))) {
    throw new AccessGateError(403, 'test_setup_required', 'Test account setup is restricted.');
  }
  return 'synthetic_demo';
}
