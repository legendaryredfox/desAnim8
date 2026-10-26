-- desAnim8 showcase. Run from the repository root:  love examples/showcase
-- Keys: left/right move and turn, space hit (flash + freeze), up/down speed,
--       t trail, o onion skin, b crowd (batch), mouse over the bar scrubs.
package.path = love.filesystem.getSource() .. '/../../?.lua;' .. package.path
local desAnim8 = require 'desAnim8'

local FRAME, FRAMES = 32, 6

-- Draws a small blob into an ImageData so the example needs no art assets.
local function makeSheet()
    local data = love.image.newImageData(FRAME * FRAMES, FRAME * 2)
    for row = 0, 1 do
        for i = 0, FRAMES - 1 do
            local t = i / FRAMES * math.pi * 2
            local squash = math.sin(t) * 3
            local lean = row == 1 and math.sin(t) * 3 + 2 or 0
            local cx, cy = i * FRAME + FRAME / 2 + lean, row * FRAME + FRAME - 12 - squash / 2
            local rx, ry = 10 + squash, 9 - squash
            for y = 0, FRAME - 1 do
                for x = 0, FRAME - 1 do
                    local px, py = i * FRAME + x, row * FRAME + y
                    local d = ((px - cx) / rx) ^ 2 + ((py - cy) / ry) ^ 2
                    if d <= 1 then
                        local shade = 0.55 + 0.4 * (1 - d)
                        data:setPixel(px, py, 0.2 * shade, 0.8 * shade, 0.5 * shade, 1)
                    end
                    local eyeY = cy - 2
                    if math.abs(py - eyeY) < 1.5 and (math.abs(px - (cx - 3 + lean / 2)) < 1.5 or math.abs(px - (cx + 3 + lean / 2)) < 1.5) then
                        data:setPixel(px, py, 0.05, 0.1, 0.1, 1)
                    end
                end
            end
        end
    end
    return love.graphics.newImage(data)
end

local image, grid, hero, crowd
local x, y = 320, 240
local showCrowd, trailOn, tick = false, false, 0
local log = {}

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    image = makeSheet()
    grid = desAnim8.newGrid(FRAME, FRAME, image:getWidth(), image:getHeight())

    local idle = desAnim8.new(image, grid('1-6', 1), 0.14, 'bounce')
    local run = desAnim8.new(image, grid('1-6', 2), 0.07)
    local hit = desAnim8.new(image, grid('3-5', 1), 0.06, 'once')
    run:onFrame(2, function() tick = tick + 1 end)
    hero = desAnim8.newSet({ idle = idle, run = run, hit = hit }, 'idle')
    hero:setPixelSnap(true)

    crowd = desAnim8.newBatch(image, grid('1-6', 2), 0.07, 'loop', 400)
    for i = 1, 200 do crowd:add(math.random(0, 600), math.random(40, 330), 0, 1, 1) end
    crowd:randomizePhases()
end

local function say(text)
    table.insert(log, 1, text)
    log[6] = nil
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
    if key == 'space' then
        hero:play('hit'):queue('idle')
        hero:getCurrent():flash(0.15, 1, 0.4, 0.4):freeze(0.05)
        say('hit: flash + hit-stop, then back to idle')
    elseif key == 't' then
        trailOn = not trailOn
        for _, name in ipairs({ 'idle', 'run', 'hit' }) do
            hero:getClip(name):setTrail(trailOn and 4 or nil, 2, 0.5)
        end
        say(trailOn and 'trail on' or 'trail off')
    elseif key == 'o' then
        hero:getCurrent():setOnion(1, 1)
        say('onion skin on (current clip)')
    elseif key == 'b' then
        showCrowd = not showCrowd
    elseif key == 'up' or key == 'down' then
        local clip = hero:getCurrent()
        clip:setSpeed(clip:getSpeed() + (key == 'up' and 0.25 or -0.25))
        say(('speed %.2f'):format(clip:getSpeed()))
    end
end

function love.update(dt)
    local dx = (love.keyboard.isDown('right') and 1 or 0) - (love.keyboard.isDown('left') and 1 or 0)
    x = x + dx * 120 * dt
    local _, name = hero:getCurrent()
    if name ~= 'hit' then
        hero:play(dx ~= 0 and 'run' or 'idle')
    end
    if dx ~= 0 then hero:faceTowards(dx) end
    hero:update(dt)
    if showCrowd then crowd:update(dt) end

    if os.getenv('DESANIM8_DEMO_QUIT') and love.timer.getTime() > 1 then love.event.quit() end
end

function love.draw()
    love.graphics.clear(0.1, 0.12, 0.16)
    if showCrowd then crowd:draw() end
    love.graphics.setColor(1, 1, 1)
    hero:draw(x, y, 0, 4, 4, FRAME / 2, FRAME - 4)
    hero:getCurrent():drawBounds(x, y, 0, 4, 4, FRAME / 2, FRAME - 4)

    desAnim8.debug.drawTimeline(hero:getCurrent(), 20, 330, 600, 14)
    if love.mouse.isDown(1) then
        desAnim8.debug.scrub(hero:getCurrent(), love.mouse.getX(), love.mouse.getY(), 20, 330, 600, 14)
    end

    love.graphics.print(('clip %s  frame %d  phase %.2f  run ticks %d  fps %d'):format(
        select(2, hero:getCurrent()), hero:getCurrentFrameNumber(), hero:getPhase(), tick, love.timer.getFPS()), 10, 10)
    for i, line in ipairs(log) do love.graphics.print(line, 10, 10 + 16 * i) end
end
