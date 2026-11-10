# Chat read fallback

Continues `review/private-controls-2026-10-26`, which already contains native
chat, safety/privacy controls and private ratings. This is an incremental change,
not a replacement for that work or a public-release declaration.

## Behavior

- `POST /api/threads/:id/read` is the authenticated REST equivalent of the
  existing WebSocket read frame. It shares `markThreadRead`, including active
  account, membership, active-peer and both-direction block checks.
- A foreground Flutter conversation marks its history read after successful
  hydration even when WebSocket is unavailable. A failed socket write also falls
  back to REST. Reading does not require another outgoing chat message.
- Concurrent REST reads for the same thread coalesce. Transient failures retry on
  the next successful history refresh. Failed/background hydration does not mark
  read. Stale read failures cannot invalidate a newer conversation.
- The existing server read semantics remain unchanged: acknowledge through server
  processing time, not a per-message watermark. Per-message read receipts and
  multi-process fan-out are separate future work.

## Validation

Backend production build and TypeScript check passed. Backend regression suite:
50 tests passed, including four new REST read authorization/state tests.

The disposable real PostgreSQL suite has new unread-count/idempotency checks but
could not run in this workspace: Docker is not installed. No live database was
used. Ten new Flutter regression tests were added, but neither Flutter analyze
nor Flutter tests completed. SDK bootstrap was stopped by the environment's
network security review before validation; no successful Flutter result is
claimed. Dart formatting and JavaScript syntax checks passed. Run the pinned
Flutter 3.47.2 CI workflow before review or release.

No merge, deployment, provider provisioning or public launch is part of this
change. Existing two-device and signed iOS/Android acceptance gates still apply.
