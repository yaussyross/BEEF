# Otter Wink rebrand — November 12, 2026

Ross requested BEEF renamed to **Otter Wink**, a brand email, a coming-soon page featuring adult male models, and no public prices. This application patch changes visible names, metadata, generated Android/iOS display labels and the launcher icon without changing authentication audiences, storage keys, database IDs, API configuration keys or package identifiers. The existing dark app palette is retained. Historical documents remain historical.

The new original vector wink mark is `design/store/otter-wink-icon.svg`, rendered to the 1024px launcher PNG. Prior icon is retained for history. Public pricing/free-forever copy is removed from the repository landing page. Domain, email and the independent coming-soon page are coordinated separately; no DNS modification is part of this patch.

Local verification: backend production build and TypeScript check; 55 backend tests; four brand/platform configuration checks. New narrow-screen Flutter wordmark tests require latest-head CI. This is not a production release or live-device result.

Remaining real-user release gates include private-stage/runtime verification, live two-device and iOS testing, secure runtime configuration, moderation operational readiness, platform release accounts/signing and production data retention/backups. Existing Render synthetic free database expires November 26, 2026. Do not expose a synthetic demo as a functioning public social app, or treat a static coming-soon site as the app launch.
