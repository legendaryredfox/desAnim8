# AGENTS.md

desAnim8: single-file sprite animation library for **LÖVE 11.5**, the latest release (inspired by kikito/anim8). Frames are LÖVE Quads drawn with `love.graphics.draw`. Files: `desAnim8.lua` (the whole library, returns a module table), `README.md`, `LICENSE`.

## Rules

- One file only; `require` nothing; LÖVE 11.5 API only (`love.graphics.draw`, `love.graphics.newQuad`). Never reintroduce `image.blit`. Prefer calls that survive LÖVE 12 (`love.filesystem.getInfo` over `getLastModified`; do not test for the `Image` class); scanners take an `ImageData` from the caller.
- **Runs on LuaJIT 2.1 (latest rolling) / Lua 5.1 (LÖVE, console wrappers) and on Lua 5.2 to 5.5.** Write the common subset: no `//`, `&`, `|`, `<<`, `>>`, `<const>`, `<close>`, `goto`, `math.type`; no `unpack`, `setfenv`, `loadstring`, `table.getn`, `math.pow`; never name an identifier `global` (reserved in 5.5); never assign to a `for` control variable (error in 5.5); do not `%d`-format a number that may be fractional (error in 5.3+); do not rely on `tostring(2.0)` ("2" on 5.1, "2.0" on 5.3+). Tests must pass on `luajit`, `lua5.1`, `lua5.4` and `lua` (5.5).
- Keep the legacy constructor working.
- Comments only for non-obvious why.
- Internal fields start with `_` (`_seq`, `_intervals`, `_timer`, `_position`, `_durations`, `_totalDuration`, `_speed`, `_wrapStart`/`_wrapEnd`, `_data`, `_trim`, `_transforms`, ...); never document them as public.
- `frames`, `_durations`, `_seq`, `_intervals` are never mutated in place (`clone()` shares them); `setPlayMode`/`setDurations`/`setState` (random) assign fresh tables. Per-instance mutable tables (`_onFrame`, `_markers`, `_color`, `_trail`) must be copied in `clone()`.
- Commits: author `git commit --author="Legendary Redfox <legendaryredfox.dev@gmail.com>"`; no AI trailers or attribution anywhere; branch first (never commit on the default branch); Conventional Commits.
- No em dashes in prose, docs, comments, or commits.
- Test-first for behavior changes (suite: `tests/run.lua`). Roadmap and item IDs live in `FIX_PLAN.md` (v2).
- Aseprite import and caching are done (FIX_PLAN D3.4/D2.5, based on `josh-perry/peachy` and `tarhses/nim.lua`). Keep imports dependency-free (a predecoded table or a decoder callback) so they run on console targets. Features that need more than `newQuad`/`draw` (shaders, ImageData, SpriteBatch, filesystem, push/pop) stay optional and never touch `love` at `require` time.
- `desAnim8.lua` is past 2500 lines: FIX_PLAN decision 1 says to move optional parts into `desAnim8_extras.lua` if it grows more. Do that only with the owner's go-ahead (it lifts the one-file rule).
- Hot path: `Animation:update` is benchmarked by `tests/bench.lua`; keep it allocation-free.
- README is bilingual on one page, Brazilian Portuguese first, then English. Edit both halves together.

## Internals

- `Grid` (local class) builds Quad lists; stores `imageWidth`/`imageHeight` for `newQuad`.
- Helpers (local): `assertPositiveInteger`, `parseRange` (number or `"n-m"` -> `from, to, step`, no table alloc), `parseDurations`, `buildIntervals` (cumulative times), `buildSequence` (play mode -> frame index list), `initTiming`, `seekIndex` (binary search).
- Timing: play mode becomes a flat `_seq` at construction; `_intervals` + `seekIndex` find the frame for any `dt` (no per-frame loop).
  - `loop` `[1..n]` repeats; `once` `[1..n]` pauses at end; `bounce` `[1..n, n-1..2]` repeats; `bounceOnce` `[1..n, n-1..1]` pauses.
- Flip, applied in `getFrameInfo`: `flippedH: sx=-sx, ox=frameWidth-ox, kx=-kx, ky=-ky`; `flippedV: sy=-sy, oy=frameHeight-oy, kx=-kx, ky=-ky` (both active cancel the shear negation).

## Public API

```lua
local g = desAnim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight [, left, top, border])
g('1-6', 1)  g('1-4', '1-2')  g(2, 3)  g('1-7', 1, '6-2', 1)   -- row-major; reverse ranges allowed

local anim = desAnim8.new(image, frames, durations [, playMode])   -- durations: number | {0.1,0.2} | {['1-3']=0.1}
local anim = desAnim8.new(image, fw, fh, numFrames, frameDuration, imageWidth, imageHeight [, playMode])  -- legacy
local anim = desAnim8.newAnimation(frames, durations [, playMode])  -- image-less (or pass nil image)
-- playMode: 'loop' (default) | 'once' | 'bounce' | 'bounceOnce'
```

Methods (see the README reference for the full list): `update(dt)`, `tick`, `draw([image,] x, y [, r, sx, sy, ox, oy, kx, ky])` (image first only for image-less animations), `getFrameInfo(...)` (returns `quad, x, y, r, sx, sy, ox, oy, kx, ky` with flip, trim, pivot, transform and pixel snap applied), playback (`pause`, `resume`, `pauseAtEnd`, `pauseAtStart`, `stop`, `reset`, `gotoFrame`, `setPhase`, `setSpeed`, `fitDuration`, `freeze`, `setStep`, `setEasing`, `setLoopRange`/`release`, `wait`), events (`onLoop`/`onStart`/`onEnd` fields, `onFrame`, `addMarker`), runtime changes (`setPlayMode`, `setDurations`), data (`getFrameData`, `getWorldRect`, `setAutoPivot`, `setInterpolation`), style (`setColor`, `setAlpha`, `setBlendMode`, `setShader`, `flash`, `faceTowards`, `setPixelSnap`, `setTrail`, `setOnion`, `drawBounds`), `getState`/`setState`, `clone()`.

Constructors: `new`, `newAnimation`, `newAnimationFromQuads` (all take a trailing `opts`: `ticks`, `weights`, `jitter`, `rng`, `randomLength`, `data`), `newFromAseprite`, `newSet`, `newSetFromAseprite`, `newComposite`, `newBatch`, `newWatcher`, `newGrid`, `newGridFromImage`. Helpers: `newFramesFromRecords`, `atlas.*`, `scanBounds`, `dataFromLists`, `sliceByAlpha`, `newQuadsFromRects`, `setTimeScale`, `shaders`, `debug.*`.

Fields: `status` (`'playing'`/`'paused'`), `currentFrame` (1-based). `onLoop = function(anim, loopCount)` or a method name string (e.g. `'pauseAtEnd'` with `loop` to play once). `once`/`bounceOnce` already pause at end.

SpriteBatch: `anim:addToBatch(sb, x, y)` returns the id, `anim:setInBatch(sb, id, x, y)` updates it.
