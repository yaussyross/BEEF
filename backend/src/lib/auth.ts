import { hash, compare } from "bcryptjs";
import { SignJWT, jwtVerify } from "jose";

/**
 * BEEF — auth primitives (server-only).
 *
 * - Passwords: bcrypt (bcryptjs), never stored or compared in plaintext.
 * - Tokens: short-lived JWT access (15m) + refresh (30d), HS256, signed with
 *   the `JWT_SECRET` env var. Access uses audience "beef:access", refresh uses
 *   "beef:refresh" so a refresh token can never be replayed as an access token.
 * - Privacy-first: the mandatory birthdate is validated here and stored by the
 *   caller, but is NEVER returned in any token payload or API response that
 *   another user can read.
 */

const ACCESS_TTL = "15m";
const REFRESH_TTL = "30d";
const JWT_ISSUER = "beef";
const JWT_ALG = "HS256";
export const ACCESS_AUDIENCE = "beef:access";
export const REFRESH_AUDIENCE = "beef:refresh";
const BCRYPT_ROUNDS = 10;

export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
export const PASSWORD_MIN = 8;
export const PASSWORD_MAX = 128;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** True when `value` is a canonical UUID string (used to guard uuid columns). */
export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value);
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

/** Claims carried in an access token. */
export interface AccessClaims {
  sub: string; // user id
  email: string;
}

export class AuthError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function getSecret(): Uint8Array {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    throw new AuthError(
      500,
      "jwt_secret_unset",
      "JWT_SECRET is not set (must be at least 32 characters)."
    );
  }
  return new TextEncoder().encode(secret);
}

/** bcrypt hash a password. Returns the hash string to persist. */
export async function hashPassword(password: string): Promise<string> {
  return hash(password, BCRYPT_ROUNDS);
}

/** Constant-time password check against a stored bcrypt hash. */
export async function verifyPassword(password: string, storedHash: string): Promise<boolean> {
  return compare(password, storedHash);
}

/**
 * True when the given birthdate (ISO `YYYY-MM-DD`) corresponds to someone 18 or
 * older today. Mandatory 18+ gate — called on register and re-checked in the
 * DB trigger (users_assert_adult).
 */
export function isAdult(birthdate: string): boolean {
  const bd = new Date(`${birthdate}T00:00:00Z`);
  if (Number.isNaN(bd.getTime())) return false;
  const today = new Date();
  let age = today.getUTCFullYear() - bd.getUTCFullYear();
  const m = today.getUTCMonth() - bd.getUTCMonth();
  if (m < 0 || (m === 0 && today.getUTCDate() < bd.getUTCDate())) age -= 1;
  return age >= 18;
}

async function signJwt(
  payload: Record<string, unknown>,
  subject: string,
  audience: string,
  ttl: string
): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: JWT_ALG })
    .setIssuer(JWT_ISSUER)
    .setAudience(audience)
    .setSubject(subject)
    .setIssuedAt()
    .setExpirationTime(ttl)
    .sign(getSecret());
}

/** Short-lived access token for an authenticated user. */
export async function signAccessToken(userId: string, email: string): Promise<string> {
  return signJwt({ email }, userId, ACCESS_AUDIENCE, ACCESS_TTL);
}

/** Long-lived refresh token (client stores it in the secure keystore). */
export async function signRefreshToken(userId: string): Promise<string> {
  return signJwt({}, userId, REFRESH_AUDIENCE, REFRESH_TTL);
}

async function verifyJwt(token: string, audience: string): Promise<string> {
  try {
    const { payload } = await jwtVerify(token, getSecret(), {
      algorithms: [JWT_ALG],
      issuer: JWT_ISSUER,
      audience,
    });
    if (!payload.sub) throw new AuthError(401, "invalid_token", "Invalid token.");
    return payload.sub;
  } catch (err) {
    if (err instanceof AuthError) throw err;
    throw new AuthError(401, "invalid_token", "Invalid or expired token.");
  }
}

/** Verify an access token and return the user id (throws AuthError 401). */
export function verifyAccessToken(token: string): Promise<string> {
  return verifyJwt(token, ACCESS_AUDIENCE);
}

/** Verify a refresh token and return the user id (throws AuthError 401). */
export function verifyRefreshToken(token: string): Promise<string> {
  return verifyJwt(token, REFRESH_AUDIENCE);
}

/** Issue both tokens for a user. */
export async function issueTokens(userId: string, email: string): Promise<AuthTokens> {
  const [accessToken, refreshToken] = await Promise.all([
    signAccessToken(userId, email),
    signRefreshToken(userId),
  ]);
  return { accessToken, refreshToken };
}

/**
 * Parse and verify `Authorization: Bearer <jwt>` from a Request. Returns the
 * user id (subject) or throws AuthError(401). Use on every protected route.
 */
export async function requireAuth(request: Request): Promise<string> {
  const header = request.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    throw new AuthError(401, "missing_token", "Missing Authorization: Bearer <token> header.");
  }
  return verifyAccessToken(match[1].trim());
}

/** Normalize an email for storage/lookup (trim + lowercase). */
export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

/** Validate a raw password against the minimum bar. */
export function validatePassword(password: string): string | null {
  if (password.length < PASSWORD_MIN) {
    return `Password must be at least ${PASSWORD_MIN} characters.`;
  }
  if (password.length > PASSWORD_MAX) {
    return `Password must be at most ${PASSWORD_MAX} characters.`;
  }
  return null;
}
