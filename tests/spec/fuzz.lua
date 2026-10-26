-- Randomized checks: a naive reference model for playback (speed, reverse, every
-- play mode) and random API call sequences that must keep the invariants.
local env = ...
local desAnim8, test, eq, near, grid, IMG, lcg = env.desAnim8, env.test, env.eq, env.near, env.grid, env.IMG, env.lcg
local clearDraws, drawCalls, drawStates = env.clearDraws, env.drawCalls, env.drawStates

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

-- update has a shortcut for plain playback, guarded by the cached _plain flag. B is
-- forced down the general path before every action; both must stay identical, which
-- catches any method that forgets to invalidate the flag.
test('fuzz: the plain-playback shortcut matches the general path', function()
    local rng = lcg()
    local modes = { 'loop', 'once', 'bounce', 'bounceOnce' }
    local easings = { 'inQuad', 'outCubic', 'inOutQuad' }
    local function pick(list) return list[1 + math.floor(rng() * #list)] end
    local shortcuts = 0

    for round = 1, 300 do
        local n = 2 + math.floor(rng() * 5)
        local frames = desAnim8.newGrid(8, 8, 8 * 8, 8)('1-' .. n, 1)
        local durations = {}
        for i = 1, n do durations[i] = 0.02 + rng() * 0.3 end
        local mode = pick(modes)
        local a = desAnim8.newAnimation(frames, durations, mode)
        local b = desAnim8.newAnimation(frames, durations, mode)
        local hits = { [a] = 0, [b] = 0 }
        local function counter(x) return function() hits[x] = hits[x] + 1 end end

        local actions = {
            function(x, p) x:update(p * 0.2) end,
            function(x, p) x:update(p * 0.2) end,
            function(x, p) x:update(p * 0.2) end,
            function(x, p) x:update(p * 0.05) end,
            function(x) x:pause() end,
            function(x) x:resume() end,
            function(x) x:reset() end,
            function(x) x:pauseAtEnd() end,
            function(x) x:pauseAtStart() end,
            function(x, p) x:gotoFrame(1 + math.floor(p * x:getFrameCount())) end,
            function(x, p) x:setPhase(p) end,
            function(x) x:setSpeed(1) end,
            function(x, p) x:setSpeed(p < 0.5 and -1 or 2) end,
            function(x, p) x:freeze(p * 0.1) end,
            function(x) x:setStep(nil) end,
            function(x, p) x:setStep(0.01 + p * 0.1) end,
            function(x) x:setEasing(nil) end,
            function(x, p) x:setEasing(easings[1 + math.floor(p * #easings)]) end,
            function(x) x:flash(0.05) end,
            function(x) x:onFrame(1, counter(x)) end,
            function(x, p) x:addMarker(p * x:getDuration(), counter(x)) end,
            function(x, p) x:addMarker(p * x:getDuration(), counter(x)) end,
            function(x, p) x:addMarker(p * x:getDuration(), counter(x)) end,
            function(x) x:clearMarkers() end,
            function(x, p)
                if x:getPlayMode() == 'loop' and x:getFrameCount() >= 2 then x:setLoopRange(1, 1 + math.floor(p * (x:getFrameCount() - 1))) end
            end,
            function(x) x:clearLoopRange() end,
            function(x) if x._loopFrom then x:release() end end,
            function(x, p) x:setPlayMode(modes[1 + math.floor(p * #modes)]) end,
            function(x) x:setState(x:getState()) end,
        }

        for step = 1, 80 do
            local index = 1 + math.floor(rng() * #actions)
            local p = rng()
            actions[index](a, p)
            actions[index](b, p)
            b._plain = false
            local label = ('round %d step %d action %d'):format(round, step, index)
            eq(a.currentFrame, b.currentFrame, label .. ': frame after the action')
            -- a short update right after: this is where the shortcut can be taken
            a:update(p * 0.03)
            b:update(p * 0.03)
            b._plain = false
            a:update(p * 0.03)
            b:update(p * 0.03)
            if a._plain then shortcuts = shortcuts + 1 end
            b._plain = false
            label = ('round %d step %d action %d'):format(round, step, index)
            eq(a.currentFrame, b.currentFrame, label .. ': frame')
            eq(a._timer, b._timer, label .. ': timer')
            eq(a.status, b.status, label .. ': status')
            eq(a._loops, b._loops, label .. ': loops')
            eq(hits[a], hits[b], label .. ': callbacks fired')
        end
    end
    assert(shortcuts > 500, 'the shortcut was barely exercised: ' .. shortcuts)
end)

-- getFrameInfo and draw also have cached shortcuts (_fancy, _styled). B is forced
-- onto the general paths; both must produce the same quads and draw calls.
test('fuzz: the getFrameInfo and draw shortcuts match the general paths', function()
    local rng = lcg()
    local function chance(p) return rng() < p end
    local function maybe(p, value) if chance(p) then return value end end
    local shortcutDraws = 0
    local shader = { send = function() end }

    for round = 1, 200 do
        local n = 2 + math.floor(rng() * 4)
        local frames = desAnim8.newGrid(8, 8, 8 * 8, 8)('1-' .. n, 1)
        local data = {}
        for i = 1, n do
            data[i] = {
                trim = maybe(0.3, { x = math.floor(rng() * 3), y = math.floor(rng() * 3), w = 12, h = 12 }),
                pivot = maybe(0.3, { x = math.floor(rng() * 8), y = math.floor(rng() * 8) }),
                transform = maybe(0.3, { x = rng() * 4, y = rng() * 4, r = rng(), sx = 1 + rng() }),
            }
        end
        local useData = chance(0.5)
        local function make()
            return desAnim8.new(IMG, frames, 0.1, 'loop', useData and { data = data } or nil)
        end
        local a, b = make(), make()

        local actions = {
            function(x, p) x:update(p * 0.15) end,
            function(x) x:flipH() end,
            function(x) x:flipV() end,
            function(x, p) x:setPixelSnap(p < 0.5) end,
            function(x, p) x:setAutoPivot(p < 0.5) end,
            function(x, p) if p < 0.5 then x:setColor(1, 0.5, 0.5, p) else x:setColor(nil) end end,
            function(x, p) x:setAlpha(p) end,
            function(x, p) x:setBlendMode(p < 0.5 and 'add' or nil) end,
            function(x, p) x:setShader(p < 0.5 and shader or nil) end,
            function(x) x:flash(0.1) end,
            function(x, p) x:setTrail(p < 0.5 and 2 or nil, 1, 0.5) end,
            function(x, p) x:setOnion(p < 0.5 and 1 or 0, p < 0.5 and 1 or 0) end,
            function(x, p) x:setInterpolation(p < 0.5) end,
        }

        for step = 1, 60 do
            local index = 1 + math.floor(rng() * #actions)
            local p = rng()
            actions[index](a, p)
            actions[index](b, p)
            b._fancy, b._styled = true, true
            local label = ('round %d step %d action %d'):format(round, step, index)

            local args = { maybe(0.9, rng() * 100), maybe(0.9, rng() * 100), maybe(0.5, rng()), maybe(0.5, 1 + rng()),
                maybe(0.3, 1 + rng()), maybe(0.5, rng() * 8), maybe(0.5, rng() * 8), maybe(0.2, rng()), maybe(0.2, rng()) }
            local ia = { a:getFrameInfo(args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]) }
            local ib = { b:getFrameInfo(args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]) }
            for k = 1, 10 do eq(ia[k], ib[k], label .. ': getFrameInfo value ' .. k) end

            clearDraws(); a:draw(args[1] or 0, args[2] or 0, args[3], args[4], args[5], args[6], args[7])
            local drawsA, statesA = {}, {}
            for i, call in ipairs(drawCalls) do drawsA[i], statesA[i] = call, drawStates[i] end
            clearDraws(); b:draw(args[1] or 0, args[2] or 0, args[3], args[4], args[5], args[6], args[7])
            eq(#drawCalls, #drawsA, label .. ': number of draw calls')
            for i = 1, #drawsA do
                local sa, sb = statesA[i], drawStates[i]
                for k = 1, 4 do near(sa.color[k], sb.color[k], label .. (': draw %d color %d'):format(i, k)) end
                eq(sa.blend, sb.blend, label .. ': blend')
                eq(sa.shader, sb.shader, label .. ': shader')
                for k = 1, 10 do eq(drawCalls[i][k], drawsA[i][k], label .. (': draw %d value %d'):format(i, k)) end
            end
            if a._styled == false and a._fancy == false then shortcutDraws = shortcutDraws + 1 end
            b._fancy, b._styled = true, true
        end
    end
    assert(shortcutDraws > 100, 'the shortcuts were barely exercised: ' .. shortcutDraws)
end)
