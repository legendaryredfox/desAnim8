-- Shared test environment: a mocked love.graphics, the assertion helpers and the
-- fixtures the spec files use. Loaded once by tests/run.lua.
local root = (arg and arg[0] or ''):match('^(.*)/tests/[^/]*$') or '.'
package.path = root .. '/?.lua;' .. package.path

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

local results = { passed = 0, failures = {} }

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        results.passed = results.passed + 1
    else
        results.failures[#results.failures + 1] = name .. '\n    ' .. tostring(err)
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

-- fn must raise an error matching pattern, attributed to the caller (a spec file)
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

-- ── Fixtures ──────────────────────────────────────────────────────────────────

local function fakeBatch()
    local b = { calls = {} }
    function b:add(...) self.calls[#self.calls + 1] = { 'add', ... }; return #self.calls end
    function b:set(...) self.calls[#self.calls + 1] = { 'set', ... } end
    return b
end
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
-- World-space extent of a quad drawn with the returned transform, along one axis.
local function span(pos, scale, origin, size)
    local a, b = pos + scale * (0 - origin), pos + scale * (size - origin)
    return math.min(a, b), math.max(a, b)
end

local function framesWith(records)
    local quads, data = desAnim8.newFramesFromRecords(records, 64, 16)
    return desAnim8.newAnimation(quads, 1, 'loop', { data = data })
end
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

-- Empties the recorded draw calls in place (specs hold their own references).
local function clearDraws()
    for i = #drawCalls, 1, -1 do drawCalls[i] = nil end
    for i = #drawStates, 1, -1 do drawStates[i] = nil end
end

return {
    root = root,
    results = results,
    clearDraws = clearDraws,
    desAnim8 = desAnim8,
    test = test,
    eq = eq,
    near = near,
    throws = throws,
    seqString = seqString,
    IMG = IMG,
    grid = grid,
    four = four,
    drawCalls = drawCalls,
    drawStates = drawStates,
    gfxLog = gfxLog,
    gstate = gstate,
    fakeBatch = fakeBatch,
    lcg = lcg,
    withTimeScale = withTimeScale,
    span = span,
    framesWith = framesWith,
    viewportXs = viewportXs,
    ASE = ASE,
    fakeImageData = fakeImageData,
    resetGfx = resetGfx,
    countLog = countLog,
}
