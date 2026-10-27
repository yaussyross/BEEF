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
