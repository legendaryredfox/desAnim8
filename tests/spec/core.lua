-- Getters and cloning.
local env = ...
local desAnim8, test, eq, near, throws, seqString, IMG, grid, four, drawCalls, drawStates, gfxLog, gstate, fakeBatch, lcg, withTimeScale, span, framesWith, viewportXs, ASE, fakeImageData, resetGfx, countLog, clearDraws = env.desAnim8, env.test, env.eq, env.near, env.throws, env.seqString, env.IMG, env.grid, env.four, env.drawCalls, env.drawStates, env.gfxLog, env.gstate, env.fakeBatch, env.lcg, env.withTimeScale, env.span, env.framesWith, env.viewportXs, env.ASE, env.fakeImageData, env.resetGfx, env.countLog, env.clearDraws

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

test('clone keeps the trail settings but starts without ghosts', function()
    local a = four(0.1)
    a:setTrail(3, 2, 0.4)
    clearDraws()
    a:draw(1, 1); a:draw(2, 2); a:draw(3, 3)
    assert(#a:getTrail() > 0)
    local c = a:clone()
    eq(#c:getTrail(), 0)
    for i = 1, 6 do c:draw(i, i) end
    eq(#c:getTrail(), 3, 'the clone records with the same count')
end)
