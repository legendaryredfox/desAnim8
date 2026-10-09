# desAnim8 v0.5.0: an animation library for LÖVE 11.5

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-legendaryredfox-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/legendaryredfox)

This project was based on [kikito's anim8](https://github.com/kikito/anim8). If you like it, please consider supporting his work.

## Funny story

Not really, but I like the LÖVE framework, and one day decided to try and make games for the PSP, which is a great handheld. I ended up creating a few tools and adding a bit of code to repos that already existed. Then, a friend told me that there could be a few people out there for whom this code could be useful, and I decided to make it public.

This code will be updated whenever I have the time to spare on this project, so please be patient.

## Disclaimers

- I'm not an experienced Lua or LÖVE developer, keep that in mind when using this code
- Feel free to open issues, but if you decide to do so, please include a detailed description

---

## Quick start

```lua
local desAnim8 = require 'libraries.desAnim8'

local image, player

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')   -- crisp pixel art; before newImage
    image = love.graphics.newImage('player.png')
    local g = desAnim8.newGrid(48, 48, image:getWidth(), image:getHeight())

    player = {
        x = 400, y = 300,
        animations = {
            idle = desAnim8.new(image, g('1-6', 1), 0.12),
            run  = desAnim8.new(image, g('1-8', 2), 0.08),
        }
    }
    player.current = player.animations.idle
end

function love.update(dt)
    player.current:update(dt)
end

function love.draw()
    player.current:draw(player.x, player.y)
end
```

---

## Grid

A grid divides a spritesheet into frame positions addressable by column and row.

```lua
local g = desAnim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight [, left, top, border])
```

| Parameter | Default | Description |
|---|---|---|
| `frameWidth`, `frameHeight` | none | Size of one frame in pixels |
| `imageWidth`, `imageHeight` | none | Full size of the spritesheet (use `image:getWidth()` / `image:getHeight()`) |
| `left`, `top` | `0` | Pixel offset of the grid origin inside the image |
| `border` | `0` | Pixel gap around every frame: one border precedes the first frame and one follows each frame (same as anim8) |

Call the grid to get a list of LÖVE Quads:

```lua
g('1-6', 1)             -- columns 1–6, row 1
g('1-4', '1-2')         -- columns 1–4 across rows 1 and 2 (row-major)
g(2, 3)                 -- single frame: column 2, row 3
g('1-7', 1, '6-2', 1)   -- two ranges chained; produces a ping-pong loop pattern
```

Ranges are numbers or `"n-m"` strings. Reverse ranges (`"6-2"`) produce frames in reverse order.
Column and row counts take `left`, `top` and `border` into account, so asking for a frame outside the sheet raises an error.

---

## Creating animations

```lua
-- from a grid (uniform duration)
local anim = desAnim8.new(image, g('1-6', 1), 0.1)

-- per-frame durations
local anim = desAnim8.new(image, g('1-6', 1), {0.2, 0.1, 0.1, 0.1, 0.1, 0.2})

-- range-keyed durations
local anim = desAnim8.new(image, g('1-6', 1), {['1']=0.2, ['2-5']=0.1, ['6']=0.2})

-- with a play mode
local anim = desAnim8.new(image, g('1-6', 1), 0.1, 'bounce')
```

**Play modes:** `'loop'` (default), `'once'`, `'bounce'`, `'bounceOnce'`.

| Mode | Plays | Ends |
|---|---|---|
| `loop` | `1..n`, repeats | |
| `once` | `1..n` | pauses on `n` |
| `bounce` | `1..n, n-1..2`, repeats | |
| `bounceOnce` | `1..n, n-1..1` | pauses on `1` |

The frame list is copied when the animation is created; durations and frames cannot be changed afterwards.

Legacy single-row constructor (v0.0.1 compatible):

```lua
local anim = desAnim8.new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight)
```

Image-less animation (the image is passed at draw time). Reuse one animation
across several images, or let a console backend keep the image handle:

```lua
local anim = desAnim8.newAnimation(g('1-6', 1), 0.1)   -- no image bound
function love.draw() anim:draw(image, x, y) end        -- image first
```

---

## Drawing

```lua
-- basic
anim:draw(x, y)

-- with rotation, scale, and offset (same parameters as love.graphics.draw)
anim:draw(x, y, rotation, scaleX, scaleY, offsetX, offsetY)

-- horizontal / vertical flip (chainable; flip state persists)
anim:flipH():draw(x, y)

-- absolute setters are safe to call every frame
anim:setFlipH(player.facingLeft)

-- mirrored clone (does not affect the original)
local mirrored = anim:clone():flipH()
```

Flip is applied automatically inside `draw`. When you need the raw parameters (e.g. for a SpriteBatch), use `getFrameInfo`:

```lua
local quad, x, y, r, sx, sy, ox, oy, kx, ky = anim:getFrameInfo(x, y)
spriteBatch:add(quad, x, y, r, sx, sy, ox, oy, kx, ky)
```

---

## Animation methods

```lua
anim:update(dt)               -- advance time; call in love.update
anim:draw(x, y [, r, sx, sy, ox, oy, kx, ky])

anim:pause()                  -- freeze on current frame
anim:resume()                 -- unpause
anim:pauseAtEnd()             -- jump to the end of the play sequence and pause
anim:pauseAtStart()           -- jump to first frame and pause
anim:stop()                   -- same as pauseAtStart
anim:reset()                  -- rewind to frame 1 and unpause
anim:gotoFrame(n)             -- jump to frame n (1-based)

anim:flipH()                  -- toggle horizontal flip (returns self)
anim:flipV()                  -- toggle vertical flip (returns self)
anim:setFlipH(bool)           -- set horizontal flip (returns self)
anim:setFlipV(bool)           -- set vertical flip (returns self)
anim:clone()                  -- new animation, same data, fresh state

anim:isPlaying()              -- true when not paused
anim:isPaused()               -- true when paused
anim:getCurrentFrame()        -- returns current frame index and its Quad
anim:getDimensions()          -- returns w, h of the current frame
anim:getFrameCount()          -- number of frames
anim:getDuration()            -- seconds for one full play-through (bounce modes include the way back)
anim:getPlayMode()            -- 'loop' | 'once' | 'bounce' | 'bounceOnce'
anim:getFrameInfo([...])      -- returns quad + transform params with flip applied
```

When the animation has no bound image, pass the image first: `anim:draw(image, x, y [, ...])`.
Passing the wrong shape raises an error that says which form to use.

Notes:

- `pauseAtEnd` goes to the last entry of the play sequence: frame `n` for `loop` and `once`, frame `2` for `bounce` (the frame before the cycle repeats), frame `1` for `bounceOnce`.
- `resume` does nothing on a finished `once`/`bounceOnce` animation. Call `reset()` or `gotoFrame(n)` to play it again.
- `update` ignores `dt <= 0`, `NaN` and infinity, and raises an error if `dt` is not a number.
- Errors are reported at your call site, not inside the library.

### Fields

| Field | Meaning |
|---|---|
| `anim.status` | `'playing'` or `'paused'` (read only; use `pause`/`resume`) |
| `anim.currentFrame` | 1-based index of the current frame (read only) |
| `anim.flippedH`, `anim.flippedV` | current flip state (use `flipH`/`setFlipH`) |
| `anim.playMode` | the play mode given at construction (read only) |
| `anim.image` | the bound image, or `nil` |
| `anim.onLoop` | optional callback, see below |

---

## onLoop callback

```lua
-- function: receives the animation and how many loops elapsed
anim.onLoop = function(a, loops)
    if loops > 3 then a:pause() end
end

-- string: calls a method on the animation by name
-- useful with 'loop' mode to play exactly once then freeze
local anim = desAnim8.new(image, g('1-4', 3), 0.1)   -- play mode is 'loop'
anim.onLoop = 'pauseAtEnd'                             -- stops on the last frame after one cycle
```

An unknown method name raises an error when the loop fires.

Note: `'once'` and `'bounceOnce'` modes already pause at the end automatically. Use `onLoop` with those modes only when you need a notification callback, not to trigger the pause.

---

## Full example

```lua
local desAnim8 = require 'libraries.desAnim8'

local image, player

function love.load()
    image = love.graphics.newImage('player.png')
    local g = desAnim8.newGrid(48, 48, image:getWidth(), image:getHeight())

    player = {
        x = 400,
        y = 300,
        facingLeft = false,
        animations = {
            idle   = desAnim8.new(image, g('1-6', 1), 0.15),
            run    = desAnim8.new(image, g('1-8', 2), 0.08),
            -- 'once' mode auto-pauses on the last frame; no onLoop needed
            attack = desAnim8.new(image, g('1-4', 3), {0.05, 0.1, 0.1, 0.2}, 'once'),
        },
    }
    player.current = player.animations.idle
end

function love.update(dt)
    player.current:update(dt)

    if love.keyboard.isDown('left')  then player.facingLeft = true  end
    if love.keyboard.isDown('right') then player.facingLeft = false end
end

function love.draw()
    local anim = player.current
    anim:setFlipH(player.facingLeft)
    anim:draw(player.x, player.y)
end
```

---

## Installing

desAnim8 is a single file with no dependencies beyond LÖVE itself.

1. Copy `desAnim8.lua` into your project (e.g. `libraries/desAnim8.lua`).
2. `require` it:

```lua
local desAnim8 = require 'libraries.desAnim8'   -- adjust the path to where you put it
```

Requires LÖVE 11.5 (LuaJIT / Lua 5.1–5.4). It only uses `love.graphics.newQuad`
and `love.graphics.draw`, so it also runs on LÖVE-compatible layers, see below.

---

## Migrating from anim8

desAnim8 is based on [kikito's anim8](https://github.com/kikito/anim8) and keeps a
similar shape, with a few differences.

| anim8 | desAnim8 | Notes |
|---|---|---|
| `anim8.newGrid(fw, fh, iw, ih, l, t, b)` | `desAnim8.newGrid(fw, fh, iw, ih, left, top, border)` | Same signature and border model. |
| `grid('1-6', 1)` | `g('1-6', 1)` | Same range strings; reverse ranges (`'6-1'`) supported. |
| `anim8.newAnimation(frames, durations)` | `desAnim8.newAnimation(frames, durations)` | Same call, no image bound. Keep `anim:draw(image, x, y)`. |
| `anim8.newAnimation(frames, durations, onLoop)` | `desAnim8.newAnimation(frames, durations, playMode)` | The third argument is a **play mode**, not `onLoop`. Set `anim.onLoop` afterwards. |
| `durations`: number / list / `{['1-3']=0.1}` | same | Identical duration forms. Overlapping range keys are an error. |
| looping via `onLoop` returning `'pauseAtEnd'` | play modes `'loop' \| 'once' \| 'bounce' \| 'bounceOnce'` | Prefer play modes; `onLoop` still exists for callbacks. |
| `anim:draw(image, x, y, ...)` | `anim:draw(x, y, ...)` when built with `desAnim8.new(image, ...)` | Or keep the anim8 call with an image-less animation. |
| `anim:flipH()` toggles a flag | `anim:flipH()` toggles a flag (chainable) | Same behaviour; desAnim8 also has `setFlipH(bool)`. |
| `anim.position` | `anim.currentFrame` | 1-based current frame index. |

Quick port, two ways:

```lua
-- anim8
local anim = anim8.newAnimation(grid('1-6', 1), 0.1)
function love.draw() anim:draw(image, x, y) end

-- desAnim8, image-less: only the module name changes
local anim = desAnim8.newAnimation(g('1-6', 1), 0.1)
function love.draw() anim:draw(image, x, y) end

-- desAnim8, image bound to the animation
local anim = desAnim8.new(image, g('1-6', 1), 0.1)
function love.draw() anim:draw(x, y) end
```

---

## Related libraries & the Aseprite workflow

desAnim8 is grid/quad-based like [anim8](https://github.com/kikito/anim8). If your
art lives in **Aseprite**, these libraries import its exports directly and are
worth a look (a native Aseprite import is planned):

| Library | Niche |
|---|---|
| [anim8](https://github.com/kikito/anim8) | The original grid/quad animator desAnim8 is based on. |
| [peachy](https://github.com/josh-perry/peachy) | Renders Aseprite **JSON + PNG** exports; uses **frame tags**. |
| [nim.lua](https://github.com/tarhses/nim.lua) | Aseprite sheets with forward/reverse/**ping-pong** and caching. |
| [OSLib Sprites Lib](https://github.com/PSP-Archive/oslibmodv2) | C sprite animation on PSP (framerate, flip, start/end frame), the same shape in native code. |

**Aseprite export tips** (also apply to the planned importer): export the sheet as
an **Array** (not a hash), enable **Frame Tags** (define at least one, even for a
single animation), and pass the image to your loader yourself: Aseprite writes a
non-relative image path into the JSON that LÖVE won't load. Aseprite **slices**
are regions, not frames, so they don't animate.

---

## Using on consoles (PSP / Vita / PS3)

desAnim8 was written with [LOVE-WrapLua](https://github.com/legendaryredfox/LOVE-WrapLua)
in mind, so the same animation code runs on homebrew hardware. It touches only
`love.graphics.newQuad`, `love.graphics.draw(image, quad, ...)` and
`quad:getViewport()`, never a backend's native image data. On backends that own
the image handle, build the animation image-less (`newAnimation`) and pass the
image at draw time: `anim:draw(image, x, y)`. Keep the console GPU limits in mind
when building spritesheets:

- **PSP:** textures must be **power-of-two** and **≤ 512×512**. Split larger
  sheets into multiple images.
- On the wrapper's **lpp-vita** backend, spritesheet/quad drawing is still being
  finished, so use the **OneLua** backend on Vita for animation-heavy games for now.

---

## Spritesheet tips

- **Avoid edge bleed.** With linear filtering, neighbouring frames can bleed a
  pixel into each other. Either leave a 1px gutter between frames and pass it as
  the grid `border`, or draw with nearest-neighbour filtering for pixel art:

  ```lua
  love.graphics.setDefaultFilter('nearest', 'nearest')   -- before newImage
  local g = desAnim8.newGrid(48, 48, iw, ih, 0, 0, 1)    -- 1px border between frames
  ```

- **`getFrameInfo` for SpriteBatch / shaders.** When you need the raw quad plus
  transform (with flip already applied), use `getFrameInfo` instead of `draw`.

- **Clone per entity.** Give each on-screen entity its own `anim:clone()` so their
  playback (timer, current frame, flip) stays independent.

---

## Tests

```sh
luajit tests/run.lua            # unit tests (also runs under lua5.1)
xvfb-run -a love tests/smoke    # renders in a real LÖVE window and checks pixel extents
```
