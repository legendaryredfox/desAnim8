-- Sets, composites, batches and the file watcher.
local env = ...
local desAnim8, test, eq, near, throws, seqString, IMG, grid, four, drawCalls, drawStates, gfxLog, gstate, fakeBatch, lcg, withTimeScale, span, framesWith, viewportXs, ASE, fakeImageData, resetGfx, countLog, clearDraws = env.desAnim8, env.test, env.eq, env.near, env.throws, env.seqString, env.IMG, env.grid, env.four, env.drawCalls, env.drawStates, env.gfxLog, env.gstate, env.fakeBatch, env.lcg, env.withTimeScale, env.span, env.framesWith, env.viewportXs, env.ASE, env.fakeImageData, env.resetGfx, env.countLog, env.clearDraws

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

test('composite: shared controls, flips, facing, image-less layers and bad layers', function()
    local body, weapon = four(0.1), four(0.2)
    local c = desAnim8.newComposite({ { anim = body }, { anim = weapon } })
    eq(c:getLayer(2), weapon); eq(c:getLayer(5), nil)
    eq(c:setFlipV(true), c); eq(body.flippedV, true); eq(weapon.flippedV, true); eq(c.flippedV, true)
    c:flipV(); eq(weapon.flippedV, false)
    c:faceTowards(-1); eq(body.flippedH, true)
    c:faceTowards(1); eq(body.flippedH, false)
    c:faceTowards(0); eq(body.flippedH, false)
    throws(function() c:faceTowards('x') end, 'faceTowards')
    c:setPhase(0.5); near(c:getPhase(), 0.5); near(weapon:getPhase(), 0.5)
    c:pause(); eq(c:isPlaying(), false); eq(weapon:isPaused(), true)
    c:resume(); eq(c:isPlaying(), true)
    c:pauseAtEnd(); eq(body.currentFrame, 4)
    c:pauseAtStart(); eq(body.currentFrame, 1)
    c:reset(); c:stop()
    throws(function() desAnim8.newComposite({ {} }) end, 'needs an anim')

    local bare = desAnim8.newAnimation(grid()('1-4', 1), 0.1)
    local c2 = desAnim8.newComposite({ { anim = bare, image = IMG } })
    clearDraws(); c2:draw(1, 2)
    eq(drawCalls[1][1], IMG)
end)

test('batch: random phases, reverse playback, once modes and validation', function()
    local frames = grid()('1-4', 1)
    local b = desAnim8.newBatch(IMG, frames, 0.1, 'loop', 4)
    local first, second = b:add(0, 0), b:add(0, 0)
    b:randomizePhases(function() return 0.6 end)
    eq(b:getFrame(first), 3)
    b:randomizePhases()
    assert(b:getFrame(second) >= 1 and b:getFrame(second) <= 4)

    b:setSpeed(first, -1); b:setPhase(first, 0.1)
    b:update(0.1)
    eq(b:getFrame(first), 4, 'reverse loop wraps to the end')

    local once = desAnim8.newBatch(IMG, frames, 0.1, 'once', 2)
    local id = once:add(0, 0)
    once:setSpeed(id, -1); once:setPhase(id, 0.1)
    once:update(0.5)
    eq(once:getFrame(id), 1, 'reverse once stops on the first frame')
    once:update(0.5); eq(once:getFrame(id), 1)
    once:setPhase(id, 0)
    once:setSpeed(id, 1); once:update(5)
    eq(once:getFrame(id), 4, 'forward once stops on the last frame')

    b:update(0); b:update(-1)
    throws(function() b:setSpeed(first, 'x') end, 'speed')
    throws(function() b:setPhase(first, 'x') end, 'phase')
    throws(function() b:update('x') end, 'dt')
    throws(function() desAnim8.newBatch(IMG, frames, 0.1, 'loop', 0) end, 'capacity')
end)

test('set: style setters reach every clip, getClip, bad clips and Aseprite variants', function()
    local a, b = four(0.1), four(0.1)
    local set = desAnim8.newSet({ a = a, b = b }, 'a')
    eq(set:setColor(1, 0, 0, 1), set)
    eq(a._color[2], 0); eq(b._color[2], 0)
    set:setAlpha(0.5); eq(b._color[4], 0.5)
    eq(set:getClip('b'), b); eq(set:getClip('zz'), nil)
    throws(function() desAnim8.newSet({ x = 5 }) end, 'not an animation')
    throws(function() set:queue('zz') end, 'unknown clip')

    local tagless = { frames = ASE.frames, meta = { size = ASE.meta.size } }
    local s = desAnim8.newSetFromAseprite(tagless, IMG)
    eq(select(2, s:getCurrent()), 'default'); eq(s:getFrameCount(), 4)

    local viaText = desAnim8.newSetFromAseprite('TEXT', IMG, { decode = function(text) eq(text, 'TEXT'); return ASE end })
    eq(select(2, viaText:getCurrent()), 'idle')
    throws(function() desAnim8.newSetFromAseprite('TEXT', IMG) end, 'decode')
end)

test('watcher: the default stat reads love.filesystem.getInfo', function()
    local real = love.filesystem
    local modtime = 5
    love.filesystem = { getInfo = function(path) return path == 'a' and { modtime = modtime } or nil end }
    local ok, err = pcall(function()
        local fired = 0
        local w = desAnim8.newWatcher('a', function() fired = fired + 1 end)
        eq(w:poll(), false)
        modtime = 6
        eq(w:poll(), true); eq(fired, 1)
        eq(desAnim8.newWatcher('missing', function() end):poll(), false)
    end)
    love.filesystem = real
    if not ok then error(err, 0) end
end)
