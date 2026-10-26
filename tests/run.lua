-- Unit tests for desAnim8. Plain Lua, no dependencies.
-- Run from the repository root: luajit tests/run.lua
local root = (arg and arg[0] or ''):match('^(.*)/tests/[^/]*$') or '.'
package.path = root .. '/?.lua;' .. package.path

-- Minimal love.graphics mock. It validates argument types the way LÖVE does so
-- that malformed calls fail here instead of passing silently.
local drawCalls, drawStates, gfxLog = {}, {}, {}
local gstate = { color = { 1, 1, 1, 1 }, blend = 'alpha', alphaMode = 'alphamultiply', shader = nil }
local function logger(name)
    return function(...) gfxLog[#gfxLog + 1] = { name, ... } end
end
love = {
    graphics = {
        getColor = function() local c = gstate.color; return c[1], c[2], c[3], c[4] end,
        setColor = function(r, g, b, a)
            gstate.color = { r, g, b, a == nil and 1 or a }
            gfxLog[#gfxLog + 1] = { 'setColor', r, g, b, a }
        end,
        getBlendMode = function() return gstate.blend, gstate.alphaMode end,
        setBlendMode = function(mode, alphaMode)
            gstate.blend, gstate.alphaMode = mode, alphaMode or 'alphamultiply'
            gfxLog[#gfxLog + 1] = { 'setBlendMode', mode, alphaMode }
        end,
        getShader = function() return gstate.shader end,
        setShader = function(sh) gstate.shader = sh; gfxLog[#gfxLog + 1] = { 'setShader', sh } end,
        newSpriteBatch = function(_, capacity)
            local sb = { calls = {}, n = 0, capacity = capacity }
            function sb:add(...) self.n = self.n + 1; self.calls[#self.calls + 1] = { 'add', ... }; return self.n end
            function sb:set(...) self.calls[#self.calls + 1] = { 'set', ... } end
            function sb:clear() self.n = 0 end
            return sb
        end,
        push = logger('push'), pop = logger('pop'), translate = logger('translate'),
        rotate = logger('rotate'), scale = logger('scale'), shear = logger('shear'),
        rectangle = logger('rectangle'), line = logger('line'),
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
            local c = gstate.color
            drawStates[#drawStates + 1] = { color = { c[1], c[2], c[3], c[4] }, blend = gstate.blend,
                alphaMode = gstate.alphaMode, shader = gstate.shader }
        end,
    },
}

-- DESANIM8_BUNDLE=dist/desAnim8.lua runs the suite against the single-file build.
local bundle = os.getenv('DESANIM8_BUNDLE')
local desAnim8 = bundle and dofile(bundle) or require 'desAnim8'

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
    if err:find('desAnim8%.lua') or err:find('desAnim8/[%w_]+%.lua') then
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

-- ── M1: queries, construction sugar, caching, state ──────────────────────────

test('getCurrentFrameNumber and getRemainingTime', function()
    local a = four(0.1)
    eq(a:getCurrentFrameNumber(), 1)
    near(a:getRemainingTime(), 0.4)
    a:update(0.25)
    eq(a:getCurrentFrameNumber(), 3)
    near(a:getRemainingTime(), 0.15)
    near(four(0.1, 'bounce'):getRemainingTime(), 0.6)
end)

test('phase: get and set', function()
    local a = four(0.1)
    near(a:getPhase(), 0)
    a:update(0.2); near(a:getPhase(), 0.5)
    a:setPhase(0.8); eq(a.currentFrame, 4); near(a:getPhase(), 0.8)
    a:setPhase(1); eq(a.currentFrame, 4); near(a:getRemainingTime(), 0)
    a:setPhase(0); eq(a.currentFrame, 1)
    a:setPhase(1.5); near(a:getPhase(), 1, 'clamped high')
    a:setPhase(-1); near(a:getPhase(), 0, 'clamped low')
    throws(function() a:setPhase(0 / 0) end, 'phase')
    throws(function() a:setPhase('x') end, 'phase')
end)

test('getLoopCount counts wraps; reset and clone start at zero', function()
    local a = four(0.1)
    eq(a:getLoopCount(), 0)
    a:update(0.9); eq(a:getLoopCount(), 2)
    a:update(0.4); eq(a:getLoopCount(), 3)
    eq(a:clone():getLoopCount(), 0)
    a:reset(); eq(a:getLoopCount(), 0)
end)

test('isFinished is true only for a completed once or bounceOnce', function()
    local o = four(0.1, 'once')
    eq(o:isFinished(), false)
    o:update(1); eq(o:isFinished(), true)
    o:reset(); eq(o:isFinished(), false)
    local b = four(0.1, 'bounceOnce')
    b:update(10); eq(b:isFinished(), true)
    local l = four(0.1)
    l:update(10); eq(l:isFinished(), false)
end)

local function fakeBatch()
    local b = { calls = {} }
    function b:add(...) self.calls[#self.calls + 1] = { 'add', ... }; return #self.calls end
    function b:set(...) self.calls[#self.calls + 1] = { 'set', ... } end
    return b
end

test('addToBatch and setInBatch pass flip-adjusted frame info', function()
    local a = four(0.1); a:flipH()
    local b = fakeBatch()
    eq(a:addToBatch(b, 10, 20), 1)
    local c = b.calls[1]
    eq(c[1], 'add'); eq(c[2], a.frames[1]); eq(c[3], 10); eq(c[4], 20)
    eq(c[6], -1, 'sx'); eq(c[8], 16, 'ox')
    a:update(0.1)
    a:setInBatch(b, 7, 1, 2)
    c = b.calls[2]
    eq(c[1], 'set'); eq(c[2], 7); eq(c[3], a.frames[2]); eq(c[4], 1); eq(c[5], 2)
end)

test('newAnimationFromQuads builds from hand-made quads', function()
    local q = { love.graphics.newQuad(0, 0, 8, 8, 64, 64), love.graphics.newQuad(8, 0, 8, 8, 64, 64) }
    local a = desAnim8.newAnimationFromQuads(IMG, q, { 0.1, 0.2 }, 'once')
    eq(a.image, IMG); eq(#a.frames, 2); eq(a.playMode, 'once')
    near(a:getDuration(), 0.3)
    throws(function() desAnim8.newAnimationFromQuads(IMG, {}, 0.1) end, 'empty')
end)

test('grid: getFrames memoizes identical calls', function()
    local g = grid()
    local real, n = love.graphics.newQuad, 0
    love.graphics.newQuad = function(...) n = n + 1; return real(...) end
    local ok, err = pcall(function()
        local f1 = g('1-4', 1); eq(n, 4)
        local f2 = g('1-4', 1); eq(n, 4, 'second call builds nothing')
        eq(#f2, 4); eq(f2[1], f1[1])
        assert(f1 ~= f2, 'each call returns its own list')
        f2[1] = nil
        eq(g('1-4', 1)[1], f1[1], 'mutating a returned list does not poison the cache')
        g('1-3', 1); eq(n, 7, 'different arguments miss')
        g:clearCache(); g('1-4', 1); eq(n, 11)
    end)
    love.graphics.newQuad = real
    if not ok then error(err, 0) end
end)

test('grid: failed getFrames calls are not cached', function()
    local g = grid()
    throws(function() g('1-9', 1) end, 'out of range')
    throws(function() g('1-9', 1) end, 'out of range')
end)

test('grid: inset shrinks every quad', function()
    local g = desAnim8.newGrid(16, 16, 64, 32, 0, 0, 0, 0.5)
    local x, y, w, h = g(2, 1)[1]:getViewport()
    eq(x, 16.5); eq(y, 0.5); eq(w, 15); eq(h, 15)
    x, y, w, h = grid()(2, 1)[1]:getViewport()
    eq(x, 16); eq(y, 0); eq(w, 16); eq(h, 16)
    throws(function() desAnim8.newGrid(16, 16, 64, 32, 0, 0, 0, 8) end, 'inset')
    throws(function() desAnim8.newGrid(16, 16, 64, 32, 0, 0, 0, -1) end, 'inset')
end)

test('grid: maxImageSize advisory warns once and is off by default', function()
    local realPrint, lines = print, {}
    print = function(s) lines[#lines + 1] = s end
    local ok, err = pcall(function()
        desAnim8.newGrid(16, 16, 1024, 32)
        eq(#lines, 0, 'off by default')
        desAnim8.maxImageSize = 512
        desAnim8.newGrid(16, 16, 512, 512); eq(#lines, 0, 'at the limit')
        desAnim8.newGrid(16, 16, 1024, 32); eq(#lines, 1)
        desAnim8.newGrid(16, 16, 32, 1024); eq(#lines, 1, 'only once')
    end)
    print = realPrint
    desAnim8.maxImageSize = nil
    if not ok then error(err, 0) end
end)

test('state: round trip keeps playback identical', function()
    for _, mode in ipairs({ 'loop', 'once', 'bounce', 'bounceOnce' }) do
        local a = four(0.1, mode)
        a:update(0.25); a:flipH()
        local b = four(0.1, mode)
        b:setState(a:getState())
        eq(b.currentFrame, a.currentFrame, mode)
        eq(b.flippedH, true, mode)
        eq(b:getLoopCount(), a:getLoopCount(), mode)
        a:update(0.2); b:update(0.2)
        eq(b.currentFrame, a.currentFrame, mode)
        near(b._timer, a._timer, mode)
    end
end)

test('state: paused at end and paused at start survive a round trip', function()
    local a = four(0.1, 'once'); a:update(1)
    local b = four(0.1, 'once'); b:setState(a:getState())
    eq(b.status, 'paused'); eq(b.currentFrame, 4); eq(b:isFinished(), true)
    local c = four(0.1); c:update(0.25); c:stop()
    local d = four(0.1); d:setState(c:getState())
    eq(d.status, 'paused'); eq(d.currentFrame, 1)
end)

test('state: rejects malformed input', function()
    local a = four(0.1)
    local function with(k, v) local t = a:getState(); t[k] = v; return t end
    throws(function() a:setState(nil) end, 'state')
    throws(function() a:setState(with('v', 2)) end, 'version')
    throws(function() a:setState(with('playMode', 'once')) end, 'play mode')
    throws(function() a:setState(with('timer', 5)) end, 'timer')
    throws(function() a:setState(with('timer', 0 / 0)) end, 'timer')
    throws(function() a:setState(with('status', 'x')) end, 'status')
    throws(function() a:setState(with('loops', -1)) end, 'loops')
    throws(function() a:setState(with('flippedH', 1)) end, 'flippedH')
end)

-- ── M2: time engine ───────────────────────────────────────────────────────────

local function lcg()
    local s = 12345
    return function() s = (s * 16807) % 2147483647; return s / 2147483647 end
end

local function withTimeScale(scale, fn)
    desAnim8.setTimeScale(scale)
    local ok, err = pcall(fn)
    desAnim8.setTimeScale(1)
    if not ok then error(err, 0) end
end

test('speed: scales advance, zero holds, bad values rejected', function()
    local a = four(0.1)
    eq(a:getSpeed(), 1)
    a:setSpeed(2); a:update(0.1)
    eq(a.currentFrame, 3)
    a:setSpeed(0); a:update(5)
    eq(a.currentFrame, 3)
    throws(function() a:setSpeed('x') end, 'speed')
    throws(function() a:setSpeed(0 / 0) end, 'speed')
    throws(function() a:setSpeed(math.huge) end, 'speed')
end)

test('speed: negative plays backwards and wraps to the end', function()
    local a = four(0.1)
    a:setSpeed(-1); a:pauseAtEnd(); a:resume()
    eq(a.currentFrame, 4)
    a:update(0.05); eq(a.currentFrame, 4)
    a:update(0.1);  eq(a.currentFrame, 3)
    a:update(0.1);  eq(a.currentFrame, 2)
    a:update(0.1);  eq(a.currentFrame, 1)
    eq(a:getLoopCount(), 0)
    a:update(0.1);  eq(a.currentFrame, 4)
    eq(a:getLoopCount(), 1)
    near(a:getRemainingTime(), a._timer, 'reverse remaining time counts down to the start')
end)

test('speed: reverse once stops on the first frame and fires onLoop', function()
    local o = four(0.1, 'once')
    local loops
    o.onLoop = function(_, n) loops = n end
    o:setSpeed(-1); o:pauseAtEnd(); o:resume()
    eq(o.status, 'playing')
    o:update(0.5)
    eq(o.status, 'paused'); eq(o.currentFrame, 1); eq(loops, 1)
    eq(o:isFinished(), true)
    o:resume(); eq(o.status, 'paused', 'a finished reverse once stays finished')
end)

test('resume: looping animation parked at its end restarts without refiring onLoop', function()
    local n = 0
    local a = four(0.1)
    a.onLoop = function(self) n = n + 1; self:pauseAtEnd() end
    a:update(0.5)
    eq(n, 1); eq(a.status, 'paused'); eq(a.currentFrame, 4)
    a:resume()
    eq(a.status, 'playing'); eq(a.currentFrame, 1)
    a:update(0.05)
    eq(n, 1)
end)

test('onFrame fires once per entry into the frame', function()
    local a, hits = four(0.1), {}
    eq(a:onFrame(3, function(self, n) hits[#hits + 1] = n end), a, 'chainable')
    a:update(0.15); eq(#hits, 0)
    a:update(0.1);  eq(#hits, 1); eq(hits[1], 3)
    a:update(0.01); eq(#hits, 1)
    a:update(0.4);  eq(#hits, 2, 'a full cycle re-enters the frame')
end)

test('onFrame: bounce enters a middle frame twice per cycle; huge dt is capped', function()
    local b, n = four(0.1, 'bounce'), 0
    b:onFrame(3, function() n = n + 1 end)
    for _ = 1, 6 do b:update(0.1) end
    eq(n, 2)
    local c, m = four(0.1), 0
    c:onFrame(1, function() m = m + 1 end)
    c:update(1e9)
    eq(m, 1)
    eq(c.currentFrame, c._seq[c._position])
end)

test('onFrame: reverse order, offFrame, clone keeps its own callbacks', function()
    local a, order = four(0.1), {}
    local function rec(_, n) order[#order + 1] = n end
    a:onFrame(3, rec); a:onFrame(2, rec)
    a:setSpeed(-1); a:pauseAtEnd(); a:resume()
    a:update(0.25)
    eq(table.concat(order, ','), '3,2')
    local c = a:clone()
    c:offFrame(2)
    c:setSpeed(1); c:update(0.1)
    eq(#order, 2, 'clone no longer fires frame 2')
    a:setSpeed(1); a:reset(); a:update(0.1)
    eq(order[#order], 2, 'original still fires frame 2')
    throws(function() a:onFrame(9, rec) end, 'frame')
    throws(function() a:onFrame(1, 'x') end, 'function')
end)

test('markers fire when their time is crossed', function()
    local a, n = four(0.1), 0
    a:addMarker(0.25, function() n = n + 1 end)
    a:update(0.2);  eq(n, 0)
    a:update(0.1);  eq(n, 1)
    a:update(0.05); eq(n, 1)
    a:update(0.4);  eq(n, 2, 'crossed again through the wrap')
    a:clearMarkers()
    a:update(0.4);  eq(n, 2)
    throws(function() a:addMarker(5, function() end) end, 'marker')
end)

test('onStart fires on the first advancing update, onEnd when a once finishes', function()
    local log = {}
    local a = four(0.1, 'once')
    a.onStart = function() log[#log + 1] = 'start' end
    a.onLoop  = function() log[#log + 1] = 'loop' end
    a.onEnd   = function() log[#log + 1] = 'end' end
    a:update(0.05); a:update(0.05)
    eq(table.concat(log, ','), 'start')
    a:update(1)
    eq(table.concat(log, ','), 'start,loop,end')
    a:reset(); a:update(0.05)
    eq(table.concat(log, ','), 'start,loop,end,start')
    local l = four(0.1)
    local starts = 0
    l.onStart = function() starts = starts + 1 end
    l:update(1); l:update(1)
    eq(starts, 1, 'not on loop wraps')
end)

test('setPlayMode keeps the frame and leaves clones alone', function()
    local a = four(0.1); a:update(0.25)
    local c = a:clone()
    eq(a:setPlayMode('bounce'), a, 'chainable')
    eq(a.currentFrame, 3); eq(a:getPlayMode(), 'bounce'); eq(a.playMode, 'bounce')
    eq(seqString(a), '1,2,3,4,3,2'); near(a:getDuration(), 0.6)
    near(a._timer, a._intervals[a._position])
    eq(seqString(c), '1,2,3,4'); near(c:getDuration(), 0.4)
    throws(function() a:setPlayMode('nope') end, 'play mode')
end)

test('setDurations retimes and keeps position and progress inside the frame', function()
    local a = four(0.1); a:update(0.25)
    local c = a:clone()
    a:setDurations(0.2)
    eq(a.currentFrame, 3); near(a._timer, 0.5); near(a:getDuration(), 0.8)
    near(c:getDuration(), 0.4)
    throws(function() a:setDurations({ 0.1 }) end, 'frame')
    local o = four(0.1, 'once'); o:update(1); o:setDurations(0.2)
    eq(o.currentFrame, 4); eq(o:isFinished(), true)
end)

test('loop range: intro, loop, release plays the outro', function()
    local a = four(0.1)
    a:setLoopRange(2, 3)
    a:update(0.35); eq(a.currentFrame, 2); eq(a:getLoopCount(), 1)
    a:update(0.1);  eq(a.currentFrame, 3)
    a:update(0.1);  eq(a.currentFrame, 2)
    a:release()
    a:update(0.1);  eq(a.currentFrame, 3)
    a:update(0.1);  eq(a.currentFrame, 4)
    a:update(0.1);  eq(a.currentFrame, 4); eq(a:isFinished(), true); eq(a.status, 'paused')
    a:reset()
    a:update(0.35); eq(a.currentFrame, 2, 'reset restores the loop range')
    a:clearLoopRange(); a:update(0.1); a:update(0.1); a:update(0.1)
    eq(a:getLoopCount() >= 1, true)
    throws(function() four(0.1, 'bounce'):setLoopRange(2, 3) end, 'loop')
    throws(function() a:setLoopRange(3, 2) end, 'range')
    throws(function() a:setLoopRange(1, 9) end, 'range')
    throws(function() a:release() end, 'loop range')
end)

test('time scale scales every animation; freeze holds then resumes mid-call', function()
    withTimeScale(0.5, function()
        eq(desAnim8.getTimeScale(), 0.5)
        local a = four(0.1); a:update(0.4); eq(a.currentFrame, 3)
    end)
    eq(desAnim8.getTimeScale(), 1)
    local f = four(0.1)
    f:freeze(0.2)
    f:update(0.1); eq(f.currentFrame, 1)
    f:update(0.2); eq(f.currentFrame, 2)
    throws(function() desAnim8.setTimeScale(-1) end, 'time scale')
    throws(function() f:freeze(-1) end, 'freeze')
end)

test('fitDuration makes one play-through last the requested time', function()
    local a = four(0.1)
    a:fitDuration(2)
    near(a:getSpeed(), 0.2)
    a:update(1); eq(a.currentFrame, 3)
    local r = four(0.1); r:setSpeed(-3); r:fitDuration(2)
    near(r:getSpeed(), -0.2)
    throws(function() a:fitDuration(0) end, 'seconds')
end)

test('setStep quantizes the displayed time', function()
    local a = four(0.1)
    a:setStep(0.2)
    a:update(0.15); eq(a.currentFrame, 1)
    a:update(0.1);  eq(a.currentFrame, 3)
    a:setStep(nil); a:update(0.01); eq(a.currentFrame, 3)
    throws(function() a:setStep(0) end, 'step')
end)

test('ticks mode is exact integer arithmetic', function()
    local a = desAnim8.newAnimation(grid()('1-4', 1), 3, 'loop', { ticks = true })
    for _ = 1, 1000 do a:tick() end
    eq(a._timer, 4); eq(a:getLoopCount(), 83); eq(a.currentFrame, 2)
    a:tick(5); eq(a._timer, 9)
    throws(function() desAnim8.newAnimation(grid()('1-4', 1), 0.5, 'loop', { ticks = true }) end, 'ticks')
    throws(function() a:update(0.5) end, 'integer')
    a:setSpeed(2)
    throws(function() a:setSpeed(1.5) end, 'integer')
    throws(function() a:fitDuration(2) end, 'ticks')
end)

test('constructor opts are validated', function()
    local q = grid()('1-4', 1)
    throws(function() desAnim8.newAnimation(q, 0.1, 'loop', { bogus = 1 }) end, 'unknown option')
    throws(function() desAnim8.newAnimation(q, 0.1, 'loop', 5) end, 'opts')
    throws(function() desAnim8.newAnimation(q, 0.1, 'loop', { jitter = 2 }) end, 'jitter')
    throws(function() desAnim8.newAnimation(q, 0.1, 'random', { weights = { 1, 1 } }) end, 'weights')
    throws(function() desAnim8.newAnimation(q, 0.1, 'random', { weights = { 1, 0, 0, 0 } }) end, 'weights')
end)

test('random mode: no repeats, reproducible with a seeded rng, weights bias', function()
    local q = grid()('1-4', 1)
    local a = desAnim8.newAnimation(q, 0.1, 'random', { rng = lcg(), randomLength = 16 })
    eq(#a._seq, 16)
    for i = 1, 16 do
        assert(a._seq[i] ~= a._seq[i % 16 + 1], 'repeat at ' .. i)
    end
    local b = desAnim8.newAnimation(q, 0.1, 'random', { rng = lcg(), randomLength = 16 })
    eq(seqString(a), seqString(b))
    local w = desAnim8.newAnimation(q, 0.1, 'random', { rng = lcg(), randomLength = 20, weights = { 0, 0, 1, 1 } })
    for _, f in ipairs(w._seq) do assert(f == 3 or f == 4, 'weights ignored: ' .. f) end
    local c = a:clone()
    assert(c._seq ~= a._seq, 'clone regenerates its own order')
    eq(desAnim8.newAnimation({ q[1] }, 0.1, 'random')._seq[1], 1)
end)

test('randomizeStart and jitter', function()
    local a = four(0.1)
    a:randomizeStart(function() return 0.5 end)
    near(a:getPhase(), 0.5)
    local j = desAnim8.newAnimation(grid()('1-4', 1), 0.1, 'loop', { jitter = 0.5, rng = function() return 1 end })
    near(j:getDuration(), 0.6)
    near(four(0.1):getDuration(), 0.4, 'jitter is per instance')
end)

test('easing remaps time across the sequence', function()
    local a = four(0.1)
    eq(a:setEasing('inQuad'), a, 'chainable')
    a:update(0.2); eq(a.currentFrame, 2)
    a:update(0.2); eq(a.currentFrame, 1)
    a:gotoFrame(3); eq(a.currentFrame, 3)
    a:update(0.0001); eq(a.currentFrame, 3, 'gotoFrame survives the next update')
    a:setEasing(nil); a:reset(); a:update(0.2); eq(a.currentFrame, 3)
    throws(function() a:setEasing('bogus') end, 'easing')
    throws(function() a:setEasing(function(t) return math.sin(t * 10) end) end, 'monotonic')
    a:setEasing(function(t) return t * t end)
end)

test('wait yields until the animation finishes or loops', function()
    local a, log = four(0.1, 'once'), {}
    local co = coroutine.create(function() log[#log + 1] = 'a'; a:wait(); log[#log + 1] = 'b' end)
    coroutine.resume(co); eq(table.concat(log, ','), 'a')
    a:update(0.2); coroutine.resume(co); eq(coroutine.status(co), 'suspended')
    a:update(1);   coroutine.resume(co); eq(coroutine.status(co), 'dead')
    eq(table.concat(log, ','), 'a,b')
    local l = four(0.1)
    local done = false
    local co2 = coroutine.create(function() l:wait(); done = true end)
    coroutine.resume(co2); l:update(0.3); coroutine.resume(co2); eq(done, false)
    l:update(0.2); coroutine.resume(co2); eq(done, true)
    throws(function() l:wait() end, 'coroutine')
end)

test('state: speed, freeze, started, released and random order round trip', function()
    local a = four(0.1)
    a:setSpeed(2); a:freeze(0.3); a:update(0.1)
    local s = a:getState()
    local b = four(0.1); b:setState(s)
    eq(b:getSpeed(), 2); near(b._freeze, a._freeze); eq(b._started, a._started)
    local q = grid()('1-4', 1)
    local r = desAnim8.newAnimation(q, 0.1, 'random', { rng = lcg(), randomLength = 8 })
    r:update(0.25)
    local r2 = desAnim8.newAnimation(q, 0.1, 'random', { rng = lcg(), randomLength = 4 })
    r2:setState(r:getState())
    eq(seqString(r2), seqString(r)); eq(r2.currentFrame, r.currentFrame)
    local lr = four(0.1); lr:setLoopRange(2, 3); lr:release()
    local lr2 = four(0.1); lr2:setLoopRange(2, 3); lr2:setState(lr:getState())
    eq(lr2._released, true)
    local plain = four(0.1)
    throws(function() plain:setState(lr:getState()) end, 'released')
end)

-- ── M3: frame data, atlases, import ───────────────────────────────────────────

-- World-space extent of a quad drawn with the returned transform, along one axis.
local function span(pos, scale, origin, size)
    local a, b = pos + scale * (0 - origin), pos + scale * (size - origin)
    return math.min(a, b), math.max(a, b)
end

local function framesWith(records)
    local quads, data = desAnim8.newFramesFromRecords(records, 64, 16)
    return desAnim8.newAnimation(quads, 1, 'loop', { data = data })
end

test('frame data: lookup, per-frame values, bad options', function()
    local hit1, hit2 = { x = 1, y = 2, w = 3, h = 4 }, { x = 5, y = 6, w = 7, h = 8 }
    local a = desAnim8.newAnimation(grid()('1-2', 1), 0.1, 'loop', { data = { [1] = { hitbox = hit1 }, [2] = { hitbox = hit2 } } })
    eq(a:getFrameData('hitbox'), hit1)
    a:update(0.1)
    eq(a:getFrameData('hitbox'), hit2)
    eq(a:getFrameData('hitbox', 1), hit1)
    eq(a:getFrameData('nothing'), nil)
    eq(a:clone():getFrameData('hitbox'), hit1, 'clone shares data')
    throws(function() desAnim8.newAnimation(grid()('1-2', 1), 0.1, 'loop', { data = { [3] = {} } }) end, 'data')
    throws(function() desAnim8.newAnimation(grid()('1-2', 1), 0.1, 'loop', { data = 5 }) end, 'data')
end)

test('getWorldRect applies origin, scale and flips', function()
    local a = desAnim8.newAnimation(grid()(1, 1), 1, 'loop', { data = { [1] = { hitbox = { x = 2, y = 4, w = 6, h = 8 } } } })
    local function rect(...) return { a:getWorldRect('hitbox', ...) } end
    local r = rect(100, 50)
    eq(r[1], 102); eq(r[2], 54); eq(r[3], 6); eq(r[4], 8)
    r = rect(100, 50, 2)
    eq(r[1], 104); eq(r[2], 58); eq(r[3], 12); eq(r[4], 16)
    r = rect(100, 50, 1, 1, 4, 4)
    eq(r[1], 98); eq(r[2], 50)
    a:flipH()
    r = rect(100, 50)
    eq(r[1], 108, 'mirrored inside the 16 wide frame'); eq(r[2], 54)
    a:flipH():flipV()
    r = rect(100, 50)
    eq(r[1], 102); eq(r[2], 50 + 16 - 4 - 8)
    eq(a:getWorldRect('missing', 0, 0), nil)
end)

test('autoPivot supplies ox and oy only when omitted', function()
    local a = desAnim8.newAnimation(grid()(1, 1), 1, 'loop', { data = { [1] = { pivot = { x = 8, y = 16 } } } })
    local _, _, _, _, _, _, ox, oy = a:getFrameInfo(10, 20)
    eq(ox, nil)
    a:setAutoPivot(true)
    _, _, _, _, _, _, ox, oy = a:getFrameInfo(10, 20)
    eq(ox, 8); eq(oy, 16)
    _, _, _, _, _, _, ox, oy = a:getFrameInfo(10, 20, 0, 1, 1, 3, 4)
    eq(ox, 3); eq(oy, 4)
    a:flipH()
    _, _, _, _, _, _, ox = a:getFrameInfo(10, 20)
    eq(ox, 16 - 8, 'pivot mirrored inside the frame')
end)

test('trimmed frames land on the same world pixels as the untrimmed original', function()
    -- opaque part is source x 2..10 and y 3..7 of a 16x16 frame
    local a = framesWith({ { x = 10, y = 0, w = 8, h = 4, trimX = 2, trimY = 3, sourceW = 16, sourceH = 16 } })
    local function extent(flipH, flipV, ox, oy)
        a.flippedH, a.flippedV = flipH, flipV
        local _, x, y, _, sx, sy, fox, foy = a:getFrameInfo(100, 50, 0, 1, 1, ox, oy)
        local x0, x1 = span(x, sx, fox, 8)
        local y0, y1 = span(y, sy, foy, 4)
        return x0, x1, y0, y1
    end
    local x0, x1, y0, y1 = extent(false, false, 0, 0)
    eq(x0, 102); eq(x1, 110); eq(y0, 53); eq(y1, 57)
    x0, x1 = extent(true, false, 0, 0)
    eq(x0, 106, 'mirrored: 16-10'); eq(x1, 114)
    x0, x1, y0, y1 = extent(false, true, 0, 0)
    eq(x0, 102); eq(y0, 50 + 16 - 7); eq(y1, 50 + 16 - 3)
    x0, x1 = extent(false, false, 5, 0)
    eq(x0, 97); eq(x1, 105)
    x0, x1 = extent(true, false, 5, 0)
    eq(x0, 101); eq(x1, 109)
    a.flippedH, a.flippedV = false, false
    local _, _, _, _, _, _, fox = a:getFrameInfo(0, 0)
    eq(fox, -2, 'trim applies even without flip or origin')
end)

test('records: rotated frames and bad input are rejected', function()
    throws(function() desAnim8.newFramesFromRecords({ { x = 0, y = 0, w = 8, h = 8, rotated = true } }, 64, 16) end, 'rotated')
    throws(function() desAnim8.newFramesFromRecords({}, 64, 16) end, 'records')
    local q, data, durations = desAnim8.newFramesFromRecords({
        { x = 0, y = 0, w = 8, h = 8, name = 'a', duration = 0.1 },
        { x = 8, y = 0, w = 8, h = 8, name = 'b', duration = 0.2 },
    }, 64, 16)
    eq(#q, 2); eq(data[2].name, 'b'); eq(data[1].trim, nil); eq(durations[2], 0.2)
end)

test('atlas adapters: TexturePacker array, hash form, Starling', function()
    local tp = {
        frames = {
            { filename = 'a', frame = { x = 0, y = 0, w = 8, h = 8 }, rotated = false, trimmed = true,
              spriteSourceSize = { x = 2, y = 1, w = 8, h = 8 }, sourceSize = { w = 16, h = 16 } },
        },
        meta = { size = { w = 64, h = 32 } },
    }
    local records, iw, ih = desAnim8.atlas.fromTexturePacker(tp)
    eq(#records, 1); eq(iw, 64); eq(ih, 32)
    eq(records[1].trimX, 2); eq(records[1].trimY, 1); eq(records[1].sourceW, 16); eq(records[1].name, 'a')
    throws(function() desAnim8.atlas.fromTexturePacker({ frames = { a = {} }, meta = {} }) end, 'array')
    local st = desAnim8.atlas.fromStarling({
        { name = 'x', x = 4, y = 5, width = 8, height = 9, frameX = -2, frameY = -1, frameWidth = 16, frameHeight = 16 },
    })
    eq(st[1].x, 4); eq(st[1].w, 8); eq(st[1].trimX, 2); eq(st[1].trimY, 1); eq(st[1].sourceW, 16)
end)

local ASE = {
    frames = {
        { filename = 'f0', frame = { x = 0,  y = 0, w = 16, h = 16 }, rotated = false, trimmed = false,
          spriteSourceSize = { x = 0, y = 0, w = 16, h = 16 }, sourceSize = { w = 16, h = 16 }, duration = 100 },
        { filename = 'f1', frame = { x = 16, y = 0, w = 16, h = 16 }, rotated = false, trimmed = false,
          spriteSourceSize = { x = 0, y = 0, w = 16, h = 16 }, sourceSize = { w = 16, h = 16 }, duration = 200 },
        { filename = 'f2', frame = { x = 32, y = 0, w = 16, h = 16 }, rotated = false, trimmed = false,
          spriteSourceSize = { x = 0, y = 0, w = 16, h = 16 }, sourceSize = { w = 16, h = 16 }, duration = 100 },
        { filename = 'f3', frame = { x = 48, y = 0, w = 16, h = 16 }, rotated = false, trimmed = false,
          spriteSourceSize = { x = 0, y = 0, w = 16, h = 16 }, sourceSize = { w = 16, h = 16 }, duration = 300 },
    },
    meta = {
        size = { w = 64, h = 16 },
        frameTags = {
            { name = 'idle', from = 0, to = 1, direction = 'forward' },
            { name = 'run',  from = 1, to = 3, direction = 'pingpong' },
            { name = 'back', from = 0, to = 3, direction = 'reverse' },
            { name = 'pr',   from = 0, to = 2, direction = 'pingpong_reverse' },
        },
        slices = {
            { name = 'hit', color = '#ff0000ff', keys = {
                { frame = 0, bounds = { x = 1, y = 1, w = 4, h = 4 } },
                { frame = 2, bounds = { x = 2, y = 2, w = 5, h = 5 }, pivot = { x = 8, y = 16 } },
            } },
        },
    },
}

local function viewportXs(anim)
    local xs = {}
    for i, q in ipairs(anim.frames) do xs[i] = select(1, q:getViewport()) end
    return table.concat(xs, ',')
end

test('aseprite: tags map to frames, durations and play modes', function()
    local idle = desAnim8.newFromAseprite(ASE, IMG, 'idle')
    eq(idle:getFrameCount(), 2); eq(idle:getPlayMode(), 'loop'); near(idle:getDuration(), 0.3)
    eq(idle.image, IMG)
    local run = desAnim8.newFromAseprite(ASE, IMG, 'run')
    eq(run:getPlayMode(), 'bounce'); eq(viewportXs(run), '16,32,48')
    near(run:getDuration(), 0.2 + 0.1 + 0.3 + 0.1)
    local back = desAnim8.newFromAseprite(ASE, IMG, 'back')
    eq(viewportXs(back), '48,32,16,0'); eq(back:getPlayMode(), 'loop')
    near(back:getDuration(), 0.7)
    eq(back._durations[1], 0.3)
    local pr = desAnim8.newFromAseprite(ASE, IMG, 'pr')
    eq(viewportXs(pr), '32,16,0'); eq(pr:getPlayMode(), 'bounce')
    local all = desAnim8.newFromAseprite(ASE, IMG)
    eq(all:getFrameCount(), 4)
    local img = desAnim8.newFromAseprite(ASE, nil, 'idle')
    eq(img.image, nil)
end)

test('aseprite: slices become frame data and pivots', function()
    local run = desAnim8.newFromAseprite(ASE, IMG, 'run')
    local b1 = run:getFrameData('hit', 1)
    eq(b1.x, 1); eq(b1.w, 4)
    eq(run:getFrameData('hit', 2).x, 2)
    eq(run:getFrameData('pivot', 1), nil)
    eq(run:getFrameData('pivot', 2).y, 16)
    eq(run:getFrameData('hit', 3).w, 5)
end)

test('aseprite: decoder callback, errors', function()
    local a = desAnim8.newFromAseprite('JSON TEXT', IMG, 'idle', { decode = function(s)
        eq(s, 'JSON TEXT'); return ASE
    end })
    eq(a:getFrameCount(), 2)
    throws(function() desAnim8.newFromAseprite('JSON TEXT', IMG, 'idle') end, 'decode')
    throws(function() desAnim8.newFromAseprite(ASE, IMG, 'nope') end, 'idle')
    throws(function() desAnim8.newFromAseprite({ frames = { f0 = {} }, meta = {} }, IMG, nil) end, 'Array')
    throws(function() desAnim8.newFromAseprite(5, IMG, 'idle') end, 'source')
    local once = desAnim8.newFromAseprite(ASE, IMG, 'idle', { playMode = 'once' })
    eq(once:getPlayMode(), 'once')
end)

test('newGridFromImage reads the image size', function()
    local image = { getDimensions = function() return 64, 32 end }
    local g = desAnim8.newGridFromImage(image, 16, 16)
    eq(g.cols, 4); eq(g.rows, 2)
    throws(function() desAnim8.newGridFromImage({}, 16, 16) end, 'image')
end)

-- ImageData stand-in: opaque pixels inside the given inclusive rectangles.
local function fakeImageData(w, h, rects)
    return {
        getDimensions = function() return w, h end,
        getPixel = function(_, x, y)
            for _, r in ipairs(rects) do
                if x >= r[1] and x < r[1] + r[3] and y >= r[2] and y < r[2] + r[4] then return 1, 1, 1, 1 end
            end
            return 0, 0, 0, 0
        end,
    }
end

test('scanBounds finds the opaque area of each frame', function()
    local data = fakeImageData(32, 16, { { 3, 2, 6, 4 } })
    local quads = grid()('1-2', 1)
    local g = desAnim8.newGrid(16, 16, 32, 16)
    local b = desAnim8.scanBounds(g('1-2', 1), data)
    eq(b[1].x, 3); eq(b[1].y, 2); eq(b[1].w, 6); eq(b[1].h, 4)
    eq(b[2].w, 0)
    local merged = desAnim8.dataFromLists({ bounds = b })
    eq(merged[1].bounds, b[1])
end)

test('sliceByAlpha finds blobs, merges close ones and orders row-major', function()
    local img = fakeImageData(40, 20, { { 2, 2, 6, 6 }, { 20, 3, 8, 6 }, { 4, 12, 6, 6 }, { 9, 2, 2, 2 } })
    local rects = desAnim8.sliceByAlpha(img)
    eq(#rects, 4)
    eq(rects[1].x, 2); eq(rects[2].x, 9); eq(rects[3].x, 20); eq(rects[4].y, 12)
    local merged = desAnim8.sliceByAlpha(img, { mergeGap = 2 })
    eq(#merged, 3); eq(merged[1].x, 2); eq(merged[1].w, 9)
    local filtered = desAnim8.sliceByAlpha(img, { minSize = 3 })
    eq(#filtered, 3)
    local quads = desAnim8.newQuadsFromRects(filtered, 40, 20)
    eq(#quads, 3)
    local x, y, w, h = quads[1]:getViewport()
    eq(x, 2); eq(w, 6)
end)

-- ── M4: rendering ─────────────────────────────────────────────────────────────

local function resetGfx()
    for i = #drawCalls, 1, -1 do drawCalls[i] = nil end
    for i = #drawStates, 1, -1 do drawStates[i] = nil end
    for i = #gfxLog, 1, -1 do gfxLog[i] = nil end
    gstate.color, gstate.blend, gstate.alphaMode, gstate.shader = { 1, 1, 1, 1 }, 'alpha', 'alphamultiply', nil
end

local function countLog(name)
    local n = 0
    for _, e in ipairs(gfxLog) do if e[1] == name then n = n + 1 end end
    return n
end

test('draw without styling touches no graphics state', function()
    resetGfx()
    four(0.1):draw(0, 0)
    eq(#drawCalls, 1); eq(#gfxLog, 0)
end)

test('color and alpha apply during draw and are restored', function()
    resetGfx()
    local a = four(0.1)
    eq(a:setColor(1, 0, 0, 0.5), a, 'chainable')
    a:draw(0, 0)
    eq(drawStates[1].color[2], 0); eq(drawStates[1].color[4], 0.5)
    eq(gstate.color[2], 1, 'previous color restored')
    a:setColor(nil)
    resetGfx(); a:draw(0, 0); eq(#gfxLog, 0)
    a:setAlpha(0.25)
    resetGfx(); a:draw(0, 0)
    eq(drawStates[1].color[1], 1); eq(drawStates[1].color[4], 0.25)
    throws(function() a:setColor('x', 0, 0) end, 'setColor')
    throws(function() a:setAlpha(nil) end, 'alpha')
end)

test('blend mode and shader apply during draw and are restored', function()
    resetGfx()
    local sent = {}
    local shader = { send = function(_, name, value) sent[name] = value end }
    local a = four(0.1)
    a:setBlendMode('add'):setShader(shader, { amount = 0.5 })
    a:draw(0, 0)
    eq(drawStates[1].blend, 'add'); eq(drawStates[1].shader, shader); eq(sent.amount, 0.5)
    eq(gstate.blend, 'alpha'); eq(gstate.shader, nil)
    a:setBlendMode(nil):setShader(nil)
    resetGfx(); a:draw(0, 0); eq(#gfxLog, 0)
    throws(function() a:setBlendMode(5) end, 'blend')
end)

test('flash overrides the tint for a while', function()
    resetGfx()
    local a = four(0.1)
    a:setColor(0.2, 0.4, 0.6, 0.8)
    a:flash(0.2, 1, 1, 1)
    a:draw(0, 0)
    eq(drawStates[1].color[1], 1); eq(drawStates[1].color[4], 0.8, 'alpha kept')
    a:update(0.1); resetGfx(); a:draw(0, 0); eq(drawStates[1].color[1], 1)
    a:update(0.2); resetGfx(); a:draw(0, 0); eq(drawStates[1].color[1], 0.2, 'flash expired')
    a:pause(); a:flash(0.1); a:update(0.2)
    resetGfx(); a:draw(0, 0); eq(drawStates[1].color[1], 0.2, 'flash runs out while paused')
    throws(function() a:flash(0) end, 'flash')
end)

test('faceTowards and default facing', function()
    local a = four(0.1)
    eq(a:faceTowards(-3), a, 'chainable')
    eq(a.flippedH, true)
    a:faceTowards(0); eq(a.flippedH, true)
    a:faceTowards(2); eq(a.flippedH, false)
    a:setDefaultFacing(-1)
    a:faceTowards(2); eq(a.flippedH, true)
    a:faceTowards(-2); eq(a.flippedH, false)
    throws(function() a:faceTowards('x') end, 'faceTowards')
    throws(function() a:setDefaultFacing(0) end, 'facing')
end)

test('pixel snap rounds the draw position', function()
    local a = four(0.1)
    local _, x, y = a:getFrameInfo(10.4, 20.6)
    near(x, 10.4); near(y, 20.6)
    a:setPixelSnap(true)
    _, x, y = a:getFrameInfo(10.4, 20.6)
    eq(x, 10); eq(y, 21)
    _, x = a:getFrameInfo(-0.5, 0)
    eq(x, 0)
    throws(function() a:setPixelSnap(1) end, 'boolean')
end)

test('trail draws fading ghosts of earlier draws', function()
    resetGfx()
    local a = four(0.1)
    a:setTrail(3, 1, 0.6)
    for i = 1, 5 do a:draw(i, 0); a:update(0.1) end
    local trail = a:getTrail()
    eq(#trail, 3)
    eq(trail[1][2], 3); eq(trail[3][2], 5)
    resetGfx()
    a:draw(6, 0)
    eq(#drawCalls, 4, 'three ghosts and the sprite')
    eq(drawCalls[1][3], 3, 'oldest first')
    near(drawStates[1].color[4], 0.15); near(drawStates[2].color[4], 0.3); near(drawStates[3].color[4], 0.45)
    eq(drawStates[4].color[4], 1)
    eq(gstate.color[4], 1)
    a:setTrail(nil); eq(#a:getTrail(), 0)
    resetGfx(); a:draw(0, 0); eq(#drawCalls, 1)
    local s = four(0.1); s:setTrail(5, 2, 0.5)
    for i = 1, 6 do s:draw(i, 0) end
    eq(#s:getTrail(), 3, 'recorded every second draw')
    throws(function() a:setTrail(0.5) end, 'setTrail')
end)

test('onion skin draws neighbouring frames first', function()
    resetGfx()
    local a = four(0.1)
    a:update(0.1)
    a:setOnion(1, 1)
    a:draw(0, 0)
    eq(#drawCalls, 3)
    eq(drawCalls[1][2], a.frames[1]); eq(drawCalls[2][2], a.frames[3]); eq(drawCalls[3][2], a.frames[2])
    assert(drawStates[1].color[1] > drawStates[1].color[2], 'previous frame tinted red')
    assert(drawStates[2].color[2] > drawStates[2].color[1], 'next frame tinted green')
    eq(a.currentFrame, 2, 'current frame untouched')
    resetGfx(); a:reset(); a:draw(0, 0)
    eq(drawCalls[1][2], a.frames[4], 'loop wraps to the last frame')
    local o = four(0.1, 'once')
    resetGfx(); o:setOnion(1, 0); o:draw(0, 0); eq(#drawCalls, 1, 'once does not wrap')
    a:setOnion(nil); resetGfx(); a:draw(0, 0); eq(#drawCalls, 1)
    throws(function() a:setOnion(-1, 0) end, 'setOnion')
end)

test('drawBounds outlines the transformed frame', function()
    resetGfx()
    local a = four(0.1)
    a:drawBounds(10, 20, 0, 2, 2, 4, 5)
    local names = {}
    for _, e in ipairs(gfxLog) do names[#names + 1] = e[1] end
    eq(names[1], 'push'); eq(names[#names], 'pop')
    local rect
    for _, e in ipairs(gfxLog) do
        if e[1] == 'translate' and e[2] == 10 then eq(e[3], 20) end
        if e[1] == 'scale' then eq(e[2], 2) end
        if e[1] == 'rectangle' then rect = e end
    end
    eq(rect[2], 'line'); eq(rect[5], 16); eq(rect[6], 16)
    resetGfx(); a:flipH(); a:drawBounds(0, 0)
    for _, e in ipairs(gfxLog) do if e[1] == 'scale' then eq(e[2], -1) end end
end)

test('debug timeline draws segments and scrubs', function()
    resetGfx()
    local a = four(0.1)
    a:update(0.15)
    desAnim8.debug.drawTimeline(a, 10, 10, 100, 10)
    assert(countLog('rectangle') >= 5, 'one segment per position plus the outline')
    eq(countLog('line'), 1)
    eq(gstate.color[1], 1, 'color restored')
    eq(desAnim8.debug.scrub(a, 60, 15, 10, 10, 100, 10), true)
    near(a:getPhase(), 0.5); eq(a.status, 'paused')
    a:resume()
    eq(desAnim8.debug.scrub(a, 500, 15, 10, 10, 100, 10), false)
    eq(a.status, 'playing')
end)

test('shader sources are plain strings', function()
    for _, name in ipairs({ 'whiteFlash', 'paletteSwap', 'outline' }) do
        local src = desAnim8.shaders[name]
        eq(type(src), 'string', name)
        assert(src:find('vec4 effect'), name .. ' defines effect')
    end
end)

-- ── M5: sets, composites, keyframe transforms, batch, watcher ─────────────────

test('set: play, flip survives clip changes, queue, keepPhase', function()
    local idle, hit, run = four(0.1), four(0.05, 'once'), four(0.05)
    local set = desAnim8.newSet({ idle = idle, hit = hit, run = run }, 'idle')
    local cur, name = set:getCurrent()
    eq(cur, idle); eq(name, 'idle')
    set:flipH(); eq(idle.flippedH, true)
    local changes = {}
    set.onChange = function(_, from, to) changes[#changes + 1] = from .. '>' .. to end
    eq(set:play('run'), set, 'chainable')
    eq(set:getCurrent(), run); eq(run.flippedH, true); eq(changes[1], 'idle>run')
    set:play('run'); eq(#changes, 1, 'same clip does nothing')
    set:update(0.075); eq(run.currentFrame, 2)
    set:play('run', { restart = true }); eq(run.currentFrame, 1)

    set:play('hit'); set:queue('idle')
    set:update(0.05)
    eq(select(2, set:getCurrent()), 'hit')
    set:update(0.2)
    eq(select(2, set:getCurrent()), 'idle'); eq(changes[#changes], 'hit>idle')
    eq(idle.currentFrame, 1, 'a clip starts over when played')

    idle:update(0.25)
    local phase = idle:getPhase()
    set:play('run', { keepPhase = true })
    near(run:getPhase(), phase)
    throws(function() set:play('nope') end, 'clip')
    throws(function() desAnim8.newSet({}) end, 'clips')
    throws(function() desAnim8.newSet({ idle = idle }, 'nope') end, 'clip')
end)

test('set delegates drawing and playback to the current clip', function()
    local a, b = four(0.1), four(0.1)
    local set = desAnim8.newSet({ a = a, b = b }, 'a')
    for i = #drawCalls, 1, -1 do drawCalls[i] = nil end
    set:update(0.1); set:draw(5, 6)
    eq(drawCalls[1][2], a.frames[2]); eq(a.currentFrame, 2); eq(b.currentFrame, 1)
    eq(set:getFrameInfo(1, 2), a.frames[2])
    set:pause(); eq(a.status, 'paused'); eq(set:isPaused(), true)
    eq(set:getFrameCount(), 4)
    set:setPhase(0.5); near(set:getPhase(), 0.5)
end)

test('newSetFromAseprite builds one clip per tag', function()
    local set = desAnim8.newSetFromAseprite(ASE, IMG)
    local _, name = set:getCurrent()
    eq(name, 'idle')
    set:play('run')
    eq(set:getCurrent():getPlayMode(), 'bounce')
    local pick = desAnim8.newSetFromAseprite(ASE, IMG, { initial = 'back' })
    eq(select(2, pick:getCurrent()), 'back')
end)

test('composite keeps layers in phase and mirrors offsets when flipped', function()
    local body, weapon = four(0.1), four(0.2)
    local c = desAnim8.newComposite({ { anim = body }, { anim = weapon, dx = 5, dy = 2 } })
    c:update(0.15)
    eq(body.currentFrame, 2); eq(weapon.currentFrame, 2)
    near(weapon:getPhase(), body:getPhase())
    for i = #drawCalls, 1, -1 do drawCalls[i] = nil end
    c:draw(10, 20)
    eq(#drawCalls, 2)
    eq(drawCalls[1][3], 10); eq(drawCalls[2][8], -5); eq(drawCalls[2][9], -2)
    c:flipH()
    eq(body.flippedH, true); eq(weapon.flippedH, true)
    for i = #drawCalls, 1, -1 do drawCalls[i] = nil end
    c:draw(10, 20)
    eq(drawCalls[2][8], 16 - 5, 'offset mirrored: flip of origin 5')
    c:setHidden(2, true)
    for i = #drawCalls, 1, -1 do drawCalls[i] = nil end
    c:draw(10, 20); eq(#drawCalls, 1)
    throws(function() desAnim8.newComposite({}) end, 'layers')
    throws(function() c:setHidden(9, true) end, 'layer')
end)

test('keyframe transforms: stepped, interpolated, mirrored by flips', function()
    local data = {
        [1] = { transform = { x = 0 } },
        [2] = { transform = { x = 10, r = 0.5, sx = 2 } },
    }
    local a = desAnim8.newAnimation(grid()('1-4', 1), 0.1, 'loop', { data = data })
    local function info() local _, _, _, r, sx, _, ox = a:getFrameInfo(0, 0); return r, sx, ox end
    a:update(0.1)
    local r, sx, ox = info()
    near(r, 0.5); near(sx, 2); near(ox, -10, 'local x offset becomes a negative origin shift')
    a:flipH()
    r, sx, ox = info()
    near(r, -0.5, 'single flip reverses rotation'); near(sx, -2); near(ox, 6, 'mirrored origin: 16 - 10')
    a:flipV()
    r = info(); near(r, 0.5, 'both flips restore the rotation sign')
    a:flipH():flipV()

    a:reset(); a:setInterpolation(true)
    a:update(0.05)
    near(a:getFrameProgress(), 0.5)
    r, sx, ox = info()
    near(ox, -5); near(r, 0.25); near(sx, 1.5)
    a:gotoFrame(4)
    r, sx, ox = info()
    near(ox, 0, 'frame 4 has no transform and blends to frame 1')
    throws(function() desAnim8.newAnimation(grid()('1-4', 1), 0.1, 'loop', { data = { [1] = { transform = { x = 'a' } } } }) end, 'transform')
end)

test('batch matches individual animations over random dt', function()
    local rng = lcg()
    local frames = grid()('1-4', 1)
    local durations = { 0.1, 0.2, 0.1, 0.3 }
    for _, mode in ipairs({ 'loop', 'once', 'bounce', 'bounceOnce' }) do
        local b = desAnim8.newBatch(IMG, frames, durations, mode, 8)
        local ids, anims = {}, {}
        for i = 1, 3 do
            ids[i] = b:add(i * 10, 0)
            anims[i] = desAnim8.new(IMG, frames, durations, mode)
            b:setPhase(ids[i], 0.1 * i); anims[i]:setPhase(0.1 * i)
        end
        b:setSpeed(ids[2], 2); anims[2]:setSpeed(2)
        for step = 1, 200 do
            local dt = rng() * 0.3
            b:update(dt)
            for i = 1, 3 do
                anims[i]:update(dt)
                eq(b:getFrame(ids[i]), anims[i].currentFrame, mode .. ' entry ' .. i .. ' step ' .. step)
            end
        end
    end
end)

test('batch rewrites only entries whose frame changed', function()
    local b = desAnim8.newBatch(IMG, grid()('1-4', 1), 0.1, 'loop', 4)
    local id = b:add(1, 2)
    local sb = b._batch
    eq(sb.calls[1][1], 'add')
    local before = #sb.calls
    b:update(0.05)
    eq(#sb.calls, before, 'same frame, nothing written')
    b:update(0.06)
    eq(#sb.calls, before + 1)
    eq(sb.calls[#sb.calls][1], 'set'); eq(sb.calls[#sb.calls][2], id)
    b:set(id, 7, 8)
    b:update(0.001)
    eq(sb.calls[#sb.calls][4], 7, 'moved entry is flushed')
end)

test('batch: remove frees the slot, flips, capacity, draw', function()
    local b = desAnim8.newBatch(IMG, grid()('1-4', 1), 0.1, 'loop', 2)
    local a1, a2 = b:add(0, 0), b:add(0, 0)
    eq(b:getCount(), 2)
    throws(function() b:add(0, 0) end, 'capacity')
    b:remove(a1)
    eq(b:getCount(), 1)
    local sb = b._batch
    local last = sb.calls[#sb.calls]
    eq(last[1], 'set'); eq(last[2], a1); eq(last[7], 0, 'zero scale hides the sprite')
    eq(b:add(3, 4), a1, 'slot reused')
    b:setFlip(a2, true, false)
    last = sb.calls[#sb.calls]
    eq(last[7], -1, 'flipped sx')
    for i = #drawCalls, 1, -1 do drawCalls[i] = nil end
    b:draw()
    eq(drawCalls[1][1], sb)
    b:clear(); eq(b:getCount(), 0)
    throws(function() b:getFrame(99) end, 'entry')
end)

test('watcher reports modification time changes', function()
    local mtimes = { ['a.json'] = 100 }
    local stat = function(path) return mtimes[path] end
    local fired = {}
    local w = desAnim8.newWatcher('a.json', function(path) fired[#fired + 1] = path end, stat)
    eq(w:poll(), false, 'first poll only records the baseline')
    eq(w:poll(), false)
    mtimes['a.json'] = 200
    eq(w:poll(), true); eq(fired[1], 'a.json')
    eq(w:poll(), false)
    mtimes['a.json'] = nil
    eq(w:poll(), false, 'missing file is not a change')
    mtimes['a.json'] = 300
    eq(w:poll(), true)
    throws(function() desAnim8.newWatcher('x', 'nope') end, 'function')
end)

-- ── Report────────────────────────────────────────────────────────────────────

if #failures > 0 then
    io.write(('%d passed, %d failed\n\n'):format(passed, #failures))
    for _, f in ipairs(failures) do io.write('FAIL ', f, '\n') end
    os.exit(1)
end
io.write(('%d passed, 0 failed\n'):format(passed))
