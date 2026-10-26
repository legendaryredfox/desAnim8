#!/bin/sh
# Re-records docs/showcase.gif from examples/showcase. Needs love, xvfb-run and ffmpeg.
# Run from the repository root:  sh tools/record-gif.sh
set -e
SAVE="$HOME/.local/share/love/desanim8-showcase"
rm -f "$SAVE"/rec_*.png
DESANIM8_DEMO_RECORD=rec xvfb-run -a -s "-screen 0 640x360x24" love examples/showcase
ffmpeg -loglevel error -y -framerate 30 -i "$SAVE/rec_%04d.png" \
    -vf "fps=15,scale=480:-1:flags=neighbor,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=none" \
    docs/showcase.gif
rm -f "$SAVE"/rec_*.png
