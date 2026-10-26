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
