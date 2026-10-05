import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import {
  EMAIL_RE,
  hashPassword,
  isAdult,
  issueTokens,
  normalizeEmail,
  validatePassword,
} from "~/lib/auth";
import { errorResponse, json, readJson } from "~/lib/http";

/**
 * POST /api/register
 * Body: { email, password, birthdate (YYYY-MM-DD) }
 *
 * - Mandatory birthdate; rejected server-side if under 18.
 * - Password bcrypt-hashed (never stored or compared plaintext).
 * - Email stored lowercased (citext column double-enforces uniqueness).
 * - Creates the user + an empty profile atomically (single CTE statement).
 * - Returns access + refresh tokens. Birthdate is NEVER returned.
 */
export const Route = createFileRoute("/api/register")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }

        const email = normalizeEmail(typeof body.email === "string" ? body.email : "");
        const password = typeof body.password === "string" ? body.password : "";
        const birthdate = typeof body.birthdate === "string" ? body.birthdate : "";

        if (!EMAIL_RE.test(email)) {
          return json(
            { error: "invalid_email", message: "That email doesn't look right. Try again?" },
            { status: 400 }
          );
        }
        const passwordError = validatePassword(password);
        if (passwordError) {
          return json({ error: "weak_password", message: passwordError }, { status: 400 });
        }
        if (!/^\d{4}-\d{2}-\d{2}$/.test(birthdate)) {
          return json(
            { error: "invalid_birthdate", message: "Birthdate is required (YYYY-MM-DD)." },
            { status: 400 }
          );
        }
        if (!isAdult(birthdate)) {
          // Privacy-first 18+ gate, enforced server-side on every registration.
          return json(
            { error: "underage", message: "You must be at least 18 years old to use BEEF." },
            { status: 403 }
          );
        }

        try {
          const passwordHash = await hashPassword(password);

          // Atomic user+profile insert. ON CONFLICT DO NOTHING + no returned row
          // means the email is already registered (race-safe).
          const rows = await sql()`WITH new_user AS (
              INSERT INTO users (email, password_hash, birthdate, signup_source)
              VALUES (${email}, ${passwordHash}, ${birthdate}::date, 'direct')
              ON CONFLICT (email) DO NOTHING
              RETURNING id
            )
            INSERT INTO profiles (user_id)
            SELECT id FROM new_user
            RETURNING user_id`;

          const userRow = rows[0] as { user_id?: string } | undefined;
          if (!userRow?.user_id) {
            return json(
              { error: "email_taken", message: "That email is already on the grill." },
              { status: 409 }
            );
          }

          const tokens = await issueTokens(userRow.user_id, email);
          return json(
            {
              user: { id: userRow.user_id, email },
              ...tokens,
            },
            { status: 201 }
          );
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});
