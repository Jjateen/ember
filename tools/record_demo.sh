#!/usr/bin/env bash
# Record a full walkthrough of every destination.
#
# screenrecord caps each clip at 180 s, so this chains fixed-length segments on
# the device and stitches them afterwards. SIGINT is what makes screenrecord
# finalise the container; killing it any other way leaves an unplayable file.
set -uo pipefail

PKG=dev.jjateen.ember
OUT=${1:-demo}
SEG=170
SEGMENTS=4
MIN_BYTES=600000

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "== resetting app state =="
adb shell pm clear "$PKG" >/dev/null
adb shell pm grant "$PKG" android.permission.ACCESS_FINE_LOCATION
adb shell pm grant "$PKG" android.permission.ACCESS_COARSE_LOCATION
adb shell rm -f /sdcard/seg_*.mp4 >/dev/null 2>&1

adb emu geo fix 72.8382547 19.1718491 >/dev/null 2>&1
adb shell am start -n "$PKG/.MainActivity" >/dev/null
sleep 10

echo "== recording =="
adb shell "for i in \$(seq 1 $SEGMENTS); do screenrecord --time-limit $SEG --bit-rate 8000000 /sdcard/seg_\$i.mp4; done" &
recorder=$!
sleep 2

python3 "$here/demo_walk.py" "${@:2}"
walk=$?

sleep 2
adb shell pkill -INT screenrecord >/dev/null 2>&1
wait $recorder 2>/dev/null
sleep 3

echo "== stitching =="
list="$work/list.txt"; : > "$list"
for f in $(adb shell ls /sdcard/seg_*.mp4 2>/dev/null | tr -d '\r' | sort -V); do
  base=$(basename "$f")
  adb pull "$f" "$work/$base" >/dev/null 2>&1
  bytes=$(stat -c%s "$work/$base" 2>/dev/null || echo 0)
  if [ "$bytes" -ge "$MIN_BYTES" ] && ffprobe -v error "$work/$base" >/dev/null 2>&1; then
    echo "file '$work/$base'" >> "$list"
    printf '  %s  %s\n' "$base" "$(du -h "$work/$base" | cut -f1)"
  else
    echo "  $base  skipped (${bytes}B, below threshold)"
  fi
done

if [ ! -s "$list" ]; then echo "no usable segments"; exit 1; fi
ffmpeg -y -v error -f concat -safe 0 -i "$list" \
  -vf "fps=24,scale=540:-2" -c:v libx264 -preset veryfast -crf 26 -pix_fmt yuv420p \
  "$OUT.mp4"
adb shell rm -f /sdcard/seg_*.mp4 >/dev/null 2>&1

echo "== done =="
ffprobe -v error -show_entries format=duration,size -of default=nw=1 "$OUT.mp4"
echo "walk exit: $walk"
