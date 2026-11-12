"""Brand contract: visible names change; auth/package/storage identities do not."""
from pathlib import Path
import os, unittest, subprocess, tempfile, plistlib
ROOT=Path(os.environ.get('BRAND_TEST_ROOT',Path(__file__).resolve().parents[1]))
class BrandTests(unittest.TestCase):
 def test_visible_names(self):
  for path in ['app/lib/app.dart','app/lib/screens/device_location_screen.dart','app/lib/main.dart','app/lib/widgets/beef_wordmark.dart','app/lib/screens/onboarding/age_gate_screen.dart','backend/src/routes/__root.tsx','backend/src/routes/index.tsx','backend/src/routes/api/register.ts']:
   text=(ROOT/path).read_text()
   self.assertIn('Otter Wink',text,path)
   self.assertNotIn('BEEF',text,path)
 def test_no_public_pricing_claims(self):
  text=(ROOT/'backend/src/routes/index.tsx').read_text().lower()
  self.assertNotIn('free',text)
  self.assertNotIn('forever',text)
 def test_stable_identifiers(self):
  self.assertIn('name: beef',(ROOT/'app/pubspec.yaml').read_text())
  self.assertIn('beef.accessToken',(ROOT/'app/lib/api/token_store.dart').read_text())
  self.assertIn('BEEF_API_BASE_URL',(ROOT/'app/lib/config/api_config.dart').read_text())
 def test_platform_display_names(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp); (root/'scripts').mkdir(); script=root/'scripts/configure_platforms.py'
   script.write_text((ROOT/'app/scripts/configure_platforms.py').read_text())
   manifest=root/'android/app/src/main/AndroidManifest.xml'; manifest.parent.mkdir(parents=True)
   manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="beef" /></manifest>')
   plist=root/'ios/Runner/Info.plist'; plist.parent.mkdir(parents=True); plist.write_bytes(plistlib.dumps({}))
   subprocess.run(['python3',str(script)],check=True)
   self.assertIn('Otter Wink',manifest.read_text())
   self.assertEqual(plistlib.loads(plist.read_bytes())['CFBundleDisplayName'],'Otter Wink')
if __name__=='__main__': unittest.main()
