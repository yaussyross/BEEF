# Private-test request hardening, November 12

Reconstructed from the recorded implementation after the earlier local checkout
and unpushed patch became unavailable. This is a new commit, not recovery of the
old commit SHA. Original branding/layout/assets are unchanged.

- Login: process-local fixed 60-second window; ten attempts per normalized email
  and 100 overall before database/password work. HTTP 429 supplies Retry-After.
  The map is bounded by the global allowance. No forwarded IP is trusted.
  This is single-process private-test protection, NOT a distributed production
  defense. Restart resets it and a malicious client can exhaust the global budget.
- JSON: 64 KiB streamed byte limit, also configured at Bun's HTTP entry point;
  missing/dishonest Content-Length cannot bypass the parser bound. Oversized or
  malformed JSON is rejected, not truncated into valid input.
- Client: each HTTP operation has a default 20-second deadline. Refresh 401/403
  clears tokens; rate limits, server/network errors, malformed refresh responses
  and timeouts preserve credentials and do not replay the original mutation.
  Late refresh completion cannot rotate tokens after a timeout. Existing session
  generation protections remain. Restore failures do not display a private profile
  or mark a session authenticated.
- A deadline is not transport cancellation or proof that a write did not reach
  the server. Never blindly retry a timed-out non-idempotent action.

Verification: backend build and TypeScript plus five added backend regression
cases. Nine additional Flutter regression cases are included; GitHub CI is the
verification gate for Flutter here. Prior CI does not cover this new revision.
No production database, merge, deployment, external access change or purchase.
Private-network boundary, two-device synthetic testing and launch gates remain.
