import { createFileRoute } from '@tanstack/react-router';
import { sql } from '~/db';
import { json, readJson } from '~/lib/http';

export const Route = createFileRoute('/api/waitlist')({ server: { handlers: {
  POST: async ({ request }) => {
    const body = await readJson(request);
    const email = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : '';
    if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      return json({ ok: false, error: 'That email looks a little undercooked. Try again?' }, { status: 400 });
    }
    try {
      // citext UNIQUE makes retries/case variants idempotent. Existing invite
      // state/source/timestamps are preserved; no account or email is created.
      await sql()`INSERT INTO waitlist_emails (email, source)
        VALUES (${email}, 'landing_page') ON CONFLICT (email) DO NOTHING`;
      return json({ ok: true });
    } catch {
      // Never return or log addresses, database credentials or SQL errors.
      return json({ ok: false, error: "We couldn't confirm your place. Your email is still here; please try again." }, { status: 503 });
    }
  },
} } });
