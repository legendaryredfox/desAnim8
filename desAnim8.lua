local desAnim8 = {
    _VERSION     = 'desAnim8 v0.3.0',
    _DESCRIPTION = 'An animation library for LÖVE 11.5 games',
    _URL         = 'https://github.com/legendaryredfox/desAnim8',
    _THANKS      = 'All thanks, recognition and incentives should go to https://github.com/kikito',
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

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function assertPositiveInteger(value, name)
    if type(value) ~= 'number' or value < 1 or value ~= math.floor(value) then
        error(('%s must be a positive integer, got %s'):format(name, tostring(value)), 2)
    end
end

-- Binary search: find i such that intervals[i] <= t < intervals[i+1].
-- Correctly returns the last index when t == totalDuration.
local function seekIndex(intervals, t)
    local low, high, i = 1, #intervals - 1, 1
    while low <= high do
        i = math.floor((low + high) / 2)
        if     t >= intervals[i + 1] then low  = i + 1
        elseif t <  intervals[i]     then high = i - 1
        else   break
        end
    end
    return i
end

-- ── Grid ──────────────────────────────────────────────────────────────────────

local Grid = {}
Grid.__index = Grid

-- newGrid(frameWidth, frameHeight, imageWidth, imageHeight [, left, top, border])
-- border: pixel gap between frames in the spritesheet (default 0).
function desAnim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight, left, top, border)
    assertPositiveInteger(frameWidth,  'frameWidth')
    assertPositiveInteger(frameHeight, 'frameHeight')
    assertPositiveInteger(imageWidth,  'imageWidth')
    assertPositiveInteger(imageHeight, 'imageHeight')
    return setmetatable({
        frameWidth  = frameWidth,
        frameHeight = frameHeight,
        imageWidth  = imageWidth,
        imageHeight = imageHeight,
        left        = left   or 0,
        top         = top    or 0,
        border      = border or 0,
        cols        = math.floor(imageWidth  / frameWidth),
        rows        = math.floor(imageHeight / frameHeight),
    }, Grid)
end

-- Returns (from, to, step) — no table allocation.
-- Accepts a number, a "n" string, or a "n-m" range string (spaces ignored).
local function parseRange(v, max)
    if type(v) == 'number' then
        assert(v >= 1 and v <= max, ('index %d out of range [1,%d]'):format(v, max))
        return v, v, 1
    end
    local s = tostring(v):gsub('%s+', '')
    local a, b = s:match('^(%d+)-(%d+)$')
    if a then
        a, b = tonumber(a), tonumber(b)
        assert(a >= 1 and a <= max and b >= 1 and b <= max,
            ('range "%s" out of bounds [1,%d]'):format(v, max))
        return a, b, a <= b and 1 or -1
    end
    local n = s:match('^(%d+)$')
    if n then
        n = tonumber(n)
        assert(n >= 1 and n <= max, ('index %d out of range [1,%d]'):format(n, max))
        return n, n, 1
    end
    error(('invalid range: %q'):format(tostring(v)), 3)
end

