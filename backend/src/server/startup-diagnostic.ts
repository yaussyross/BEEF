/** Only fixed codes reach logs. Never return message/stack/URL/SQL/environment. */
export function startupDiagnostic(error: unknown): string {
  const e = error as { message?: unknown; code?: unknown } | null;
  const messages: Record<string, string> = {
    'Invalid BEEF_HOST': 'invalid_host', 'Invalid BEEF_PORT': 'invalid_port',
    'DATABASE_URL is required': 'missing_database', 'DATABASE_URL must use PostgreSQL': 'invalid_database_scheme',
    'Invalid DATABASE_URL': 'invalid_database', 'Invalid BEEF_DATABASE_DRIVER': 'invalid_driver',
    'Invalid BEEF_DATABASE_TLS': 'invalid_tls_policy',
    'Render internal TLS requires an unmodified internal database URL': 'invalid_internal_database_url',
    'Test access is unavailable.': 'invalid_test_allowlist_or_mode',
    'JWT_SECRET must contain at least 32 characters': 'invalid_jwt_secret',
    'MODERATION_ADMIN_KEY must contain at least 32 characters': 'invalid_moderator_secret',
  };
  if (typeof e?.message === 'string' && Object.hasOwn(messages, e.message)) return messages[e.message];
  if (typeof e?.code === 'string' && /^[0-9A-Z]{5}$/.test(e.code)) return `sqlstate_${e.code}`;
  return 'unclassified';
}
