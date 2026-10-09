-- Unit tests for desAnim8. Plain Lua, no dependencies.
-- Run from the repository root: luajit tests/run.lua
local root = (arg and arg[0] or ''):match('^(.*)/tests/[^/]*$') or '.'
package.path = root .. '/?.lua;' .. package.path

-- Minimal love.graphics mock. It validates argument types the way LÖVE does so
-- that malformed calls fail here instead of passing silently.
local drawCalls = {}
love = {
    graphics = {
        newQuad = function(x, y, w, h, iw, ih)
            for i, v in ipairs({ x, y, w, h, iw, ih }) do
                assert(type(v) == 'number', 'newQuad: argument ' .. i .. ' must be a number')
            end
            return { x = x, y = y, w = w, h = h, getViewport = function(q) return q.x, q.y, q.w, q.h end }
        end,
        draw = function(...)
            local a = { ... }
            if type(a[1]) == 'number' or a[1] == nil then
                error('bad argument #1 to draw (Texture expected)', 2)
            end
            drawCalls[#drawCalls + 1] = a
        end,
    },
}

local desAnim8 = require 'desAnim8'

-- ── Harness ───────────────────────────────────────────────────────────────────

local passed, failures = 0, {}

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failures[#failures + 1] = name .. '\n    ' .. tostring(err)
    end
end

local function eq(actual, expected, label)
    if actual ~= expected then
        error(('%sexpected %s, got %s'):format(label and (label .. ': ') or '', tostring(expected), tostring(actual)), 2)
    end
end

local function near(actual, expected, label)
    if math.abs(actual - expected) > 1e-9 then
        error(('%sexpected %s, got %s'):format(label and (label .. ': ') or '', tostring(expected), tostring(actual)), 2)
    end
end

-- fn must raise an error matching pattern, attributed to the caller (this file)
-- and not to a line inside the library.
local function throws(fn, pattern, label)
    local ok, err = pcall(fn)
    if ok then error((label or 'call') .. ' did not raise an error', 2) end
    err = tostring(err)
    if not err:find(pattern) then
        error(('%s: error %q does not match %q'):format(label or 'call', err, pattern), 2)
    end
    if err:find('desAnim8%.lua') then
        error(('%s: error points inside the library: %q'):format(label or 'call', err), 2)
    end
end

local function seqString(anim) return table.concat(anim._seq, ',') end

local IMG = { 'image' }
local function grid() return desAnim8.newGrid(16, 16, 64, 32) end
local function four(duration, mode) return desAnim8.new(IMG, grid()('1-4', 1), duration or 0.1, mode) end

-- ── Grid ──────────────────────────────────────────────────────────────────────

test('grid: cols and rows without border', function()
    local g = desAnim8.newGrid(16, 16, 64, 32)
    eq(g.cols, 4); eq(g.rows, 2)
end)

test('grid: cols and rows account for border', function()
    -- 20 frames of 16px with a 1px border before each frame = 20*17 + 1 = 341
    local g = desAnim8.newGrid(16, 16, 341, 18, 0, 0, 1)
    eq(g.cols, 20)
    throws(function() g(21, 1) end, 'out of range')
    eq(#g('1-20', 1), 20)
end)

test('grid: cols and rows account for left and top offsets', function()
    local g = desAnim8.newGrid(16, 16, 64, 64, 32, 16)
    eq(g.cols, 2); eq(g.rows, 3)
    throws(function() g(3, 1) end, 'out of range')
end)

test('grid: quad positions with left, top and border', function()
    local g = desAnim8.newGrid(16, 16, 200, 200, 10, 20, 2)
    local f = g('1-2', '1-2')
    eq(#f, 4)
    eq(f[1].x, 12); eq(f[1].y, 22)
    eq(f[2].x, 30); eq(f[2].y, 22)
    eq(f[3].x, 12); eq(f[3].y, 40)
end)

test('grid: ranges, reverse ranges and chained pairs', function()
    local g = grid()
    eq(#g('1-4', '1-2'), 8)
    local rev = g('4-1', 1)
    eq(rev[1].x, 48); eq(rev[4].x, 0)
    eq(#g('1-4', 1, '4-1', 1), 8)
    eq(#g(' 1 - 3 ', 1), 3)
    eq(#g(2, 2), 1)
    eq(#g('2', '2'), 1)
end)

test('grid: invalid ranges raise errors attributed to the caller', function()
    local g = grid()
    throws(function() g('0-2', 1) end, 'out of range', 'zero')
    throws(function() g(5, 1) end, 'out of range', 'too high')
    throws(function() g('a', 1) end, 'invalid', 'letters')
    throws(function() g('3-', 1) end, 'invalid', 'open range')
    throws(function() g('-1', 1) end, 'invalid', 'negative')
    throws(function() g(1.5, 1) end, 'integer', 'fraction')
    throws(function() g('1-2') end, 'row', 'odd argument count')
    throws(function() g() end, 'no frames', 'no arguments')
end)

test('grid: constructor validation', function()
    throws(function() desAnim8.newGrid(0, 16, 64, 32) end, 'frameWidth')
    throws(function() desAnim8.newGrid(16, 16, 64) end, 'imageHeight')
    throws(function() desAnim8.newGrid(16.5, 16, 64, 32) end, 'frameWidth')
    throws(function() desAnim8.newGrid('16', 16, 64, 32) end, 'frameWidth')
    throws(function() desAnim8.newGrid(16, 16, 64, 32, -1) end, 'left')
    throws(function() desAnim8.newGrid(16, 16, 64, 32, 0, 'x') end, 'top')
    throws(function() desAnim8.newGrid(16, 16, 64, 32, 0, 0, 1.5) end, 'border')
end)

-- ── Durations ─────────────────────────────────────────────────────────────────

test('durations: number, array and range-keyed forms', function()
    local g = grid()
    near(desAnim8.new(IMG, g('1-4', 1), 0.25):getDuration(), 1.0)
    near(desAnim8.new(IMG, g('1-4', 1), { 0.1, 0.2, 0.3, 0.4 }):getDuration(), 1.0)
    local a = desAnim8.new(IMG, g('1-4', 1), { ['1'] = 0.2, ['2-3'] = 0.1, [4] = 0.2 })
    near(a:getDuration(), 0.6)
end)

test('durations: invalid input', function()
    local g = grid()
    throws(function() desAnim8.new(IMG, g('1-4', 1), 0) end, 'positive number')
    throws(function() desAnim8.new(IMG, g('1-4', 1), -1) end, 'positive number')
    throws(function() desAnim8.new(IMG, g('1-4', 1), 'x') end, 'durations')
    throws(function() desAnim8.new(IMG, g('1-4', 1), nil) end, 'durations')
    throws(function() desAnim8.new(IMG, g('1-4', 1), { 0.1, 0.1 }) end, 'no duration specified for frame 3')
    throws(function() desAnim8.new(IMG, g('1-4', 1), { 0.1, 0.1, 0.1, 0.1, 0.1 }) end, 'durations')
    throws(function() desAnim8.new(IMG, g('1-4', 1), { 0.1, 0.1, 0.1, -1 }) end, 'positive number')
end)

test('durations: overlapping range keys are rejected', function()
    throws(function()
        desAnim8.new(IMG, grid()('1-4', 1), { ['1-3'] = 0.1, ['2-4'] = 0.2 })
    end, 'more than once')
end)

-- ── Play mode sequences ───────────────────────────────────────────────────────

test('sequences for every play mode', function()
    eq(seqString(four(0.1, 'loop')), '1,2,3,4')
    eq(seqString(four(0.1, 'once')), '1,2,3,4')
    eq(seqString(four(0.1, 'bounce')), '1,2,3,4,3,2')
    eq(seqString(four(0.1, 'bounceOnce')), '1,2,3,4,3,2,1')
    eq(seqString(four()), '1,2,3,4', 'default mode')
end)

test('sequences: one and two frame edge cases', function()
    local g = grid()
    eq(seqString(desAnim8.new(IMG, g(1, 1), 0.1, 'bounce')), '1')
    eq(seqString(desAnim8.new(IMG, g('1-2', 1), 0.1, 'bounce')), '1,2')
    eq(seqString(desAnim8.new(IMG, g('1-2', 1), 0.1, 'bounceOnce')), '1,2,1')
end)

-- ── Constructors ──────────────────────────────────────────────────────────────

test('constructor: unknown play mode names the valid ones', function()
    throws(function() four(0.1, 'pingpong') end, 'unknown play mode "pingpong"')
    throws(function() four(0.1, 'pingpong') end, 'bounceOnce')
end)

test('constructor: anim8 style third argument gets a hint', function()
    throws(function() four(0.1, 'pauseAtEnd') end, 'onLoop')
    throws(function() four(0.1, function() end) end, 'onLoop')
end)

test('constructor: empty frames list', function()
    throws(function() desAnim8.new(IMG, {}, 0.1) end, 'empty')
end)

test('constructor: anim8 style call without an image gets a usage error', function()
    throws(function() desAnim8.new(grid()('1-4', 1), 0.1) end, 'newAnimation')
    throws(function() desAnim8.new(IMG) end, 'newAnimation')
end)

test('constructor: legacy form', function()
    local a = desAnim8.new(IMG, 16, 16, 4, 0.1, 64, 16)
    eq(#a.frames, 4)
    eq(a.frames[4].x, 48)
    eq(a.playMode, 'loop')
    eq(desAnim8.new(IMG, 16, 16, 4, 0.1, 64, 16, 'once').playMode, 'once')
    throws(function() desAnim8.new(IMG, 16, 16, 4, 0.1) end, 'imageWidth')
    throws(function() desAnim8.new(IMG, 0, 16, 4, 0.1, 64, 16) end, 'frameWidth')
    throws(function() desAnim8.new(IMG, 16, 16, 0, 0.1, 64, 16) end, 'numFrames')
end)

test('constructor: newAnimation is image-less', function()
    local a = desAnim8.newAnimation(grid()('1-4', 1), 0.1, 'once')
    eq(a.image, nil)
    eq(a.playMode, 'once')
    eq(#a.frames, 4)
end)

test('constructor: caller frame list is copied', function()
    local frames = grid()('1-4', 1)
    local a = desAnim8.new(IMG, frames, 0.1)
    frames[#frames + 1] = frames[1]
    eq(#a.frames, 4)
end)

test('instances do not inherit the module table', function()
    local a = four()
    eq(a.new, nil); eq(a.newGrid, nil); eq(a.newAnimation, nil); eq(a._VERSION, nil)
end)

-- ── Timing ────────────────────────────────────────────────────────────────────

test('update: frame advance at interval boundaries', function()
    local a = four(0.1)
    eq(a.currentFrame, 1)
    a:update(0.1); eq(a.currentFrame, 2)
    a:update(0.1); eq(a.currentFrame, 3)
    a:update(0.1); eq(a.currentFrame, 4)
    a:update(0.1); eq(a.currentFrame, 1, 'wraps')
end)

test('update: large dt skips frames and wraps', function()
    local a = desAnim8.new(IMG, grid()('1-4', 1), { 0.1, 0.2, 0.3, 0.4 })
    a:update(2.55)
    eq(a.currentFrame, 3)
    near(a._timer, 0.55)
end)

test('update: once and bounceOnce pause on their last frame', function()
    local o = four(0.1, 'once'); o:update(10)
    eq(o.currentFrame, 4); eq(o.status, 'paused')
    local b = four(0.1, 'bounceOnce'); b:update(10)
    eq(b.currentFrame, 1); eq(b.status, 'paused')
end)

test('update: paused animations do not advance', function()
    local a = four(0.1); a:pause(); a:update(1)
    eq(a.currentFrame, 1); eq(a:isPaused(), true)
    a:resume(); a:update(0.15)
    eq(a.currentFrame, 2); eq(a:isPlaying(), true)
end)

test('update: ignores zero, negative, NaN and infinite dt', function()
    local a = four(0.1)
    local loops = 0
    a.onLoop = function() loops = loops + 1 end
    a:update(0.15)
    for _, dt in ipairs({ 0, -0.01, -5, 0 / 0, math.huge, -math.huge }) do
        a:update(dt)
        eq(a.currentFrame, 2, 'frame after dt ' .. tostring(dt))
        near(a._timer, 0.15, 'timer after dt ' .. tostring(dt))
    end
    eq(loops, 0)
    a:update(0.1)
    eq(a.currentFrame, 3, 'still playable afterwards')
end)

test('update: non-number dt raises a clear error', function()
    local a = four()
    throws(function() a:update(nil) end, 'dt')
    throws(function() a:update('x') end, 'dt')
end)

test('onLoop: function receives loop count', function()
    local a = four(0.1)
    local total = 0
    a.onLoop = function(anim, loops) eq(anim, a); total = total + loops end
    a:update(1.0)
    eq(total, 2)
    near(a._timer, 0.2)
end)

test('onLoop: method name string', function()
    local a = four(0.1)
    a.onLoop = 'pauseAtEnd'
    a:update(0.5)
    eq(a.status, 'paused'); eq(a.currentFrame, 4)
end)

test('onLoop: unknown method name raises a clear error', function()
    local a = four(0.1)
    a.onLoop = 'nope'
    throws(function() a:update(1) end, 'onLoop.-nope')
end)

test('onLoop: callback may reset the animation', function()
    local a = four(0.1, 'once')
    a.onLoop = function(anim) anim:reset() end
    a:update(1)
    eq(a.currentFrame, 1); eq(a.status, 'playing')
end)

test('once: resume on a finished animation stays finished', function()
    local a = four(0.1, 'once')
    local loops = 0
    a.onLoop = function() loops = loops + 1 end
    a:update(1)
    eq(loops, 1)
    a:resume(); a:update(0.05)
    eq(a.status, 'paused'); eq(loops, 1); eq(a.currentFrame, 4)
    a:reset(); a:update(0.15)
    eq(a.currentFrame, 2); eq(a.status, 'playing')
end)

test('pauseAtEnd rests on the last frame of the play sequence', function()
    local l = four(0.1, 'loop'); l:pauseAtEnd(); eq(l.currentFrame, 4); eq(l.status, 'paused')
    local b = four(0.1, 'bounce'); b:pauseAtEnd(); eq(b.currentFrame, 2)
    local bo = four(0.1, 'bounceOnce'); bo:pauseAtEnd(); eq(bo.currentFrame, 1)
end)

test('pauseAtStart, stop, reset', function()
    local a = four(0.1); a:update(0.25)
    a:pauseAtStart(); eq(a.currentFrame, 1); eq(a.status, 'paused')
    a:resume(); a:update(0.25); a:stop()
    eq(a.currentFrame, 1); eq(a.status, 'paused')
    a:update(0.25); a:reset()
    eq(a.currentFrame, 1); eq(a.status, 'playing')
end)

test('gotoFrame', function()
    local a = four(0.1)
    a:gotoFrame(3)
    eq(a.currentFrame, 3); near(a._timer, 0.2)
    a:update(0.05); eq(a.currentFrame, 3)
    a:update(0.06); eq(a.currentFrame, 4)
    throws(function() a:gotoFrame(5) end, 'out of range')
    throws(function() a:gotoFrame(0) end, 'out of range')
    throws(function() a:gotoFrame(1.5) end, 'integer')
    throws(function() a:gotoFrame('a') end, 'integer')
    throws(function() a:gotoFrame(nil) end, 'integer')
end)

test('timing matches a naive reference (seeded fuzz)', function()
    math.randomseed(1234)
    local modes = { 'loop', 'once', 'bounce', 'bounceOnce' }
    for _ = 1, 1500 do
        local n = math.random(1, 8)
        local frames, durs, centis = {}, {}, {}
        for i = 1, n do
            centis[i] = math.random(1, 50)
            durs[i] = centis[i] / 100
            frames[i] = love.graphics.newQuad(i, 0, 1, 1, 100, 100)
        end
        local mode = modes[math.random(4)]
        local a = desAnim8.newAnimation(frames, durs, mode)
        local seq = {}
        for i = 1, n do seq[#seq + 1] = i end
        if n > 1 and mode == 'bounce' then for i = n - 1, 2, -1 do seq[#seq + 1] = i end end
        if n > 1 and mode == 'bounceOnce' then for i = n - 1, 1, -1 do seq[#seq + 1] = i end end
        local cum, total = { 0 }, 0
        for i, fi in ipairs(seq) do total = total + centis[fi]; cum[i + 1] = total end
        local once = mode == 'once' or mode == 'bounceOnce'
        local t = 0
        for _ = 1, 30 do
            local dtc = math.random(0, 300)
            t = t + dtc
            a:update(dtc / 100)
            local tt, expected = t % total, nil
            if once and t >= total then
                expected = seq[#seq]
            else
                for i = 1, #seq do
                    if tt >= cum[i] and tt < cum[i + 1] then expected = seq[i]; break end
                end
            end
            -- exact boundaries are decided by float rounding; skip them
            local onBoundary = false
            for i = 1, #cum do if tt == cum[i] then onBoundary = true end end
            if not onBoundary then eq(a.currentFrame, expected, mode .. ' t=' .. t) end
            if a.status == 'paused' then break end
        end
    end
end)

-- ── Flip and getFrameInfo ─────────────────────────────────────────────────────

test('getFrameInfo: no flip passes parameters through untouched', function()
    local a = four()
    local q, x, y, r, sx, sy, ox, oy, kx, ky = a:getFrameInfo(1, 2)
    eq(q, a.frames[1]); eq(x, 1); eq(y, 2)
    eq(r, nil); eq(sx, nil); eq(sy, nil); eq(ox, nil); eq(oy, nil); eq(kx, nil); eq(ky, nil)
end)

test('getFrameInfo: flipH', function()
    local a = four(); a:flipH()
    local _, _, _, r, sx, sy, ox, oy, kx, ky = a:getFrameInfo(0, 0, 0, 1, 1, 4, 5, 0.5, 0.25)
    eq(r, 0); eq(sx, -1); eq(sy, 1); eq(ox, 12); eq(oy, 5); eq(kx, -0.5); eq(ky, -0.25)
end)

test('getFrameInfo: flipV', function()
    local a = four(); a:flipV()
    local _, _, _, _, sx, sy, ox, oy, kx, ky = a:getFrameInfo(0, 0, 0, 1, 1, 4, 5, 0.5, 0.25)
    eq(sx, 1); eq(sy, -1); eq(ox, 4); eq(oy, 11); eq(kx, -0.5); eq(ky, -0.25)
end)

test('getFrameInfo: both flips cancel the shear negation', function()
    local a = four(); a:flipH():flipV()
    local _, _, _, _, sx, sy, ox, oy, kx, ky = a:getFrameInfo(0, 0, 0, 1, 1, 4, 5, 0.5, 0.25)
    eq(sx, -1); eq(sy, -1); eq(ox, 12); eq(oy, 11); eq(kx, 0.5); eq(ky, 0.25)
end)

test('getFrameInfo: omitted sy follows sx like love.graphics.draw', function()
    local a = four(); a:flipH()
    local _, _, _, _, sx, sy = a:getFrameInfo(0, 0, 0, 3)
    eq(sx, -3); eq(sy, 3)
    a:flipH():flipV()
    _, _, _, _, sx, sy = a:getFrameInfo(0, 0, 0, 3)
    eq(sx, 3); eq(sy, -3)
    a:flipV():flipH()
    _, _, _, _, sx, sy = a:getFrameInfo(0, 0, 0, 3, 2)
    eq(sx, -3); eq(sy, 2, 'explicit sy is kept')
end)

test('flip setters and chaining', function()
    local a = four()
    eq(a:flipH(), a); eq(a:flipV(), a)
    eq(a.flippedH, true); eq(a.flippedV, true)
    eq(a:setFlipH(false), a); eq(a:setFlipV(false), a)
    eq(a.flippedH, false); eq(a.flippedV, false)
    a:setFlipH(true); a:setFlipH(true)
    eq(a.flippedH, true, 'setters are absolute, not toggles')
    throws(function() a:setFlipH(nil) end, 'boolean')
end)

-- ── Draw ──────────────────────────────────────────────────────────────────────

test('draw: bound image', function()
    drawCalls = {}
    local a = four()
    a:draw(5, 6, 0, 2, 2)
    local c = drawCalls[1]
    eq(c[1], IMG); eq(c[2], a.frames[1]); eq(c[3], 5); eq(c[4], 6); eq(c[6], 2)
end)

test('draw: image-less animation takes the image first', function()
    drawCalls = {}
    local a = desAnim8.newAnimation(grid()('1-4', 1), 0.1)
    a:draw(IMG, 5, 6, 0, 2, 2)
    local c = drawCalls[1]
    eq(c[1], IMG); eq(c[3], 5); eq(c[4], 6); eq(c[6], 2)
    a:draw(IMG, 1, 1)
    eq(#drawCalls, 2)
end)

test('draw: wrong argument shape gives a clear error', function()
    local bound = four()
    local free = desAnim8.newAnimation(grid()('1-4', 1), 0.1)
    throws(function() bound:draw(IMG, 5, 6) end, 'image bound')
    throws(function() free:draw(5, 6) end, 'no image')
    throws(function() free:draw() end, 'no image')
end)

-- ── Misc API ──────────────────────────────────────────────────────────────────

test('getters', function()
    local a = four(0.1, 'bounce')
    eq(a:getFrameCount(), 4)
    near(a:getDuration(), 0.6, 'bounce plays 6 frames per cycle')
    eq(a:getPlayMode(), 'bounce')
    local idx, quad = a:getCurrentFrame()
    eq(idx, 1); eq(quad, a.frames[1])
    local w, h = a:getDimensions()
    eq(w, 16); eq(h, 16)
end)

test('clone: independent state, shared immutable data, copied flip and onLoop', function()
    local a = four(0.1); a:update(0.25)
    local cb = function() end
    a.onLoop = cb; a:flipH()
    local c = a:clone()
    eq(c.currentFrame, 1); eq(c.status, 'playing')
    eq(c.flippedH, true); eq(c.onLoop, cb)
    eq(c.frames, a.frames); eq(c._seq, a._seq); eq(c._intervals, a._intervals)
    c:update(0.15)
    eq(a.currentFrame, 3, 'original untouched')
    eq(c.currentFrame, 2)
    c:flipH()
    eq(a.flippedH, true); eq(c.flippedH, false)
end)

-- ── Report ────────────────────────────────────────────────────────────────────

if #failures > 0 then
    io.write(('%d passed, %d failed\n\n'):format(passed, #failures))
    for _, f in ipairs(failures) do io.write('FAIL ', f, '\n') end
    os.exit(1)
end
io.write(('%d passed, 0 failed\n'):format(passed))
