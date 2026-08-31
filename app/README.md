# BEEF — Flutter app

The BEEF **Flutter mobile app**. The backend API (auth etc.) is the sibling
TanStack Start app at `../backend` (see `src/routes/api/*`, `src/lib/*`,
`scripts/import-waitlist.ts`); the Postgres schema lives at `../db`.

```
app/
  pubspec.yaml              # Flutter project (name: beef, sdk ^3.5.0)
  analysis_options.yaml     # flutter_lints + const/print rules
  lib/
    main.dart               # entry — wires ApiClient + AuthController + BeefApp
    app.dart                # MaterialApp + AuthGate (splash/onboarding/home)
    config/api_config.dart  # API base URL (--dart-define override)
    theme/                  # BeefColors palette + BeefTheme.dark ThemeData
    api/                    # http client, token store, auth endpoints
    auth/                   # AuthController (ChangeNotifier) + AuthScope
    models/                 # typed DTOs (User, Profile, PublicProfile, ...)
    widgets/                # BeefWordmark, BrandButton
    screens/                # splash, home, onboarding (18+ gate/register/login)
```

## Client architecture (auth slice)

- `lib/api/http_client.dart` — `ApiClient` (JSON, `Authorization: Bearer` header,
  consistent `{ error, message }` → `ApiException` mapping) and automatic
  **refresh-on-401**: a protected call that returns 401 triggers a single token
  rotation via `/api/refresh`, retries once, and clears tokens if refresh fails.
- `lib/api/token_store.dart` — `TokenStore` abstraction over
  `flutter_secure_storage` (iOS Keychain / Android EncryptedSharedPreferences).
- `lib/auth/auth_controller.dart` — `AuthController extends ChangeNotifier`,
  the single source of truth for auth state (`unknown` / `unauthenticated` /
  `authenticated`) with `restore`, `register`, `login`, `signOut`.
- `lib/auth/auth_scope.dart` — `InheritedNotifier` exposing the controller to
  the tree (`AuthScope.of` subscribes; `AuthScope.read` does not).
- Onboarding is a non-Navigator state machine (`OnboardingFlow`) so a completed
  register/login cleanly swaps the whole flow for the home screen.

### Privacy invariants enforced client-side

- The 18+ gate is mandatory and non-skippable; age is checked **client-side**
  before any network call, and the backend re-checks at `/api/register` (plus a
  DB trigger). The birthdate is the user's own entry on their own device — never
  rendered for another user.
- The client never displays another user's precise location or birthdate. The
  backend already strips them (grid returns distance buckets only;
  `/api/profile/:id` returns `is_adult` + `age_bucket`); the client models
  mirror that and do not re-add raw values.

## Flutter SDK — where it lives

The Flutter SDK is **not installed** in this sandbox yet. The official
`flutter_linux_3.47.2-stable.tar.xz` (sha256 verified) was downloaded to
`/opt/flutter` but the extraction **fails reproducibly** on this sandbox's
overlay filesystem at `flutter/engine/src/...` ("Directory renamed before its
status could be extracted"), and the 2.48 GB unpacked SDK does not fit alongside
the sandbox's 3.1 GB `/` budget without OOM-killing the extractor.

**When a larger-disk environment (or CI) is available**, install to `/opt/flutter`
(documented path) and complete the platform scaffold:

```bash
# 1. Install Flutter to /opt/flutter and put /opt/flutter/bin on PATH.

# 2. Generate the Android/iOS platform folders (fills in gradle/xcodeproj):
cd app
flutter create . --org com.beef --project-name beef --platforms android,ios

# 3. Fetch dependencies (http, flutter_secure_storage, web_socket_channel):
flutter pub get

# 4. Static analysis — must be clean before CI passes:
flutter analyze

# 5. Build/run for verification:
flutter run            # a connected device/emulator
flutter build appbundle  # Android release
flutter build ipa        # iOS release (needs signing on a Mac)
```

`flutter create .` preserves the existing `pubspec.yaml` / `lib/` /
`analysis_options.yaml` (it only adds missing platform files); re-apply them if
an older toolchain overwrites them.

### API base URL

The backend API is served by the same host as the BEEF site. The default is
compiled into `lib/config/api_config.dart`; override per environment at build
time:

```bash
flutter build ... --dart-define=BEEF_API_BASE_URL=https://your-host
```

### Package identifiers (original — NOT Grindr-like)

- Android applicationId: `com.beef.app`
- iOS bundle id: `app.beef`

Set after `flutter create`:
- Android `android/app/build.gradle.kts` → `minSdk = 24` (see also
  `flutter.minSdkVersion` default), `applicationId = "com.beef.app"`.
- iOS `ios/Runner.xcodeproj` → deployment target **13.0**, bundle id `app.beef`.

### Dependency rationale (pubspec.yaml)

| Package | Version | Why |
|---------|---------|-----|
| `http` | `^1.2.2` | REST client for the `lib/api/` layer (register/login/refresh/me). |
| `flutter_secure_storage` | `^9.2.2` | Secure token storage; access + refresh JWTs never touch shared prefs. |
| `web_socket_channel` | `^3.0.1` | 1:1 chat WebSocket (`/api/ws`) — pinned now, consumed by the chat slice. |

All three require Dart `>=3.3.0`, compatible with the `sdk: ^3.5.0` floor.
`flutter_secure_storage` requires Flutter `>=3.22` (the 3.47.2 toolchain
satisfies this).

## Database schema

The schema lives at the repo root in `../db` (migrations + runners). See
`../db/migrations/README.md` for the full table list, privacy invariants, and
run instructions. Migrations are idempotent and also tracked by a
`schema_migrations` version table when applied via `../db/migrate.sh` (or
`bun ../db/migrate.ts` from the app dir).

Requires `postgis` + `citext` extensions (both supported on Neon).