-- getFrames(colRange, rowRange [, colRange, rowRange ...])
-- Each pair selects a rectangle of frames in row-major order.
-- Returns a list of love.graphics.newQuad objects.
function Grid:getFrames(...)
    local args   = { ... }
    local frames = {}
    local fw, fh, bw     = self.frameWidth, self.frameHeight, self.border
    local iw, ih         = self.imageWidth, self.imageHeight
    local i = 1
    while i <= #args do
        local cmin, cmax, cstep = parseRange(args[i],     self.cols)
        local rmin, rmax, rstep = parseRange(args[i + 1], self.rows)
        i = i + 2
        for row = rmin, rmax, rstep do
            for col = cmin, cmax, cstep do
                local x = self.left + (col - 1) * (fw + bw) + bw
                local y = self.top  + (row - 1) * (fh + bw) + bw
                frames[#frames + 1] = love.graphics.newQuad(x, y, fw, fh, iw, ih)
            end
        end
    end
    assert(#frames > 0, 'getFrames: no frames selected')
    return frames
end

Grid.__call = Grid.getFrames

-- ── Duration handling ─────────────────────────────────────────────────────────

-- durations can be:
--   number              → same duration for every frame
--   {d1, d2, …}         → per-frame array
--   {['2-4'] = 0.2, …}  → range-keyed table
local function parseDurations(durations, frameCount)
    if type(durations) == 'number' then
        assert(durations > 0, 'frameDuration must be > 0')
        local t = {}
        for i = 1, frameCount do t[i] = durations end
        return t
    end
    assert(type(durations) == 'table', 'durations must be a positive number or a table')
    local result = {}
    for key, dur in pairs(durations) do
        assert(type(dur) == 'number' and dur > 0,
            ('duration for key %q must be a positive number'):format(tostring(key)))
        local from, to, step = parseRange(key, frameCount)
        for k = from, to, step do result[k] = dur end
    end
    for i = 1, frameCount do
        assert(result[i], ('no duration specified for frame %d'):format(i))
    end
    return result
end

local function buildIntervals(durations)
    local t, intervals = 0, { 0 }
    for i = 1, #durations do
        t = t + durations[i]
        intervals[i + 1] = t
    end
    return intervals, t
end

-- ── Sequence (encodes play mode as a frame-index list) ────────────────────────

local VALID_MODES  = { loop=true, once=true, bounce=true, bounceOnce=true }
local PAUSE_AT_END = { once=true, bounceOnce=true }

-- Expand play mode into a flat sequence of frame indices:
--   loop/once      → [1, 2, …, n]
--   bounce         → [1, 2, …, n, n-1, …, 2]   endpoints appear once
--   bounceOnce     → [1, 2, …, n, n-1, …, 1]
local function buildSequence(n, playMode)
    if n == 1 then return { 1 } end
    local seq = {}
    if playMode == 'loop' or playMode == 'once' then
        for i = 1, n do seq[i] = i end
    elseif playMode == 'bounce' then
        for i = 1, n         do seq[#seq + 1] = i end
        for i = n - 1, 2, -1 do seq[#seq + 1] = i end
    else -- bounceOnce
        for i = 1, n         do seq[#seq + 1] = i end
        for i = n - 1, 1, -1 do seq[#seq + 1] = i end
    end
    return seq
end

local function initTiming(self)
    local seq    = buildSequence(#self.frames, self.playMode)
    local seqDur = {}
    for i, fi in ipairs(seq) do seqDur[i] = self._durations[fi] end
    local intervals, total = buildIntervals(seqDur)
    self._seq           = seq
    self._intervals     = intervals
    self._totalDuration = total
    self._timer         = 0
    self._position      = 1
    self.currentFrame   = seq[1]
    self.status         = 'playing'
end

-- ── Animation ─────────────────────────────────────────────────────────────────

-- New API:    new(image, frames, durations [, playMode])
--             frames is a list of Quads, typically from Grid:getFrames()
-- Legacy API: new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight [, playMode])
function desAnim8.new(image, ...)
    local self = setmetatable({}, desAnim8)
    self.image    = image
    self.flippedH = false
    self.flippedV = false
    self.onLoop   = nil

    local args = { ... }
    if type(args[1]) == 'table' then
        self.frames     = args[1]
        self._durations = parseDurations(args[2], #self.frames)
        self.playMode   = args[3] or 'loop'
    else
        local fw, fh, n, dur, iw, ih, mode =
            args[1], args[2], args[3], args[4], args[5], args[6], args[7]
        self.playMode   = mode or 'loop'
        self.frames     = {}
        for i = 0, n - 1 do
            self.frames[#self.frames + 1] = love.graphics.newQuad(i * fw, 0, fw, fh, iw, ih)
        end
        self._durations = parseDurations(dur, n)
    end

    assert(#self.frames > 0, 'desAnim8.new: frames list is empty')
    assert(VALID_MODES[self.playMode],
        ('desAnim8.new: unknown play mode %q'):format(tostring(self.playMode)))

    initTiming(self)
    return self
end

function desAnim8:update(dt)
    if self.status ~= 'playing' then return end

    self._timer = self._timer + dt
    local loops = math.floor(self._timer / self._totalDuration)
    if loops ~= 0 then
        self._timer = self._timer - self._totalDuration * loops
        if PAUSE_AT_END[self.playMode] then
            self:pauseAtEnd()
        end
        if self.onLoop then
            local cb = type(self.onLoop) == 'string' and self[self.onLoop] or self.onLoop
            cb(self, loops)
        end
    end

    self._position    = seekIndex(self._intervals, self._timer)
    self.currentFrame = self._seq[self._position]
end

-- Returns the quad and all love.graphics.draw transform parameters, with flip
-- adjustments applied. Use this when you need to draw with extra transforms, or
-- to add the animation to a SpriteBatch.
function desAnim8:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky)
    local frame = self.frames[self.currentFrame]
    if self.flippedH or self.flippedV then
        r,  sx, sy = r  or 0, sx or 1, sy or 1
        ox, oy     = ox or 0, oy or 0
        kx, ky     = kx or 0, ky or 0
        local _, _, w, h = frame:getViewport()
        if self.flippedH then
            sx = -sx
            ox = w - ox
            kx = -kx
            ky = -ky
        end
        if self.flippedV then
            sy = -sy
            oy = h - oy
            kx = -kx
            ky = -ky
        end
    end
    return frame, x, y, r, sx, sy, ox, oy, kx, ky
end

function desAnim8:draw(x, y, r, sx, sy, ox, oy, kx, ky)
    love.graphics.draw(self.image, self:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky))
end

function desAnim8:getDimensions()
    local _, _, w, h = self.frames[self.currentFrame]:getViewport()
    return w, h
end

-- Toggle horizontal flip. Returns self so calls can be chained.
function desAnim8:flipH()
    self.flippedH = not self.flippedH
    return self
end

-- Toggle vertical flip. Returns self so calls can be chained.
function desAnim8:flipV()
    self.flippedV = not self.flippedV
    return self
end

function desAnim8:pause()
    self.status = 'paused'
end

function desAnim8:resume()
    self.status = 'playing'
end

function desAnim8:pauseAtEnd()
    self._position    = #self._seq
    self._timer       = self._totalDuration
    self.currentFrame = self._seq[self._position]
    self.status       = 'paused'
end

function desAnim8:pauseAtStart()
    self._position    = 1
    self._timer       = 0
    self.currentFrame = self._seq[1]
    self.status       = 'paused'
end

-- Alias for pauseAtStart (backward compat).
function desAnim8:stop()
    self:pauseAtStart()
end

function desAnim8:reset()
    self._position    = 1
    self._timer       = 0
    self.currentFrame = self._seq[1]
    self.status       = 'playing'
end

function desAnim8:gotoFrame(n)
    assert(n >= 1 and n <= #self.frames,
        ('gotoFrame: %d out of range [1,%d]'):format(n, #self.frames))
    for i, fi in ipairs(self._seq) do
        if fi == n then
            self._position    = i
            self._timer       = self._intervals[i]
            self.currentFrame = n
            return
        end
    end
end

function desAnim8:isPlaying()
    return self.status == 'playing'
end

function desAnim8:isPaused()
    return self.status == 'paused'
end

-- Returns a new animation sharing the same immutable data (frames, durations,
-- sequence, intervals). Playback state starts fresh; flip and onLoop are copied.
function desAnim8:clone()
    local c = setmetatable({}, desAnim8)
    for k, v in pairs(self) do c[k] = v end
    c._timer       = 0
    c._position    = 1
    c.currentFrame = c._seq[1]
    c.status       = 'playing'
    return c
end

return desAnim8
