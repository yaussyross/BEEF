import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { AuthError, issueTokens, normalizeEmail, verifyPassword } from "~/lib/auth";
import { errorResponse, json, readJson } from "~/lib/http";

/**
 * POST /api/login
 * Body: { email, password }
 *
 * Returns access + refresh tokens. Rejects deleted/suspended/banned accounts.
 * Never returns the birthdate.
 */
export const Route = createFileRoute("/api/login")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }
        const email = normalizeEmail(typeof body.email === "string" ? body.email : "");
        const password = typeof body.password === "string" ? body.password : "";

        if (!email || !password) {
          return json(
            { error: "missing_credentials", message: "Email and password are required." },
            { status: 400 }
          );
        }

        try {
          const rows = await sql()`SELECT id, email, password_hash, status
                                 FROM users
                                 WHERE email = ${email}
                                 LIMIT 1`;
          const user = rows[0] as
            | { id: string; email: string; password_hash: string; status: string }
            | undefined;

          // Constant-ish time response whether or not the account exists.
          if (!user || !(await verifyPassword(password, user.password_hash))) {
            throw new AuthError(
              401,
              "invalid_credentials",
              "That email and password don't match."
            );
          }

          if (user.status !== "active") {
            throw new AuthError(403, "account_disabled", "This account is not active.");
          }

          const tokens = await issueTokens(user.id, user.email);
          return json({ user: { id: user.id, email: user.email }, ...tokens });
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});
