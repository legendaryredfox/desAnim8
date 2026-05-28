# AGENTS.md

## Project overview

desAnim8 is a single-file sprite animation library for **LÖVE 11.5** games. It provides frame-based animation from spritesheets using `love.graphics.draw` and LÖVE Quads. Inspired by [kikito/anim8](https://github.com/kikito/anim8).

## Lua / LÖVE runtime note

LÖVE 11.5 ships with **LuaJIT**, which is Lua 5.1 with selected Lua 5.2 extensions (e.g. `goto`). "Lua 5.5" is not a released version; all code in this project targets **LuaJIT / Lua 5.1**. Do not use Lua 5.3+ syntax (`//`, `&`, `|`, `<<`, `>>`, `<const>`, `<close>`, `math.type`, etc.).

## Repository layout

```
desAnim8.lua   ← entire library (single file, returns a module table)
README.md
LICENSE
AGENTS.md      ← this file
```

## Architecture

### Components inside `desAnim8.lua`

| Symbol | Kind | Purpose |
|---|---|---|
| `Grid` | local class | Builds LÖVE Quad lists from a spritesheet's row/column layout |
| `desAnim8` | public module / metatable | Animation objects |

Internal helpers (all local, not exported):

| Symbol | Purpose |
|---|---|
| `assertPositiveInteger` | Validates grid constructor arguments |
| `parseRange` | Parses a number or `"n-m"` string into `(from, to, step)` — no table allocation |
| `parseDurations` | Normalises the `durations` argument into a per-frame array |
| `buildIntervals` | Builds a cumulative time array from per-frame durations |
| `buildSequence` | Expands a play mode into a flat frame-index list |
| `initTiming` | Wires up all timing state on a new/reset animation |
| `seekIndex` | Binary search over the intervals array |

### Frame representation

Frames are **LÖVE Quad objects** created by `love.graphics.newQuad`. The Grid stores `imageWidth` and `imageHeight` to pass to `newQuad`. The legacy constructor also takes these as positional parameters.

### Timing model

Play mode is encoded as a flat **sequence** of frame indices (`_seq`) at construction. A cumulative `_intervals` array and a binary search (`seekIndex`) replace any frame-by-frame loop. This correctly handles any size of `dt` without accumulating direction-state bugs.

| Mode | Sequence |
|---|---|
| `loop` | `[1, 2, …, n]` — repeats |
| `once` | `[1, 2, …, n]` — pauses at end |
| `bounce` | `[1, 2, …, n, n-1, …, 2]` — repeats; endpoints appear once |
| `bounceOnce` | `[1, 2, …, n, n-1, …, 1]` — pauses at end |

### Rendering

Drawing uses the standard LÖVE 11.5 API:

```lua
love.graphics.draw(image, quad, x, y [, r, sx, sy, ox, oy, kx, ky])
```

`image.blit` is **not used**. Do not reintroduce it.

### Flip transform

Flip is applied inside `getFrameInfo` by negating the relevant scale component and adjusting the origin offset so the image stays at the expected screen position. Both `flippedH` and `flippedV` may be active simultaneously.

```
flippedH: sx = -sx,  ox = frameWidth  - ox,  kx = -kx,  ky = -ky
flippedV: sy = -sy,  oy = frameHeight - oy,  kx = -kx,  ky = -ky
```

When both are active the `kx`/`ky` negations cancel out (correct: double-flip = 180° rotation preserves shear).

## Public API

### Grid

```lua
local g = desAnim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight [, left, top, border])
```

- `left`, `top` (default 0) — pixel offset of the grid origin.
- `border` (default 0) — pixel gap between frames in the sheet.

Calling the grid (or `g:getFrames(...)`) returns a list of Quad objects:

```lua
g('1-6', 1)              -- columns 1–6, row 1
g('1-4', '1-2')          -- columns 1–4, rows 1–2 (row-major)
g(2, 3)                  -- single frame at col 2, row 3
g('1-7', 1, '6-2', 1)    -- two ranges chained (submarine pattern)
```

Reverse ranges (`"6-2"`) produce frames in reverse order.

### Animation constructor

New API:

```lua
local anim = desAnim8.new(image, frames, durations [, playMode])
```

`durations` can be a positive number, a per-frame array `{0.1, 0.2, 0.1}`, or a range-keyed table `{['1-3']=0.1, ['4-6']=0.2}`.

Legacy API (backward-compatible):

```lua
local anim = desAnim8.new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight [, playMode])
```

`playMode`: `'loop'` (default), `'once'`, `'bounce'`, `'bounceOnce'`.

### Animation methods

| Method | Description |
|---|---|
| `anim:update(dt)` | Advance animation time; call in `love.update` |
| `anim:draw(x, y [, r, sx, sy, ox, oy, kx, ky])` | Draw via `love.graphics.draw`; flip is applied automatically |
| `anim:getFrameInfo(x, y [, r, sx, sy, ox, oy, kx, ky])` | Returns `quad, x, y, r, sx, sy, ox, oy, kx, ky` with flip applied |
| `anim:getDimensions()` | Returns `w, h` of the current frame |
| `anim:flipH()` | Toggle horizontal flip; returns self (chainable) |
| `anim:flipV()` | Toggle vertical flip; returns self (chainable) |
| `anim:pause()` | Freeze on the current frame |
| `anim:resume()` | Unpause |
| `anim:pauseAtEnd()` | Jump to last frame and pause |
| `anim:pauseAtStart()` | Jump to first frame and pause |
| `anim:stop()` | Alias for `pauseAtStart()` |
| `anim:reset()` | Rewind to frame 1 and unpause |
| `anim:gotoFrame(n)` | Jump to frame n (1-based, index into `frames`) |
| `anim:isPlaying()` | `true` when `status == 'playing'` |
| `anim:isPaused()` | `true` when `status == 'paused'` |
| `anim:clone()` | New animation sharing immutable data; fresh playback state |

### Status field

`anim.status` — string: `'playing'` or `'paused'`.

### currentFrame field

`anim.currentFrame` — 1-based index into `anim.frames` (a LÖVE Quad).

### onLoop callback

```lua
anim.onLoop = function(anim, loopCount) ... end

-- String form: looks up and calls a method on the animation by name.
-- Most useful with 'loop' mode to play exactly once then freeze:
anim.onLoop = 'pauseAtEnd'
```

`'once'` and `'bounceOnce'` modes already call `pauseAtEnd()` internally when the sequence completes. Setting `onLoop = 'pauseAtEnd'` on those modes is redundant (it calls `pauseAtEnd` twice, which is harmless but misleading). Use `onLoop` with those modes only for a notification callback.

### SpriteBatch usage

```lua
local id = sb:add(anim:getFrameInfo(x, y))
-- later:
sb:set(id, anim:getFrameInfo(x, y))
```

## What is implemented

- [x] LÖVE 11.5 rendering via `love.graphics.draw` + Quads
- [x] Grid with `border` param and input validation
- [x] Per-frame durations (number, array, or range-keyed table)
- [x] Play modes: `loop`, `once`, `bounce`, `bounceOnce`
- [x] Interval-based timing with binary search (correct under any `dt`)
- [x] Playback controls: `pause`, `resume`, `stop`, `reset`, `gotoFrame`, `pauseAtEnd`, `pauseAtStart`
- [x] `onLoop(anim, loopCount)` — also accepts a method name string
- [x] `flipH()` / `flipV()` with correct transform math in `getFrameInfo`
- [x] `getDimensions()`
- [x] `clone()` — shares immutable tables, resets playback state
- [x] `status` string field
- [x] Backward-compatible legacy constructor

## What might still be needed

- [ ] Shader support (passing the quad to a custom shader via `love.graphics.setShader`)

## Conventions and rules for AI agents

- **One file only.** Do not split the library across multiple files.
- **LÖVE 11.5 API only.** Use `love.graphics.draw` and `love.graphics.newQuad`. Do not call `image.blit`.
- **No external dependencies.** The library must `require` nothing.
- **Backward compatibility.** The legacy constructor signature must keep working.
- **LuaJIT / Lua 5.1 compatible.** No Lua 5.3+ integer ops (`//`, `&`, `|`, `<<`, `>>`), no `<const>`, no `math.type`.
- **No comments explaining what code does.** Only add a comment when the *why* is non-obvious.
- **Internal fields are prefixed `_`** (`_seq`, `_intervals`, `_timer`, `_position`, `_durations`, `_totalDuration`). Do not expose or document them as public API.
- **`frames`, `_durations`, `_seq`, `_intervals` are immutable after construction.** `clone()` shares them by reference; never mutate them.
