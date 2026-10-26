-- onLoop, onStart/onEnd, frame callbacks and time markers.
local env = ...
local desAnim8, test, eq, near, throws, seqString, IMG, grid, four, drawCalls, drawStates, gfxLog, gstate, fakeBatch, lcg, withTimeScale, span, framesWith, viewportXs, ASE, fakeImageData, resetGfx, countLog, clearDraws = env.desAnim8, env.test, env.eq, env.near, env.throws, env.seqString, env.IMG, env.grid, env.four, env.drawCalls, env.drawStates, env.gfxLog, env.gstate, env.fakeBatch, env.lcg, env.withTimeScale, env.span, env.framesWith, env.viewportXs, env.ASE, env.fakeImageData, env.resetGfx, env.countLog, env.clearDraws

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

test('hooks reject non-function values and offFrame removes a single callback', function()
    local a = four(0.1)
    a.onLoop = 5
    throws(function() a:update(1) end, 'onLoop')

    local hits = {}
    local b = four(0.1)
    local function one() hits[#hits + 1] = 'one' end
    local function two() hits[#hits + 1] = 'two' end
    b:onFrame(2, one); b:onFrame(2, two)
    b:offFrame(2, one)
    b:update(0.1)
    eq(table.concat(hits, ','), 'two')
    b:offFrame(3)   -- nothing registered: no error
end)

-- update takes a shortcut for plain playback once it has been warmed up. Each of
-- these changes happens after the warm-up and must take effect immediately.
local function warm(anim)
    anim:update(0.01); anim:update(0.01)
    return anim
end

test('plain shortcut: markers, frame callbacks and onStart added or reset after warm-up', function()
    local a, fired = warm(four(0.1)), 0
    a:addMarker(0.05, function() fired = fired + 1 end)
    a:update(0.05)
    eq(fired, 1, 'marker')

    local b, entered = warm(four(0.1)), 0
    b:onFrame(2, function() entered = entered + 1 end)
    b:update(0.1)
    eq(entered, 1, 'frame callback')

    local c, starts = warm(four(0.1)), 0
    c.onStart = function() starts = starts + 1 end
    c:reset()
    c:update(0.01)
    eq(starts, 1, 'onStart after reset')
    warm(c)
    c:pauseAtStart(); c:resume(); c:update(0.01)
    eq(starts, 2, 'onStart after pauseAtStart and resume')

    local d, cleared = warm(four(0.1)), 0
    d:addMarker(0.05, function() cleared = cleared + 1 end)
    d:clearMarkers()
    d:update(0.2)
    eq(cleared, 0, 'cleared markers stay quiet')
end)

test('plain shortcut: speed, freeze, step, easing, loop range and flash set after warm-up', function()
    local a = warm(four(0.1))
    a:setSpeed(2); a:update(0.1)
    eq(a.currentFrame, 3, 'speed')

    local f = warm(four(0.1))
    f:freeze(0.2); f:update(0.1)
    eq(f.currentFrame, 1, 'freeze holds')
    f:update(0.2)
    eq(f.currentFrame, 2, 'freeze runs out and play resumes')
    f:update(0.1); f:update(0.1)
    eq(f.currentFrame, 4, 'and the shortcut works again afterwards')

    local s = warm(four(0.1))
    s:setStep(0.2); s:update(0.15)
    eq(s.currentFrame, 1, 'step')

    local e = warm(four(0.1))
    e:setEasing('inQuad'); e:update(0.2)
    eq(e.currentFrame, 2, 'easing')

    local l = warm(four(0.1))
    l:setLoopRange(2, 3)
    l:update(0.35)
    eq(l.currentFrame, 2, 'loop range wraps back to its start')

    local fl = warm(four(0.1))
    fl:setColor(0.2, 0.4, 0.6, 1)
    fl:flash(0.1, 1, 1, 1)
    clearDraws(); fl:draw(0, 0)
    eq(drawStates[1].color[1], 1, 'flash is on')
    for _ = 1, 5 do fl:update(0.03) end
    clearDraws(); fl:draw(0, 0)
    eq(drawStates[1].color[1], 0.2, 'and runs out through the shortcut path')
end)

test('plain shortcut: a state restore and a clone start from the right flags', function()
    local a = warm(four(0.1))
    a:setSpeed(2)
    local state = a:getState()
    local b = warm(four(0.1))
    b:setState(state)
    b:update(0.1)
    eq(b.currentFrame, 3, 'restored speed applies')

    local c = warm(four(0.1))
    c:addMarker(0.05, function() end)
    local d = c:clone()
    local seen = 0
    d._markers[1].fn = function() seen = seen + 1 end
    warm(d)
    d:reset()
    d:update(0.06)
    eq(seen, 1, 'the clone keeps its markers and does not use a stale shortcut')
end)
