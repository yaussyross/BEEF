#!/bin/bash
set -e
cd /home/team/shared/design/store/fonts
curl -sL -o Unbounded.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/unbounded/Unbounded%5Bwght%5D.ttf"
curl -sL -o SpaceGrotesk.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf"
ls -la
file Unbounded.ttf SpaceGrotesk.ttf
