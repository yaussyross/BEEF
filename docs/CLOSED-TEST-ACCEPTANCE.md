# Closed synthetic test — pending setup approvals

Owner selected a closed test on October 26, 2026. Only the owner and explicitly
approved testers may access it, using synthetic accounts/content. Ross is the
intended reviewer; no live admin access, operational availability, credentials,
invites or external-report transmission has been granted or established.

Fixture specification: `testing/closed-test-fixtures.json`. No media is included;
all reports contain neutral synthetic markers. Do not use real names, addresses,
sexual/personal information or harmful material. This is a preparation file, not
a seed applied to a host. The isolated integration suite creates its own matching
synthetic scenarios and destroys them after testing.

## Setup prerequisites

- Explicitly approved host/database with verified free or already-authorized
  capacity, private access controls covering HTTP and WebSocket, and no open
  signup/waitlist surface reachable by unapproved visitors. Configure those
  controls for the selected host; current source is not itself an invite gate.
- Approval for staging-only secret creation/storage and synthetic-data persistence,
  retention/cleanup and backups. A new account, OAuth permission, public endpoint
  or live migration is not authorized by the closed-test choice.
- Apply reviewed migrations to the approved synthetic database; build an APK with
  its actual `BEEF_API_BASE_URL`. Approve a private artifact-delivery route and
  two devices/testers. Existing public-repo CI does not upload the APK.
- Specify the specialized severe-report review/release process, reviewer identity
  auditing, decisions, deadlines and escalation. Current ordinary review returns
  409 for urgent reports/held content; no automatic release is implemented.

## Two-device acceptance record

Record commit/build hash, configured endpoint, tester/device/OS, expected/actual
result and sanitized evidence for every row. Use device A as Fixture A and device
B as Fixture B; Fixture C is an authorization-only outsider. Ross checks metadata
only. Never display or upload suspected illegal material as test evidence.

| Scenario | Required result |
|---|---|
| Access boundary | Unapproved device/session cannot reach the staging service, signup or WebSocket; approved devices can authenticate. |
| Chat lifecycle | Both directions send/receive/read; background/resume and reconnect hydrate without duplication. |
| Lost acknowledgement | Network interruption then retry yields one message with the same client ID. |
| Ratings | Both participants exchange messages spanning less than five minutes: locked. At least five minutes: eligible. Idle window/one-sided messages remain ineligible. Re-rating replaces the prior vote. |
| Block | Block while socket disconnected; local thread/history disappears; both-direction API/chat access fails. |
| Privacy | City/region/exact and hide-distance settings persist; public payloads contain no coordinates, birthdate or email. |
| Report retry | Interrupt response and retry same request: one report/queue/evidence set; changed details with same key rejected. |
| Specific severe report | Neutral identified message becomes unreadable in history/inbox/duplicate sends; connected cached copy clears; other messages/account remain usable. |
| Account/thread-only allegation | Urgent queue item; no blanket suspension, profile hiding or conversation restriction. |
| Metadata review | Ross sees IDs, category, urgency and hold state only—no body, reason text, photo key, URL or evidence preview. Unauthorized caller gets no queue. |
| Restoration guard | Ordinary approve/reject/blur/ban cannot resolve urgent/held items; another normal queue cannot release the held message. No repeat report undoes later review state. |
| Status revocation | Independently applied test suspension/ban blocks existing tokens/socket actions; this does not come from an allegation. |
| Runtime outage | Database down: liveness 200, readiness 503; waitlist has no false success; recovery permits a single durable retry. |
| Shutdown | Stop service gracefully, sockets close, restart restores saved synthetic state. |
| Cleanup | Approved teardown deletes synthetic accounts, reports/evidence and staging secrets according to agreed scope; verify no real data entered. |

## Known limits to test explicitly

Already delivered content cannot be recalled from screenshots or offline devices.
Containment notifications are process-local; reconnect/hydration enforces stored
status. The added client guard prevents a late approved event from restoring a
message after that device received containment, but it is not a distributed
atomic cancellation guarantee. Report idempotency is screen-scoped on the client.
No photo-specific reporting/review UI or specialized evidence viewer is added.
No real-user launch follows from this test passing.
