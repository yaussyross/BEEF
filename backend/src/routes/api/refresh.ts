import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { AuthError, issueTokens, verifyRefreshToken } from "~/lib/auth";
import { errorResponse, json, readJson } from "~/lib/http";

/**
 * POST /api/refresh
 * Body: { refreshToken }
 *
 * Verifies the refresh token, confirms the account is still active, and issues
 * a fresh access + refresh pair (rotation). Stateless JWTs mean a stolen old
 * refresh token stays valid until expiry — acceptable for v1; a revocable
 * server-side token store is a later hardening item.
 */
export const Route = createFileRoute("/api/refresh")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const body = await readJson(request);
        const refreshToken = typeof body?.refreshToken === "string" ? body.refreshToken : "";

        if (!refreshToken) {
          return json(
            { error: "missing_refresh_token", message: "refreshToken is required." },
            { status: 400 }
          );
        }

        try {
          const userId = await verifyRefreshToken(refreshToken);

          const rows = await sql()`SELECT id, email, status
                                 FROM users
                                 WHERE id = ${userId}
                                 LIMIT 1`;
          const user = rows[0] as
            | { id: string; email: string; status: string }
            | undefined;

          if (!user) {
            throw new AuthError(401, "invalid_token", "Account no longer exists.");
          }
          if (user.status !== "active") {
            throw new AuthError(403, "account_disabled", "This account is not active.");
          }

          const tokens = await issueTokens(user.id, user.email);
          return json(tokens);
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});
