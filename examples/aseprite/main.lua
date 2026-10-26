-- Aseprite import, end to end. Run from the repository root:  love examples/aseprite
-- hero.json is an "Array" export with frame tags and slices. The image is built in
-- code so the example needs no art assets; with real art you would load the PNG.
-- Keys: 1 idle, 2 run, left/right turn, h toggle the hurtbox, escape quits.
package.path = love.filesystem.getSource() .. '/../../?.lua;' .. package.path .. ';' ..
    love.filesystem.getSource() .. '/?.lua'
local desAnim8 = require 'desAnim8'
local json = require 'json'

local FRAME = 32

-- Eight 32x32 frames: a blob that squashes (idle) or leans (run).
local function makeSheet()
    local data = love.image.newImageData(FRAME * 8, FRAME)
    for i = 0, 7 do
        local running = i >= 4
        local t = i / 4 * math.pi * 2
        local squash, lean = math.sin(t) * 3, running and 3 or 0
        local cx, cy = i * FRAME + FRAME / 2 + lean, FRAME - 14 - squash / 2
        local rx, ry = 10 + squash, 9 - squash
        for y = 0, FRAME - 1 do
            for x = 0, FRAME - 1 do
                local px = i * FRAME + x
                local d = ((px - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2
                if d <= 1 then
                    local shade = 0.55 + 0.4 * (1 - d)
                    data:setPixel(px, y, 0.9 * shade, 0.5 * shade, 0.2 * shade, 1)
                end
            end
        end
    end
    return love.graphics.newImage(data)
end

local hero, showBox = nil, true
local x, y = 320, 250

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    local text = love.filesystem.read('hero.json')          -- the file inside this folder
    hero = desAnim8.newSetFromAseprite(text, makeSheet(), { decode = json.decode, initial = 'idle' })
    hero:setAutoPivot(true)                                  -- origin from the "feet" slice
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
    if key == '1' then hero:play('idle') end
    if key == '2' then hero:play('run') end
    if key == 'left' then hero:setFlipH(true) end
    if key == 'right' then hero:setFlipH(false) end
    if key == 'h' then showBox = not showBox end
end

function love.update(dt)
    hero:update(dt)
    if os.getenv('DESANIM8_DEMO_QUIT') and love.timer.getTime() > 1 then love.event.quit() end
end

function love.draw()
    love.graphics.clear(0.12, 0.12, 0.16)
    love.graphics.setColor(1, 1, 1)
    hero:draw(x, y, 0, 6, 6)
    if showBox then
        love.graphics.setColor(1, 0.3, 0.3)
        local bx, by, bw, bh = hero:getWorldRect('hurtbox', x, y, 6, 6)
        if bx then love.graphics.rectangle('line', bx, by, bw, bh) end
    end
    love.graphics.setColor(1, 1, 1)
    local clip, name = hero:getCurrent()
    love.graphics.print(('clip %s (%s, %d frames)   frame %d   keys: 1 idle  2 run  left/right  h hurtbox'):format(
        name, clip:getPlayMode(), clip:getFrameCount(), clip:getCurrentFrameNumber()), 10, 10)
end
