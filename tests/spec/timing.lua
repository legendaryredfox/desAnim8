-- Advancing time: update, speed, reverse, loop ranges, time scale, easing, ticks, phase and transport controls.
local env = ...
local desAnim8, test, eq, near, throws, seqString, IMG, grid, four, drawCalls, drawStates, gfxLog, gstate, fakeBatch, lcg, withTimeScale, span, framesWith, viewportXs, ASE, fakeImageData, resetGfx, countLog, clearDraws = env.desAnim8, env.test, env.eq, env.near, env.throws, env.seqString, env.IMG, env.grid, env.four, env.drawCalls, env.drawStates, env.gfxLog, env.gstate, env.fakeBatch, env.lcg, env.withTimeScale, env.span, env.framesWith, env.viewportXs, env.ASE, env.fakeImageData, env.resetGfx, env.countLog, env.clearDraws

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

test('setPlayMode, setDurations and gotoFrame stay consistent while easing or step is active', function()
    local a = four(0.1)
    a:setEasing('inQuad'); a:update(0.3)
    local frame = a.currentFrame
    a:setPlayMode('bounce')
    eq(a.currentFrame, frame, 'play mode change keeps the frame')
    a:update(0.0001); eq(a.currentFrame, frame, 'no jump on the next update')
    a:setDurations(0.2)
    eq(a.currentFrame, frame, 'duration change keeps the frame')
    a:update(0.0001); eq(a.currentFrame, frame)
    assert(a._timer >= 0 and a._timer <= a._totalDuration)

    local s = four(0.1)
    s:setStep(0.25)
    s:gotoFrame(3)      -- 0.2 to 0.3 holds no multiple of 0.25 except 0.25
    eq(s.currentFrame, 3)
    s:gotoFrame(2)      -- 0.1 to 0.2 holds none: the displayed frame follows the timer
    eq(s.currentFrame, s._seq[s._position])
    local shown = s.currentFrame
    s:update(0.0001); eq(s.currentFrame, shown, 'consistent with the next update')
end)

test('easing and time-control validation', function()
    local a = four(0.1)
    throws(function() a:setEasing(5) end, 'name, a function')
    throws(function() a:setEasing(function(t) return t * 0.5 end) end, 'map 0 to 0 and 1 to 1')
    throws(function() a:randomizeStart(function() return 2 end) end, 'rng')
    local t = desAnim8.newAnimation(grid()('1-4', 1), 3, 'loop', { ticks = true })
    throws(function() t:freeze(0.5) end, 'integer')
end)

test('frame lookup is right with many frames (binary search)', function()
    local frames = desAnim8.newGrid(8, 8, 8 * 16, 8)('1-16', 1)
    local a = desAnim8.newAnimation(frames, 0.1)
    for i = 1, 16 do
        a:setPhase((i - 0.5) / 16)
        eq(a.currentFrame, i, 'middle of frame ' .. i)
        a:gotoFrame(i)
        eq(a.currentFrame, i)
        a:update(0.05)
        eq(a.currentFrame, i, 'half way into frame ' .. i)
    end
end)
