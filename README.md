### desAnim8 v0.3.0 — An animation library for LÖVE 11.5

This project was based on [kikito's anim8](https://github.com/kikito/anim8). If you like it, please consider supporting his work.

### Funny story

Not really, but I like the LÖVE framework, and one day decided to try and make games for the PSP, which is a great handheld. I ended up creating a few tools and adding a bit of code to repos that already existed. Then, a friend told me that there could be a few people out there for whom this code could be useful, and I decided to make it public.

This code will be updated whenever I have the time to spare on this project, so please be patient.

### Disclaimers

- I'm not an experienced Lua or LÖVE developer, keep that in mind when using this code
- Feel free to open issues, but if you decide to do so, please include a detailed description

---

### Quick start

```lua
local desAnim8 = require 'libraries.desAnim8'

local image, player

function love.load()
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

### Grid

A grid divides a spritesheet into frame positions addressable by column and row.

```lua
local g = desAnim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight [, left, top, border])
```

| Parameter | Default | Description |
|---|---|---|
| `frameWidth`, `frameHeight` | — | Size of one frame in pixels |
| `imageWidth`, `imageHeight` | — | Full size of the spritesheet (use `image:getWidth()` / `image:getHeight()`) |
| `left`, `top` | `0` | Pixel offset of the grid origin inside the image |
| `border` | `0` | Pixel gap between frames in the sheet |

Call the grid to get a list of LÖVE Quads:

```lua
g('1-6', 1)             -- columns 1–6, row 1
g('1-4', '1-2')         -- columns 1–4 across rows 1 and 2 (row-major)
g(2, 3)                 -- single frame: column 2, row 3
g('1-7', 1, '6-2', 1)   -- two ranges chained; produces a ping-pong loop pattern
```

Ranges are numbers or `"n-m"` strings. Reverse ranges (`"6-2"`) produce frames in reverse order.

---

### Creating animations

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

Legacy single-row constructor (v0.0.1 compatible):

```lua
local anim = desAnim8.new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight)
```

---

### Drawing

```lua
-- basic
anim:draw(x, y)

-- with rotation, scale, and offset (same parameters as love.graphics.draw)
anim:draw(x, y, rotation, scaleX, scaleY, offsetX, offsetY)

-- horizontal / vertical flip (chainable; flip state persists)
anim:flipH():draw(x, y)

-- mirrored clone (does not affect the original)
local mirrored = anim:clone():flipH()
```

Flip is applied automatically inside `draw`. When you need the raw parameters (e.g. for a SpriteBatch), use `getFrameInfo`:

```lua
local quad, x, y, r, sx, sy, ox, oy, kx, ky = anim:getFrameInfo(x, y)
spriteBatch:add(quad, x, y, r, sx, sy, ox, oy, kx, ky)
```

---

### Animation methods

```lua
anim:update(dt)               -- advance time; call in love.update
anim:draw(x, y [, r, sx, sy, ox, oy, kx, ky])

anim:pause()                  -- freeze on current frame
anim:resume()                 -- unpause
anim:pauseAtEnd()             -- jump to last frame and pause
anim:pauseAtStart()           -- jump to first frame and pause
anim:stop()                   -- same as pauseAtStart
anim:reset()                  -- rewind to frame 1 and unpause
anim:gotoFrame(n)             -- jump to frame n (1-based)

anim:flipH()                  -- toggle horizontal flip (returns self)
anim:flipV()                  -- toggle vertical flip (returns self)
anim:clone()                  -- new animation, same data, fresh state

anim:isPlaying()              -- true when not paused
anim:isPaused()               -- true when paused
anim:getDimensions()          -- returns w, h of the current frame
anim:getFrameInfo([...])      -- returns quad + transform params with flip applied
```

`anim.status` is `'playing'` or `'paused'`. `anim.currentFrame` is the 1-based frame index.

---

### onLoop callback

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

Note: `'once'` and `'bounceOnce'` modes already pause at the end automatically. Use `onLoop` with those modes only when you need a notification callback, not to trigger the pause.

---

### Full example

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
    if player.facingLeft ~= anim.flippedH then anim:flipH() end
    anim:draw(player.x, player.y)
end
```
