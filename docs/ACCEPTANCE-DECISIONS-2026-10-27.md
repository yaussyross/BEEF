# Full acceptance and decision map — October 27

Boundary: private, access-restricted synthetic adult test. No public launch,
real-user collection, paid provisioning, persistent credentials or destructive
retention changes. “Owner decision” below is consequential approval, not a request
to approve ordinary code, layout, validation, retry or test choices.

## Established requirements — implement without another product decision

| Area | Acceptance requirement | Current state / next engineering action |
|---|---|---|
| Adult gate/auth | Server and DB reject minors; authenticated access enforces current status | Implemented; synthetic integration tested. Self-declared birthdate is not identity/age verification. |
| Profiles | Name/bio/tags/interests editable, validated atomically, moderated | Implemented; rollback/concurrency tests and mobile tests. |
| Discovery/friends | Interest and intent filters work; location stays server-side | Implemented/tested; device acceptance pending. |
| Location/privacy | City/region/exact and hidden distance persist, no public coordinates | Implemented/tested, including concurrent updates. Fictional area selector works. Native foreground acquisition implemented and disabled for synthetic builds. |
| Chat | History, send/read, reconnect, retries and duplicate protection | Implemented; real isolated HTTP/WS and mobile tests. Two-device reconnect/background acceptance pending. |
| Ratings | 1–5 stars, latest vote wins, both people exchange messages spanning >=5 minutes | Approved and implemented/tested. Idle windows and one-sided exchanges do not qualify. Preserve this rule. |
| Block/report | Both-direction access revocation, unblock confirmation, exact-message report, idempotent retries | Implemented/tested. |
| Moderation containment | Urgent queue and targeted message hold; no accusation-only full-account suspension | Approved and implemented/tested; ordinary review cannot release urgent holds. |
| Verification honesty | No unsupported identity/photo/age assurance | Follow-up removes reliance on a legacy `verified` enum and displays unverified. No photo verifier exists. |
| Runtime/waitlist | Explicit env, liveness/readiness, shutdown, durable deduplicated waitlist | Implemented; isolated runtime/DB/API/browser tests. |
| Error UX/accessibility | Loading, retry, retained edits, disabled-account behavior, readable errors | Existing flow tests; further device/screen-reader QA remains engineering work, not a product decision. |
| Brand/build | Bundled fonts, reproducible APK, no-config inert screen | Implemented; 33165ed CI passed 65 tests and APK. Subsequent changes require their own CI. Generated app icon/store screenshots still need final device/artifact inspection. |
| Test artifacts | Synthetic fixtures and two-device acceptance checklist; clear setup-only label | Prepared. Current APK expires Oct 28 19:39 UTC. Library persistence attempted but local transfer denied HTTP403; not delivered durably. |

## Consequential choices and recommended privacy-preserving defaults

| Decision | Recommended default (proposal unless already approved) | Why owner input is needed / independent work |
|---|---|---|
| Public rating visibility | Keep ratings private in closed test; later show aggregates only to authenticated adults after at least five distinct eligible raters; no voter identities or leaderboards | Later instruction explicitly holds public exposure. Owner must approve visibility, threshold and correction/appeal rules. Existing private submission remains fully usable. |
| Rating abuse/appeals | One current vote per eligible pair; protect reporters, rate-limit changes, provide reviewed corrections without revealing raters | Existing one-vote/re-rate rule approved. Thresholds and whether moderation can remove/restore ratings alter reputation policy; owner choice. Do not silently remove ratings. |
| Photo storage/sharing | Private storage, restricted access, no public original URLs; strip metadata, validate/re-encode, quarantine before display | Local validation/adapter tests can be built once supported image formats/stack are established. Provider, persistence, sharing and processing approval required before a working hosted upload. No real photos. |
| Photo verification meaning | Explicitly unverified until a documented photo-match process exists; never imply legal identity, adult status or safety | Owner must choose the attestation and reviewer procedure. No KYC/selfie collection or third-party disclosure by default. Honesty guard is independent implementation. |
| AI image moderation | Fail closed to human review; no image leaves the approved storage boundary without separate approval | Provider, price, data processing and reliable reviewer workflow not established. Stub is not a functioning moderation service. Synthetic metadata tests remain permitted. |
| Profile prompts | Optional, non-sensitive conversation starters; user previews text and can clear it; moderate as profile text | Wording/layout are routine choices. Publishing new profile fields introduces new sharing; confirm audience before persistence/public display. A local-only draft is not a completed shared feature. |
| Consent-friendly lane | Voluntary discovery preference only, off by default; revoke immediately; never represent consent to physical/sexual activity or expose a consent history | Owner must define audience, entry criteria and what opt-in means. This changes sensitive disclosure and cannot be inferred from the feature name. |
| Account recovery | Generic non-enumerating responses, short-lived single-use recovery proof, revoke old sessions after reset | Flow/security implementation is routine. Recovery delivery channel/provider and associated data disclosure/cost need approval. Never restore access based on profile knowledge alone. |
| Account deletion/retention | Explain scope; require reauthentication; hide account promptly after an approved request, then follow explicitly approved retention/evidence rules | Timing, legal evidence holds, backups and irreversible deletion are owner/legal policy. No destructive default implemented. |
| Urgent moderation operations | Metadata-only triage; least-privilege reviewer; preserve restricted evidence; no automatic release or ordinary harmful-media preview | Ross is intended reviewer, but staffing, deadlines, credible-danger criteria, appeals/restoration and specialist escalation are unapproved. No invented operational coverage or external transmission. |
| Push notifications | Off in synthetic test; if added, generic notification text with no message/body/location/reputation content | Delivery requires platform accounts/credentials and third-party data handling approval. In-app unread state already implemented. |
| Analytics/ads | No third-party tracking SDK or location sharing in closed test; collect only operational metrics without message/profile content | Advertising is later phase; provider/data-sharing/business terms and any spend require owner approval. Do not introduce an ad SDK merely to finish the test build. |
| Store/public release | Remain private synthetic until safety, privacy disclosures, age-rating and release review are complete | Legal/store statements and account agreements require owner action. Historical policy assertions are not a current compliance determination. |

## Setup and acceptance gates — separate from product choices

1. Select an existing no-cost-capacity host and database; verify limits before
   provisioning. Approve specific private deployment, synthetic-data persistence,
   cleanup/backup policy and migrations. Use a single server process until shared
   fan-out/revocation exists. No paid resources without explicit approval.
2. Separately approve staging JWT/moderator secret creation and secure storage;
   do not paste credentials in chat. Choose approved reviewer/tester access.
3. Configure TLS and access controls for both HTTP and WebSocket, including
   signup/waitlist; verify unapproved clients cannot reach application surfaces.
   Then exercise backup/restore, monitoring, resource limits and abuse controls.
   These technical controls do not require another product design decision.
4. Build against the approved HTTPS origin, privately deliver to two approved
   devices, run CLOSED-TEST-ACCEPTANCE.md with synthetic fixtures, record exact
   build/device/OS and results. No invitations or real data implied.
5. iOS compilation/signing, physical permission behavior, screen-reader checks,
   store accounts and submissions remain unrun. Account fees require approval;
   no Apple/Google/Firebase account is required to finish local synthetic tests.

The remaining work is not “only approvals”: chosen features still need code,
regression tests, operational setup and device acceptance. Do not label a setup
APK, a schema enum, an integration mock or historical live check a finished product.
