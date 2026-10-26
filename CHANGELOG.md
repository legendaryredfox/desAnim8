# Changelog

## 0.10.0 (unreleased)

### Added
- Queries: `getCurrentFrameNumber`, `getRemainingTime`, `getPhase`/`setPhase`, `getLoopCount`, `isFinished`, `getFrameProgress`.
- SpriteBatch: `addToBatch`, `setInBatch`. Constructor: `newAnimationFromQuads`, `newGridFromImage`.
- Grid: `inset` argument, `Grid:clearCache`, quad cache for identical calls, `desAnim8.maxImageSize` advisory warning.
- Time engine: `setSpeed`/`getSpeed` (negative plays backwards), `fitDuration`, `freeze`, `setStep`, `setEasing`, `randomizeStart`, `wait`, `tick`, `desAnim8.setTimeScale`/`getTimeScale`.
- Loop ranges: `setLoopRange`, `clearLoopRange`, `release`.
- Events: `onFrame`/`offFrame`, `addMarker`/`clearMarkers`, `onStart` and `onEnd` fields.
- Runtime changes: `setPlayMode`, `setDurations`.
- Constructor `opts` (fifth argument): `ticks`, `weights`, `jitter`, `rng`, `randomLength`, `data`; new `'random'` play mode.
- Per-frame data: `getFrameData`, `getWorldRect`, `setAutoPivot`, trim offsets and keyframe `transform` data with `setInterpolation`.
- Atlases: `newFramesFromRecords`, `atlas.fromTexturePacker`, `atlas.fromStarling`, `atlas.fromAseprite`.
- Aseprite: `newFromAseprite` (tags, directions, slices as frame data) and `newSetFromAseprite`.
- Sheet tools: `scanBounds`, `dataFromLists`, `sliceByAlpha`, `newQuadsFromRects`.
- Render style: `setColor`, `setAlpha`, `setBlendMode`, `setShader`, `flash`, `faceTowards`, `setDefaultFacing`, `setPixelSnap`, `setTrail`/`getTrail`, `setOnion`, `desAnim8.shaders` (GLSL sources).
- Debugging: `drawBounds`, `desAnim8.debug.drawTimeline`, `desAnim8.debug.scrub`.
- Composition: `newSet` (named clips with `play`, `queue`, `setNext`, `keepPhase`), `newComposite` (layers on one clock), `newBatch` (many entries, one SpriteBatch), `newWatcher`.
- `getState`/`setState` for saving and restoring playback.
- `examples/aseprite`: the Aseprite importer end to end, with a minimal JSON decoder and an export that includes tags and slices.
- `docs/showcase.gif` in the README, recorded from the example by `tools/record-gif.sh` (the example has a scripted recording mode).
- LuaCATS annotations, a rockspec, `.luacheckrc`, `examples/showcase`, `tests/bench.lua`, and the README in Brazilian Portuguese and English.

### Fixed
- `setPlayMode` and `setDurations` left `currentFrame` out of step with the timer while an easing or `setStep` was active, so the frame jumped on the next `update`. `gotoFrame` also honours `setStep` now.

### Changed
- The library is split into modules under `desAnim8/` behind a thin `desAnim8.lua` entry; `require 'desAnim8'` is unchanged. `lua tools/bundle.lua` builds the single-file `dist/desAnim8.lua` for consoles, and CI keeps it current and tested.
- `resume()` on a looping animation parked by `pauseAtEnd` starts over instead of refiring `onLoop`.
- Hooks run after the frame is updated, so `onLoop` sees the new `currentFrame`.
- `getFrameInfo` applies trim and transform data; its flip math is unchanged for plain animations.
- Supported runtimes: LuaJIT 2.1 and Lua 5.1 through 5.5; CI covers luajit, 5.1, 5.4 and 5.5.
- `update` has a shortcut for plain forward playback, so it costs about the same as in 0.5.0 despite the new features.

## 0.5.0

### Fixed
- `flipH`/`flipV` no longer break uniform scale: an omitted `sy` follows `sx`, as in `love.graphics.draw`.
- Grid column and row counts now account for `left`, `top` and `border`; frames outside the sheet are rejected.
- `onLoop` set to an unknown method name raises a clear error instead of `attempt to call a string value`.
- `update` ignores `dt <= 0`, `NaN` and infinity (a bad `dt` used to rewind the animation or freeze it for good).
- `desAnim8.new(frames, durations)` (anim8 style, no image) and incomplete legacy calls raise a usage error that points to `newAnimation`.
- Duplicate range keys in a durations table are rejected instead of depending on `pairs` order.
- Non-integer frame and range numbers are rejected by `Grid` and `gotoFrame`.
- `resume` on a finished `once`/`bounceOnce` animation no longer fires `onLoop` again.
- The frame list is copied at construction.
- Instances no longer inherit the module table (`anim.new`, `anim._VERSION`, ...).
- Errors are reported at the caller's line instead of inside the library.
- The embedded license notice names the copyright holder.

### Added
- `setFlipH(bool)`, `setFlipV(bool)`, `getFrameCount()`, `getDuration()`, `getPlayMode()`.
- `draw` raises a clear error when called with the wrong argument shape for bound or image-less animations.
- Unknown play mode errors list the valid modes and hint at `onLoop`.
- Test suite: `tests/run.lua` (unit, mocked LÖVE) and `tests/smoke` (real LÖVE).

### Docs
- README: heading hierarchy, play mode table, fields table, notes on `pauseAtEnd` per mode, updated anim8 migration table, pixel-art filter in Quick start.
