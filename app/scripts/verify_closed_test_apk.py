"""Offline inspection only: no calls to the configured endpoint."""
import hashlib
import json
from pathlib import Path
import zipfile

apk = Path('build/app/outputs/flutter-apk/app-debug.apk')
origin = 'https://beef-synthetic-staging.onrender.com'
with zipfile.ZipFile(apk) as archive:
    kernels = [n for n in archive.namelist() if n.endswith('/kernel_blob.bin')]
    if len(kernels) != 1 or origin.encode() not in archive.read(kernels[0]):
        raise SystemExit('Pinned origin not found in compiled Dart kernel')
    kernel = archive.read(kernels[0])
    for forbidden in [b'JWT_SECRET', b'MODERATION_ADMIN_KEY', b'BEEF_CLOSED_TEST_SETUP_KEY', b'postgres://', b'postgresql://']:
        if forbidden in kernel:
            raise SystemExit('Unexpected server configuration in compiled app')
report = {'origin': origin, 'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
          'compiled_origin_verified': True, 'device_location_enabled': False,
          'device_tested': False, 'hosted_acceptance_completed': False,
          'credentials_injected': False}
Path('build/closed-test-build-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS compiled APK origin inspection; no server configuration or credentials injected')
