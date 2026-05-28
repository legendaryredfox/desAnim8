local desAnim8 = {
    _VERSION     = 'desAnim8 v0.1.0',
    _DESCRIPTION = 'An animation library for LÖVE games in the PSP platform',
    _URL         = 'https://github.com/legendaryredfox/desAnim8',
    _THANKS      = [[
        All thanks, recognition and incentives should go to https://github.com/kikito
    ]],
    _LICENSE     = [[
      MIT LICENSE

      Copyright (c) 2024

      Permission is hereby granted, free of charge, to any person obtaining a
      copy of this software and associated documentation files (the
      "Software"), to deal in the Software without restriction, including
      without limitation the rights to use, copy, modify, merge, publish,
      distribute, sublicense, and/or sell copies of the Software, and to
      permit persons to whom the Software is furnished to do so, subject to
      the following conditions:

      The above copyright notice and this permission notice shall be included
      in all copies or substantial portions of the Software.

      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
      IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
      CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
      TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
      SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    ]]
}
desAnim8.__index = desAnim8

-- ──────────────────────────────────────────────
-- Grid
-- ──────────────────────────────────────────────

local Grid = {}
Grid.__index = Grid

function desAnim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight, left, top)
    local self      = setmetatable({}, Grid)
    self.frameWidth  = frameWidth
    self.frameHeight = frameHeight
    self.imageWidth  = imageWidth
    self.imageHeight = imageHeight
    self.left        = left or 0
    self.top         = top  or 0
    self.cols        = math.floor(imageWidth  / frameWidth)
    self.rows        = math.floor(imageHeight / frameHeight)
    return self
end

local function parseRange(v, max)
    if type(v) == 'number' then
        assert(v >= 1 and v <= max, ('Index %d out of range [1, %d]'):format(v, max))
        return { v }
    end
    local from, to = v:match('^(%d+)-(%d+)$')
    if from then
        from, to = tonumber(from), tonumber(to)
        assert(from >= 1 and to >= 1 and from <= max and to <= max,
            ('Range "%s" out of bounds [1, %d]'):format(v, max))
        local result, step = {}, from <= to and 1 or -1
        for i = from, to, step do result[#result + 1] = i end
        return result
    end
    local single = v:match('^(%d+)$')
    if single then
        single = tonumber(single)
        assert(single >= 1 and single <= max, ('Index %d out of range [1, %d]'):format(single, max))
        return { single }
    end
    error(('Invalid grid range: %q'):format(tostring(v)))
end

-- grid('1-6', 1) or grid(1, 1, 6, 1) etc.  Returns a list of frame tables {x,y,w,h}.
function Grid:__call(...)
    local args   = { ... }
    local frames = {}
    local i      = 1
    while i <= #args do
        local cols = parseRange(args[i],     self.cols)
        local rows = parseRange(args[i + 1], self.rows)
        i = i + 2
        for _, row in ipairs(rows) do
            for _, col in ipairs(cols) do
                frames[#frames + 1] = {
                    x = self.left + (col - 1) * self.frameWidth,
                    y = self.top  + (row - 1) * self.frameHeight,
                    w = self.frameWidth,
                    h = self.frameHeight,
                }
            end
        end
    end
    return frames
end

-- ──────────────────────────────────────────────
-- Play modes
-- ──────────────────────────────────────────────

local playModes = {}

playModes.loop = function(anim)
    local next = anim.currentFrame + 1
    if next > #anim.frames then
        next = 1
        if anim.onLoop then anim.onLoop(anim, 'loop') end
    end
    anim.currentFrame = next
end

playModes.once = function(anim)
    if anim.currentFrame < #anim.frames then
        anim.currentFrame = anim.currentFrame + 1
    else
        anim.paused = true
        if anim.onLoop then anim.onLoop(anim, 'once') end
    end
end

playModes.bounce = function(anim)
    local next = anim.currentFrame + anim._dir
    if next > #anim.frames then
        anim._dir = -1
        next      = #anim.frames - 1
        if anim.onLoop then anim.onLoop(anim, 'bounce') end
    elseif next < 1 then
        anim._dir = 1
        next      = 2
        if anim.onLoop then anim.onLoop(anim, 'bounce') end
    end
    anim.currentFrame = math.max(1, math.min(#anim.frames, next))
end

playModes.bounceOnce = function(anim)
    local next = anim.currentFrame + anim._dir
    if next > #anim.frames then
        anim._dir = -1
        next      = #anim.frames - 1
    elseif next < 1 then
        anim.paused = true
        next        = 1
        if anim.onLoop then anim.onLoop(anim, 'bounceOnce') end
    end
    anim.currentFrame = math.max(1, math.min(#anim.frames, next))
end

-- ──────────────────────────────────────────────
-- Animation
-- ──────────────────────────────────────────────

-- New API:    desAnim8.new(image, frames, frameDuration [, playMode])
-- Legacy API: desAnim8.new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight [, playMode])
function desAnim8.new(image, ...)
    local self         = setmetatable({}, desAnim8)
    self.image         = image
    self.currentFrame  = 1
    self.timeElapsed   = 0
    self._dir          = 1
    self.paused        = false
    self.onLoop        = nil

    local args = { ... }
    if type(args[1]) == 'table' then
        self.frames        = args[1]
        self.frameDuration = args[2]
        self.playMode      = args[3] or 'loop'
    else
        -- legacy: frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight [, playMode]
        local fw, fh, n, dur, iw, ih, mode =
            args[1], args[2], args[3], args[4], args[5], args[6], args[7]
        self.frameDuration = dur
        self.playMode      = mode or 'loop'
        self.frames        = {}
        for i = 0, n - 1 do
            self.frames[#self.frames + 1] = { x = i * fw, y = 0, w = fw, h = fh }
        end
    end

    assert(#self.frames > 0, 'desAnim8.new: frames list is empty')
    assert(self.frameDuration and self.frameDuration > 0, 'desAnim8.new: frameDuration must be > 0')
    assert(playModes[self.playMode], ('desAnim8.new: unknown playMode %q'):format(tostring(self.playMode)))
    return self
end

function desAnim8:update(dt)
    if self.paused then return end
    self.timeElapsed = self.timeElapsed + dt
    while self.timeElapsed >= self.frameDuration do
        self.timeElapsed = self.timeElapsed - self.frameDuration
        playModes[self.playMode](self)
        if self.paused then break end
    end
end

function desAnim8:draw(x, y)
    local f = self.frames[self.currentFrame]
    image.blit(self.image, x, y, f.x, f.y, f.w, f.h)
end

function desAnim8:pause()
    self.paused = true
end

function desAnim8:resume()
    self.paused = false
end

-- Stop and rewind to frame 1.
function desAnim8:stop()
    self.paused       = true
    self.currentFrame = 1
    self.timeElapsed  = 0
    self._dir         = 1
end

-- Rewind to frame 1 and unpause.
function desAnim8:reset()
    self.currentFrame = 1
    self.timeElapsed  = 0
    self._dir         = 1
    self.paused       = false
end

function desAnim8:gotoFrame(n)
    assert(n >= 1 and n <= #self.frames,
        ('desAnim8:gotoFrame: %d out of range [1, %d]'):format(n, #self.frames))
    self.currentFrame = n
    self.timeElapsed  = 0
end

function desAnim8:isPlaying()
    return not self.paused
end

function desAnim8:isPaused()
    return self.paused
end

-- Returns a new animation that shares the same frames table.
function desAnim8:clone()
    local c = setmetatable({}, desAnim8)
    for k, v in pairs(self) do c[k] = v end
    c.frames = self.frames
    return c
end

return desAnim8
