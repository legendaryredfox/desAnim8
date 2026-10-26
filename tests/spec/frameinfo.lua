-- getFrameInfo: flips, trim, pivot, per-frame data, transforms and SpriteBatch helpers.
local env = ...
local desAnim8, test, eq, near, throws, seqString, IMG, grid, four, drawCalls, drawStates, gfxLog, gstate, fakeBatch, lcg, withTimeScale, span, framesWith, viewportXs, ASE, fakeImageData, resetGfx, countLog, clearDraws = env.desAnim8, env.test, env.eq, env.near, env.throws, env.seqString, env.IMG, env.grid, env.four, env.drawCalls, env.drawStates, env.gfxLog, env.gstate, env.fakeBatch, env.lcg, env.withTimeScale, env.span, env.framesWith, env.viewportXs, env.ASE, env.fakeImageData, env.resetGfx, env.countLog, env.clearDraws

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

test('getWorldRect honours the auto pivot and trimmed frames', function()
    local quads, data = desAnim8.newFramesFromRecords(
        { { x = 0, y = 0, w = 8, h = 8, trimX = 2, trimY = 0, sourceW = 16, sourceH = 16 } }, 64, 16)
    data[1].hitbox = { x = 4, y = 0, w = 4, h = 4 }
    data[1].pivot = { x = 8, y = 8 }
    local a = desAnim8.newAnimation(quads, 1, 'loop', { data = data })
    a:setAutoPivot(true)
    local x, y, w, h = a:getWorldRect('hitbox', 100, 50)
    eq(x, 96); eq(y, 42); eq(w, 4); eq(h, 4)
    a:flipH()
    x = a:getWorldRect('hitbox', 100, 50)
    eq(x, 100, 'mirrored inside the 16 wide source frame')
end)
