# Ember — knowledge transfer

Everything needed to pick this project up, including the environment, the
decisions and why they were made, and the bugs already paid for.

---

## 1. What it is

A walk-and-unlock map game used to survey a neighbourhood on foot. Six surveyed
places sit on a satellite map. Walk within 25 m of one, hold position for
fifteen seconds, and it ignites: a named token is awarded and the route walked
is drawn behind you.

No backend, no accounts, no analytics. Progress lives on the device. Builds are
distributed as signed APKs outside any app store.

Repo: `github.com/Jjateen/ember` · Releases carry the APK and a demo video.

---

## 2. Where things live

```
~/personal/flutter_ws/ember/     the app (this repo)
~/personal/flutter_ws/tokens/    Rhino source models, one per place
~/personal/keystores/            release signing key  <- irreplaceable
```

Everything else was tooling installed outside `~/personal` and has been removed
to reclaim disk. Section 3 rebuilds it.

---

## 3. Rebuilding the environment

Roughly 20 GB and about an hour, mostly downloads.

### Flutter

```bash
mkdir -p ~/development && cd ~/development
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz
tar xf flutter_linux_3.47.2-stable.tar.xz && rm flutter_linux_3.47.2-stable.tar.xz
```

Built against **Flutter 3.47.2 / Dart 3.13.2**.

### A real JDK

**The system Java is a JRE with no compiler.** `java-17`, `java-21` and
`java-25` under `/usr/lib/jvm` all lack `javac`, and Gradle fails with
*"does not provide the required capabilities: [JAVA_COMPILER]"*. Install a JDK:

```bash
cd ~/development
curl -L -o jdk21.tar.gz "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse"
tar xzf jdk21.tar.gz && rm jdk21.tar.gz
```

### Android SDK

```bash
cd ~/development
curl -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
mkdir -p ~/Android/Sdk/cmdline-tools
unzip -q cmdline-tools.zip -d ~/Android/Sdk/cmdline-tools
mv ~/Android/Sdk/cmdline-tools/cmdline-tools ~/Android/Sdk/cmdline-tools/latest

export ANDROID_HOME=~/Android/Sdk
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" \
           "emulator" "system-images;android-35;google_apis;x86_64"
```

`sdkmanager` runs fine on Java 25; only Gradle needs the real JDK.

### Shell profile

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export JAVA_HOME="$HOME/development/jdk-21.0.12.1+1"
```

Then point the toolchain at them:

```bash
flutter config --android-sdk "$ANDROID_HOME"
flutter config --jdk-dir "$JAVA_HOME"
```

`android/gradle.properties` also carries `org.gradle.java.home`, which must be
updated if the JDK path changes.

### Emulator

```bash
avdmanager create avd -n ember -k "system-images;android-35;google_apis;x86_64" -d pixel_7
emulator -avd ember -no-boot-anim -gpu swiftshader_indirect
```

**Use `-gpu swiftshader_indirect`.** `-gpu host` worked initially and later
began failing with *"Your GPU cannot be used for hardware rendering"* followed
by a hung QEMU main loop. Software rendering is slower to boot but stable.

Other emulator lessons paid for the hard way:

- A hard-killed emulator leaves `*.lock` files in `~/.android/avd/ember.avd`
  that block the next start. Delete them.
- It gets OOM-killed on a loaded machine. `-memory 2048` helps.
- If it dies mid-script, `adb emu geo fix` silently succeeds against nothing, so
  a driving script reports success while doing nothing. `tools/record_demo.sh`
  guards against this.

---

## 4. The keystore — read this first

`~/personal/keystores/ember-release.jks` signs every release build. Its
credentials are in `android/key.properties`, which is gitignored, as is the key
itself.

**If it is lost, every tester must uninstall before they can take another
build**, because Android refuses to update an app whose signature changed.
There is no recovery. Back it up somewhere other than this machine.

Without `key.properties` the build falls back to debug keys. That still
installs, but produces the same update problem later.

---

## 5. Architecture

Full diagrams: `docs/arch_layers.png`, `docs/arch_flow.png` (regenerate with
`docs/gen_layers.py` and `docs/gen_flow.py`).

```
lib/
  domain/   models.dart, proximity.dart   pure Dart, no Flutter or plugin imports
  data/     location_service.dart, repositories.dart
  ui/       game_controller.dart, map_screen.dart, tray_screen.dart,
            ignition_screen.dart
  theme/    ember_theme.dart
