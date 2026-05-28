# AGENTS.md

## Project overview

desAnim8 is a single-file sprite animation library for LÖVE games targeting the **PSP (PlayStation Portable)** platform. It provides frame-based animation from spritesheets and is designed to work with PSP's `image.blit` rendering API. Inspired by [kikito/anim8](https://github.com/kikito/anim8).

Tested on: RetroArch (LÖVE core) on Linux, and a Sony PSP 3000.

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
| `Grid` | local class | Maps row/column coordinates on a spritesheet to frame tables |
| `playModes` | local table | Advance-frame strategies: `loop`, `once`, `bounce`, `bounceOnce` |
| `desAnim8` | public module | Animation objects; also the metatable for animations |

### Frame representation

Frames are plain Lua tables `{ x, y, w, h }` (pixel source coordinates inside the spritesheet). This keeps the library dependency-free — it does **not** use `love.graphics.newQuad`.

### Rendering

Drawing is done via PSP's native `image.blit`:

```lua
image.blit(image, destX, destY, srcX, srcY, srcW, srcH)
```

Do **not** use `love.graphics.draw` — that is standard LÖVE, not available or reliable on all PSP ports.

## Public API

### Grid

```lua
local g = desAnim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight [, left, top])
```

`left`/`top` (default 0) offset the origin inside the image, useful when the sheet has padding.

Calling the grid returns a list of frame tables:

```lua
local frames = g('1-6', 1)     -- columns 1–6, row 1 (single row)
local frames = g('1-4', '1-2') -- columns 1–4 across rows 1 and 2
local frames = g(2, 3)         -- single frame: column 2, row 3
```

Column and row arguments accept a number or a `"from-to"` range string. Multiple pairs can be chained:

```lua
local frames = g('1-3', 1, '1-3', 2) -- rows 1 and 2, columns 1–3
```

### Animation constructor

New API:

```lua
local anim = desAnim8.new(image, frames, frameDuration [, playMode])
```

Legacy API (backward-compatible with v0.0.1):

```lua
local anim = desAnim8.new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight [, playMode])
```

`playMode` is one of: `'loop'` (default), `'once'`, `'bounce'`, `'bounceOnce'`.

### Animation methods

| Method | Description |
|---|---|
| `anim:update(dt)` | Advance animation time; call every frame |
| `anim:draw(x, y)` | Draw the current frame at (x, y) |
| `anim:pause()` | Freeze on the current frame |
| `anim:resume()` | Unpause |
| `anim:stop()` | Pause and rewind to frame 1 |
| `anim:reset()` | Rewind to frame 1 and unpause |
| `anim:gotoFrame(n)` | Jump to frame n (1-based) |
| `anim:isPlaying()` | Returns true if not paused |
| `anim:isPaused()` | Returns true if paused |
| `anim:clone()` | Shallow copy sharing the same frame list |

### onLoop callback

```lua
anim.onLoop = function(anim, mode) ... end
```

Called when the animation reaches a loop point. `mode` is the current play mode string.

## What is implemented

- [x] Single-row spritesheet animation (legacy API)
- [x] Multi-row spritesheet support via `Grid`
- [x] Play modes: `loop`, `once`, `bounce`, `bounceOnce`
- [x] Playback controls: `pause`, `resume`, `stop`, `reset`, `gotoFrame`
- [x] `onLoop` callback
- [x] `clone()` for sharing frame data across animation instances
- [x] Backward compatibility with the original v0.0.1 constructor signature

## What might still be needed

- [ ] Per-frame duration (different delay per frame)
- [ ] Draw with scale and rotation (depends on PSP port's `image.blit` support)
- [ ] Horizontal/vertical flip in `draw` (depends on PSP port capabilities)

## Conventions and rules for AI agents

- **One file only.** Do not split the library across multiple files.
- **No LÖVE graphics API.** Never call `love.graphics.newQuad`, `love.graphics.draw`, or any other `love.graphics.*` function. The only draw call is `image.blit`.
- **No external dependencies.** The library must `require` nothing.
- **Backward compatibility.** The legacy constructor signature must keep working.
- **Lua 5.1 compatible.** PSP runtimes use Lua 5.1; avoid 5.2+ syntax (`goto`, `<const>`, bitwise operators, etc.).
- **No comments explaining what code does.** Only add a comment when the *why* is non-obvious.
