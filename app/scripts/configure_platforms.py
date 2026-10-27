"""Configure generated platforms; never request background location access."""
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

ANDROID = 'http://schemas.android.com/apk/res/android'
TOOLS = 'http://schemas.android.com/tools'
ET.register_namespace('android', ANDROID)
ET.register_namespace('tools', TOOLS)
root = Path(__file__).resolve().parents[1]
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    tree = ET.parse(manifest)
    node = tree.getroot()
    permissions = {p.get(f'{{{ANDROID}}}name'): p for p in node.findall('uses-permission')}
    # Coarse only; no background or foreground service. Native reading is also
    # disabled by default in Dart until the real-data boundary is approved.
    name = 'android.permission.ACCESS_COARSE_LOCATION'
    if name not in permissions:
        ET.SubElement(node, 'uses-permission', {f'{{{ANDROID}}}name': name})
    for name in ['android.permission.ACCESS_BACKGROUND_LOCATION', 'android.permission.FOREGROUND_SERVICE_LOCATION']:
        permission = permissions.get(name)
        if permission is None:
            permission = ET.SubElement(node, 'uses-permission', {f'{{{ANDROID}}}name': name})
        permission.set(f'{{{TOOLS}}}node', 'remove')
    tree.write(manifest, encoding='utf-8', xml_declaration=True)
plist = root / 'ios/Runner/Info.plist'
if plist.exists():
    with plist.open('rb') as f:
        data = plistlib.load(f)
    data['NSLocationWhenInUseUsageDescription'] = 'BEEF uses a location reading you request to find nearby profiles with your chosen privacy settings.'
    with plist.open('wb') as f:
        plistlib.dump(data, f)
# For Swift Package Manager, builds must set BYPASS_PERMISSION_LOCATION_ALWAYS=1.
# CocoaPods projects apply the equivalent macro in their generated Podfile.
podfile = root / 'ios/Podfile'
if podfile.exists():
    text = podfile.read_text()
    marker = 'flutter_additional_ios_build_settings(target)'
    if 'BYPASS_PERMISSION_LOCATION_ALWAYS=1' not in text:
        if marker not in text:
            raise SystemExit('Cannot safely configure generated Podfile; review its post_install hook.')
        text = text.replace(marker, marker + "\n    if target.name == 'geolocator_apple'\n      target.build_configurations.each do |config|\n        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']\n        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'BYPASS_PERMISSION_LOCATION_ALWAYS=1'\n      end\n    end")
        podfile.write_text(text)
