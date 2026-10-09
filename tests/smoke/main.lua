-- Real-LÖVE smoke test: renders to a canvas and checks pixel extents, which the
-- mocked unit tests cannot do. Run from the repository root:
--   xvfb-run -a love tests/smoke
package.path = love.filesystem.getSource() .. '/../../?.lua;' .. package.path
local desAnim8 = require 'desAnim8'

local failures = 0
local function check(name, ok, detail)
    print((ok and 'ok   ' or 'FAIL ') .. name .. (detail and ('  ' .. detail) or ''))
    if not ok then failures = failures + 1 end
end

-- Width and height of the opaque area, anchored at the canvas origin.
local function extent(canvas)
    local data = canvas:newImageData()
    local mx, my = 0, 0
    for y = 0, data:getHeight() - 1 do
        for x = 0, data:getWidth() - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0 then mx, my = math.max(mx, x + 1), math.max(my, y + 1) end
        end
    end
    return mx, my
end

function love.load()
    local ok, err = pcall(function()
        local data = love.image.newImageData(64, 16)
        data:mapPixel(function() return 1, 1, 1, 1 end)
        local image = love.graphics.newImage(data)
        local canvas = love.graphics.newCanvas(200, 200)
        local function render(fn)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 0)
            fn()
            love.graphics.setCanvas()
            return extent(canvas)
        end

        local grid = desAnim8.newGrid(16, 16, 64, 16)
        local anim = desAnim8.new(image, grid('1-4', 1), 0.1)

        local w, h = render(function() anim:draw(0, 0, 0, 3) end)
        check('uniform scale 3 draws 48x48', w == 48 and h == 48, w .. 'x' .. h)

        anim:flipH()
        w, h = render(function() anim:draw(0, 0, 0, 3) end)
        check('flipH keeps uniform scale 3 (48x48)', w == 48 and h == 48, w .. 'x' .. h)
        anim:flipH():flipV()
        w, h = render(function() anim:draw(0, 0, 0, 3) end)
        check('flipV keeps uniform scale 3 (48x48)', w == 48 and h == 48, w .. 'x' .. h)
        anim:flipV()

        local free = desAnim8.newAnimation(grid('1-4', 1), 0.1)
        w, h = render(function() free:draw(image, 0, 0) end)
        check('image-less draw', w == 16 and h == 16, w .. 'x' .. h)

        check('draw without image raises a desAnim8 error',
            not pcall(free.draw, free, 10, 20))

        local border = desAnim8.newGrid(16, 16, 341, 18, 0, 0, 1)
        check('border grid column count', border.cols == 20, tostring(border.cols))
    end)
    if not ok then print('FAIL error: ' .. tostring(err)); failures = failures + 1 end
    print(failures == 0 and 'smoke: all passed' or ('smoke: ' .. failures .. ' failed'))
    love.event.quit(failures == 0 and 0 or 1)
end
