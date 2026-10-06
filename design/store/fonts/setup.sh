#!/bin/bash
set -e
cd /home/team/shared/design/store/fonts
pip install --break-system-packages -q Pillow 2>&1 | tail -1
# Unbounded already downloaded as unbounded.zip
if [ -f unbounded.zip ]; then
  unzip -o -q unbounded.zip -d unbounded_raw || true
  # move the static ttf weights of interest up
  find unbounded_raw -name "*.ttf" -exec cp {} . \; 2>/dev/null || true
  rm -rf unbounded_raw unbounded.zip
fi
# Space Grotesk
curl -sL -o sg.zip "https://fonts.google.com/download?family=Space%20Grotesk" 
unzip -o -q sg.zip -d sg_raw || true
find sg_raw -name "*.ttf" -exec cp {} . \; 2>/dev/null || true
rm -rf sg_raw sg.zip
echo "=== fonts dir ==="
ls -la
python3 -c "import PIL; print('PIL', PIL.__version__)"
