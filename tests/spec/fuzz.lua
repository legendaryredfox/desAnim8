-- Randomized checks: a naive reference model for playback (speed, reverse, every
-- play mode) and random API call sequences that must keep the invariants.
local env = ...
local desAnim8, test, eq, near, grid, IMG, lcg = env.desAnim8, env.test, env.eq, env.near, env.grid, env.IMG, env.lcg

-- Reference sequence: the frame order a play mode plays, written independently of
-- the library.
local function referenceSequence(n, mode)
    local seq = {}
    for i = 1, n do seq[#seq + 1] = i end
    if mode == 'bounce' then
        for i = n - 1, 2, -1 do seq[#seq + 1] = i end
    elseif mode == 'bounceOnce' then
        for i = n - 1, 1, -1 do seq[#seq + 1] = i end
    end
    return seq
end

test('fuzz: playback matches a naive model for every mode, speed and direction', function()
    local rng = lcg()
    local function between(lo, hi) return lo + rng() * (hi - lo) end
    local modes = { 'loop', 'once', 'bounce', 'bounceOnce' }
    local compared = 0
    for round = 1, 300 do
        local n = 2 + math.floor(rng() * 5)
        local durations = {}
        for i = 1, n do durations[i] = between(0.02, 0.4) end
        local mode = modes[1 + math.floor(rng() * #modes)]
        local anim = desAnim8.newAnimation(grid()('1-4', 1), 0.1, mode)
        -- the grid only has 4 columns: rebuild with n frames of a wider sheet
        local frames = desAnim8.newGrid(8, 8, 8 * 8, 8)('1-' .. n, 1)
        anim = desAnim8.newAnimation(frames, durations, mode)

        local seq = referenceSequence(n, mode)
        local bounds, total = { 0 }, 0
        for i, f in ipairs(seq) do total = total + durations[f]; bounds[i + 1] = total end
        local finishes = mode == 'once' or mode == 'bounceOnce'

        local speed = (rng() < 0.5 and -1 or 1) * between(0.25, 3)
        anim:setSpeed(speed)
        local t = 0
        if speed < 0 then anim:pauseAtEnd(); anim:resume(); t = total end
        local done = false

        for step = 1, 60 do
            local dt = rng() < 0.1 and between(1, 6) or between(0.001, 0.5)
            anim:update(dt)
            if not done then
                t = t + dt * speed
                if finishes and t >= total and speed > 0 then t, done = total, true
                elseif finishes and t < 0 and speed < 0 then t, done = 0, true
                else t = t % total end
            end
            -- skip the instants where float rounding decides the frame
            local nearBoundary = false
            for _, b in ipairs(bounds) do if math.abs(t - b) < 1e-7 then nearBoundary = true end end
            if not nearBoundary then
                local expected
                if done and speed > 0 then expected = seq[#seq]
                elseif done then expected = seq[1]
                else
                    for i = 1, #seq do
                        if t >= bounds[i] and t < bounds[i + 1] then expected = seq[i]; break end
                    end
                end
                eq(anim.currentFrame, expected,
                    ('round %d (%s, speed %.3f) step %d t=%.6f'):format(round, mode, speed, step, t))
                compared = compared + 1
            elseif done then
                break
            end
        end
    end
    assert(compared > 5000, 'the model compared too little: ' .. compared)
end)

local function invariants(anim, label)
    local n = anim:getFrameCount()
    assert(anim.currentFrame >= 1 and anim.currentFrame <= n and anim.currentFrame == math.floor(anim.currentFrame),
        label .. ': currentFrame ' .. tostring(anim.currentFrame))
    assert(anim.status == 'playing' or anim.status == 'paused', label .. ': status')
    assert(anim._timer >= 0 and anim._timer <= anim._totalDuration, label .. ': timer ' .. tostring(anim._timer))
    assert(anim._position >= 1 and anim._position <= #anim._seq, label .. ': position')
    eq(anim.currentFrame, anim._seq[anim._position], label .. ': frame/position')
    local phase = anim:getPhase()
    assert(phase >= 0 and phase <= 1, label .. ': phase ' .. tostring(phase))
end

test('fuzz: random call sequences keep the animation consistent', function()
    local rng = lcg()
    local function pick(list) return list[1 + math.floor(rng() * #list)] end
    local modes = { 'loop', 'once', 'bounce', 'bounceOnce', 'random' }
    local easings = { 'linear', 'inQuad', 'outQuad', 'inOutQuad', 'inCubic', 'outCubic', 'inOutCubic' }
    local calls = 0

    for round = 1, 250 do
        local n = 2 + math.floor(rng() * 5)
        local frames = desAnim8.newGrid(8, 8, 8 * 8, 8)('1-' .. n, 1)
        local durations = {}
        for i = 1, n do durations[i] = 0.02 + rng() * 0.3 end
        local anim = desAnim8.newAnimation(frames, durations, pick(modes), { rng = rng })
        local log = {}

        local actions = {
            function() anim:update(rng() * 0.6) end,
            function() anim:update(rng() < 0.1 and 5 * rng() or 0.016) end,
            function() anim:pause() end,
            function() anim:resume() end,
            function() anim:reset() end,
            function() anim:stop() end,
            function() anim:pauseAtEnd() end,
            function() anim:pauseAtStart() end,
            function() anim:gotoFrame(1 + math.floor(rng() * anim:getFrameCount())) end,
            function() anim:setPhase(rng()) end,
            function() anim:setSpeed((rng() - 0.5) * 6) end,
            function() anim:freeze(rng() * 0.3) end,
            function() anim:setStep(rng() < 0.5 and nil or 0.01 + rng() * 0.2) end,
            function() anim:setEasing(rng() < 0.3 and nil or pick(easings)) end,
            function() anim:setPlayMode(pick(modes)) end,
            function()
                local d = {}
                for i = 1, anim:getFrameCount() do d[i] = 0.02 + rng() * 0.3 end
                anim:setDurations(d)
            end,
            function()
                if anim:getPlayMode() == 'loop' and anim:getFrameCount() >= 2 then
                    local from = 1 + math.floor(rng() * (anim:getFrameCount() - 1))
                    anim:setLoopRange(from, from + math.floor(rng() * (anim:getFrameCount() - from + 1)))
                end
            end,
            function() if anim._loopFrom then anim:release() end end,
            function() anim:clearLoopRange() end,
            function() anim:flipH() end,
            function() anim:flash(0.05) end,
            function() anim:onFrame(1 + math.floor(rng() * anim:getFrameCount()), function() end) end,
            function() anim:addMarker(rng() * anim:getDuration(), function() end) end,
            function() anim:randomizeStart(rng) end,
            function() anim = anim:clone() end,
            function()
                local state = anim:getState()
                local frame = anim.currentFrame
                anim:update(rng() * 0.2)
                anim:setState(state)
                eq(anim.currentFrame, frame, 'setState restores the frame')
            end,
        }

        for step = 1, 60 do
            local index = 1 + math.floor(rng() * #actions)
            log[#log + 1] = index
            local ok, err = pcall(actions[index])
            if not ok then
                error(('round %d step %d action %d raised: %s\ncalls so far: %s'):format(
                    round, step, index, tostring(err), table.concat(log, ',')), 0)
            end
            invariants(anim, ('round %d step %d (action %d)'):format(round, step, index))
            calls = calls + 1
        end
    end
    assert(calls == 250 * 60)
end)