```

Dependencies point downward only. `domain/` holds the game rules as plain
functions, which is why they are covered by unit tests with no device involved.
`GameController` is the one app-scoped `ChangeNotifier`; it owns the location
subscription, the dwell timer and the unlock.

The layering follows Flutter's official architecture guidance, minus the layers
that would hold nothing at this size: no use-case classes, no DTO mapping, no
router.

---

## 6. Decisions, and the reasoning behind them

**Unlock radius 25 m.** The two closest places are 39 m apart, so anything at
or above that would award two tokens from one spot. It is a squeeze, not a free
win: urban GPS runs 7–13 m and worse with a blocked sky view, so the radius sits
near the noise floor.

**Dwell of 15 s.** A bare radius flickers as GPS drifts. Requiring the player to
stay inside makes a radius this tight workable, and incidentally filters
drive-bys and makes spoofing cost real time.

**Accuracy gate of 40 m, separate from the radius.** Gating at the radius meant
nothing ever unlocked on a real phone. The dwell is the real filter; this only
excludes garbage. See §7.

**`flutter_map` over OpenStreetMap and Esri, not Google Maps.** Google's mobile
map SKU is genuinely free and unlimited, but issuing a key still requires
attaching a billing account. A side benefit: markers become ordinary Flutter
widgets rather than bitmaps crossing a platform channel, which sidesteps a known
performance trap where `google_maps_flutter` re-diffs the entire marker set on
any change.

**Zoom ceiling.** Esri serves this area to zoom 19, about 28 cm per pixel, and
returns blank placeholder tiles above it. Past that the layer upscales. Setting
`MAPBOX_TOKEN` at build time swaps in imagery with native tiles to zoom 22 and
raises the ceiling to match.

**No background location.** Foreground-only avoids the platform's background
restrictions entirely, and the app is honest about it in the permission screen.

---

## 7. Bugs already paid for

Keep these in mind before changing the location path; each was found on a real
device or in a real recording.

**"Waiting for a location fix" forever.** Three faults compounding: the stream
carries a 5 m distance filter so a stationary phone emits almost nothing; the
first three fixes were discarded as cold-start noise, which a stationary user
never got past; and every fix was dropped unless accuracy beat 25 m, which
phones routinely fail indoors. Underneath was one design error — a single check
gated both *showing a position* and *awarding a token*. They are now separate:
`isPlausible` decides what may be drawn, `isPreciseEnough` decides what may
unlock. Startup also seeds from the last known position rather than waiting for
movement.

**Panel went blank after an unlock.** Igniting cleared the proximity result, and
the next fix that would have recomputed it never arrives while standing still.
It now recomputes from the position already held.

**Map vanished when zoomed in.** The tile layers had both `maxNativeZoom` and
`maxZoom`. The first upscales past the deepest tiles that exist; the second
hides the layer entirely above it. Only the first belongs there.

**Sixteen ignition screens stacked up.** Every unlock pushed a new route, so a
run of quick unlocks buried the map. It now clears itself after 3.6 s and a
guard prevents a second being pushed while one is showing.

**Video jumped backwards in time.** An interrupted recording left `screenrecord`
alive on the device; the next run's loop wrote the same segment filenames
concurrently and the two interleaved. The script now kills stale recorders
first.

**Wrong token could be awarded.** `evaluate` returned in-radius places in list
order, so a caller taking the first could unlock whichever happened to be listed
first. It now sorts by distance.

---

## 8. Tooling

All under `tools/`, all re-runnable.

| Script | Purpose |
|---|---|
| `gen_token_art.py` | Renders token sprites from the Rhino models |
| `gen_icon.py` | Draws the launcher icon at every mipmap density |
| `demo_walk.py` | Drives emulator GPS through every place |
| `record_demo.sh` | Records a walkthrough and stitches it to mp4 |

### Token art

```bash
python3 -m venv .venv-3dm && .venv-3dm/bin/pip install rhino3dm pillow numpy
.venv-3dm/bin/python tools/gen_token_art.py ../tokens
```

One `.3dm` per place, mapped by filename in `MODEL_FOR`. Flutter cannot draw
Rhino files and a 3D engine would be a heavy dependency for six small pictures,
so each is rasterised once to a flat-shaded sprite, lit and cold.

The camera is fixed looking from the north-east, so a model whose front faces
away renders showing its back. `ROTATE_DEG` applies a per-model yaw; the
Detective Agency needs 90°.

### Demo recording

```bash
bash tools/record_demo.sh demo     # SPEEDUP=6 by default
```

Walks every place at 1 m/s so the app sees a believable GPS cadence, then speeds
the recording up. About nine minutes of walking yields ninety seconds of video.
`screenrecord` caps each clip at 180 s, hence the segment chaining.

The route is a Catmull-Rom curve through the surveyed points, not straight
lines. Real road routing was tried and rejected: the lanes are not in
OpenStreetMap, and OSRM detours over a kilometre around a seventy-metre gap.

---

## 9. Releasing

```bash
flutter test
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk dist/ember-vX.Y.Z.apk

GH_CONFIG_DIR=~/.config/gh-jj gh release upload v0.1.0 dist/ember-v0.1.0.apk --clobber
```

`GH_CONFIG_DIR=~/.config/gh-jj` is required on every `gh` call; the default
config points at a different account.

Bump `version:` in `pubspec.yaml` for each build. Patches to an existing test
build have so far been shipped by bumping the build number and re-uploading to
the same release, so testers are not split across tags.

---

## 10. Open questions

**Lane-level detail.** Not reachable from free sources. Esri imagery stops at
zoom 19 here; Esri's Clarity and Wayback services need authentication; and OSM,
CARTO and Esri Street all return blank tiles for the settlement interior because
the lanes are mapped nowhere. Sharper imagery means Mapbox (a token, free to
25k monthly users) or Google (a key plus a billing account).

**Radius.** 25 m works and keeps the closest pair distinct. A request to tighten
it to 5 m was raised and held: phones do not report accuracy anywhere near that,
so it would unlock nothing. About 15 m is the practical floor.

**Coordinates.** The six places were surveyed rather than generated, but any
that sit awkwardly should be corrected in `assets/destinations.json` after
walking them.

**Trails as lane data.** Every walk records a real path through real lanes.
Persisting and accumulating those would build a lane map that no basemap has.
Currently the trail is in memory only and resets with progress.
