# Owner-run setup and external acceptance

The app is a synthetic closed test, not a production launch. The configured debug
APK points only to `https://beef-synthetic-staging.onrender.com`, has device GPS
disabled and contains no server/setup/database credentials. CI verifies its
compiled origin offline. Check the exact-head runtime evidence separately: an
emulator pass does not establish hosted or physical-device acceptance. CI artifacts inherit the
public repository's artifact access rules: this is a build for restricted staging,
not a confidential binary. The backend access controls are the security boundary.

## Minimum secure setup step (Ross's own computer)

Use the exact reviewed commit from the handoff. Python 3 is sufficient; no paid
service, Render API key or new provider account is needed. This script must run
only from your own permitted network, not the restricted agent workspace or CI.
The WSS handshake requires ordinary direct HTTPS access on your computer; it does
not configure a tunnel/proxy or change network restrictions. Stop if your network
blocks the host.

1. In the existing Render service's **Environment** page, add
   `BEEF_CLOSED_TEST_SETUP_KEY` using a fresh 32–64 character random value generated
   and stored privately in your password manager. Do not paste it into chat,
   source files, shell arguments, screenshots or a shared terminal. Save the
   setting and wait for the single resulting deploy to become Live.
2. In a normal interactive terminal in your checked-out BEEF repository, run:

   ```sh
   python3 scripts/closed_test_acceptance.py --setup
   ```

   Enter the setup key and two distinct strong passwords through the hidden
   prompts. Store the passwords privately as Fixture 1 and Fixture 2. The script
   uses only the existing adult-A/adult-B `example.test` identities; no mail is
   sent. Existing accounts are never reset: wrong credentials stop the script.
3. **Remove `BEEF_CLOSED_TEST_SETUP_KEY` from Render Environment immediately after
   the script finishes, even on failure.** Save and wait for that single deploy.
   Registration is then disabled again. The fixture passwords remain unchanged.
4. Run the same script **without `--setup`** to verify login and chat after setup
   has been disabled. Send back only the PASS/stop summary, never credentials or
   response contents. If a check fails, stop; do not change allowlists, reset
   accounts or enable public registration to force success.

The script checks readiness, hidden landing, anonymous HTTP and WSS rejection,
outsider rejection, fixture login, authenticated WSS handshake, two-way REST chat
and message retry idempotency. It writes two clearly synthetic messages per run.
Tokens and passwords stay in process memory; no credential file or report dump
is written. Redirects are rejected before credentials can be forwarded. No raw
error/response body is logged. Do not enable HTTP debugging or record the terminal.
There is no secure-channel blocker if you have your existing Render dashboard,
password manager and a normal private terminal. If those are unavailable, stop;
we cannot safely substitute chat for credential delivery.

## Android runtime and browser preview

No Android hardware purchase is required. The review CI attempts an accelerated
Android API 35 emulator with its network disabled before app launch. It installs
the actual configured APK built in that job, checks launch/background/resume, and
then tests the same chat screens using controlled synthetic fixtures plus the
Android secure-storage plugin. The runtime evidence artifact contains screenshots
and `RESULT.txt` only when the complete runtime suite passes. A failed/skipped CI
step is not a runtime pass. These offline checks do not contact staging.

CI also builds a separate offline browser preview with synthetic chat and the
adult gate. It has no real login, registration or backend connection. Its bundle
is not deployed and has not been validated in iPhone Safari; it is not a native
iOS build. Do not treat the staging root URL as this preview.

If approved Android devices later become available, the remaining physical-device
step is:

Download the separately named configured closed-test APK from the verified CI run
and compare its SHA256 with `closed-test-build-verification.json` in the artifact.
Install on two approved Android test devices, then log in using Fixture 1
and Fixture 2. Run `CLOSED-TEST-ACCEPTANCE.md`. The root web URL intentionally has
no landing page; it is not a browser-based version of the Flutter app.

The script is a smoke test, not complete acceptance. Two-device background and
reconnect behavior, five-minute rating eligibility, privacy, block/report and
metadata-only review still need recording. Reviewer/admin setup is separate;
the setup key is not a moderator key and must never be embedded in the APK.
iOS signing and device validation remain unrun.

Database expiry: November 26, 2026 at 21:24:58 UTC. Review by November 19. No paid
extension or automatic deletion/export is authorized by these instructions.
