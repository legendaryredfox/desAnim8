-- Real-LÖVE smoke test: renders to a canvas and checks pixel extents, which the
-- mocked unit tests cannot do. Run from the repository root:
--   xvfb-run -a love tests/smoke
package.path = love.filesystem.getSource() .. '/../../?.lua;' .. package.path
-- DESANIM8_BUNDLE=dist/desAnim8.lua tests the single-file build instead.
local bundle = os.getenv('DESANIM8_BUNDLE')
local desAnim8 = bundle and dofile(bundle) or require 'desAnim8'

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

        local batch = love.graphics.newSpriteBatch(image, 4)
        local id = anim:addToBatch(batch, 0, 0)
        anim:update(0.1)
        anim:setInBatch(batch, id, 0, 0)
        w, h = render(function() love.graphics.draw(batch) end)
        check('SpriteBatch add and set through getFrameInfo', w == 16 and h == 16, w .. 'x' .. h)

        local inset = desAnim8.newGrid(16, 16, 64, 16, 0, 0, 0, 0.5)
        local _, _, qw, qh = inset(1, 1)[1]:getViewport()
        check('inset shrinks real quads', qw == 15 and qh == 15, qw .. 'x' .. qh)

        local rev = desAnim8.new(image, grid('1-4', 1), 0.1)
        rev:setSpeed(-1):pauseAtEnd()
        rev:resume()
        rev:update(0.15)
        check('reverse playback with real quads', rev.currentFrame == 3, tostring(rev.currentFrame))

        local hits = 0
        local ev = desAnim8.new(image, grid('1-4', 1), 0.1, 'bounce')
        ev:onFrame(3, function() hits = hits + 1 end)
        for _ = 1, 6 do ev:update(0.1) end
        check('onFrame twice per bounce cycle', hits == 2, tostring(hits))

        local live = desAnim8.new(image, grid('1-4', 1), 0.1)
        live:update(0.25)
        live:setPlayMode('bounce')
        check('setPlayMode keeps the frame', live.currentFrame == 3, tostring(live.currentFrame))

        local quads, frameData = desAnim8.newFramesFromRecords(
            { { x = 0, y = 0, w = 8, h = 8, trimX = 2, trimY = 0, sourceW = 16, sourceH = 16 } }, 64, 16)
        local trimmed = desAnim8.newAnimation(quads, 1, 'loop', { data = frameData })
        w, h = render(function() trimmed:draw(image, 0, 0) end)
        check('trimmed frame is offset by its trim', w == 10 and h == 8, w .. 'x' .. h)
        trimmed:flipH()
        w, h = render(function() trimmed:draw(image, 0, 0) end)
        check('trimmed frame mirrors inside its source frame', w == 14 and h == 8, w .. 'x' .. h)

        local sheet = love.image.newImageData(32, 16)
        for y = 2, 5 do for x = 3, 8 do sheet:setPixel(x, y, 1, 1, 1, 1) end end
        for y = 4, 9 do for x = 20, 25 do sheet:setPixel(x, y, 1, 1, 1, 1) end end
        local bounds = desAnim8.scanBounds(desAnim8.newGrid(16, 16, 32, 16)('1-2', 1), sheet)
        check('scanBounds on real ImageData', bounds[1].x == 3 and bounds[1].w == 6 and bounds[2].x == 4 and bounds[2].h == 6,
            bounds[1].x .. ',' .. bounds[1].w .. ' / ' .. bounds[2].x .. ',' .. bounds[2].h)
        for name, source in pairs(desAnim8.shaders) do
            check('shader compiles: ' .. name, (pcall(love.graphics.newShader, source)))
        end
        local flash = love.graphics.newShader(desAnim8.shaders.whiteFlash)
        local tinted = desAnim8.new(image, grid('1-4', 1), 0.1)
        tinted:setShader(flash, { amount = 1 }):setColor(1, 1, 1, 1)
        w, h = render(function() tinted:draw(0, 0) end)
        check('draw with shader, tint and trail', w == 16 and h == 16, w .. 'x' .. h)
        tinted:setShader(nil):setTrail(2, 1, 0.5)
        render(function() tinted:draw(0, 0); tinted:draw(4, 0) end)
        check('trail keeps ghosts', #tinted:getTrail() == 2, tostring(#tinted:getTrail()))
        local setA = desAnim8.new(image, grid('1-4', 1), 0.1)
        local setB = desAnim8.new(image, grid('1-2', 1), 0.1)
        local set = desAnim8.newSet({ a = setA, b = setB }, 'a')
        set:play('b'):update(0.1)
        w, h = render(function() set:draw(0, 0) end)
        check('set draws the current clip', w == 16 and h == 16 and set:getCurrent() == setB, w .. 'x' .. h)

        local layerA = desAnim8.new(image, grid('1-4', 1), 0.1)
        local layerB = desAnim8.new(image, grid('1-4', 1), 0.2)
        local comp = desAnim8.newComposite({ { anim = layerA }, { anim = layerB, dx = 8, dy = 0 } })
        comp:update(0.15)
        w, h = render(function() comp:draw(0, 0, 0, 1, 1, -8, 0) end)
        check('composite draws offset layers', w == 32 and h == 16, w .. 'x' .. h)

        local kf = desAnim8.newAnimation(grid('1-4', 1), 0.1, 'loop',
            { data = { [1] = { transform = { x = 8 } } } })
        w, h = render(function() kf:draw(image, 0, 0) end)
        check('keyframe transform shifts the sprite', w == 24 and h == 16, w .. 'x' .. h)

        local many = desAnim8.newBatch(image, grid('1-4', 1), 0.1, 'loop', 8)
        many:add(0, 0); many:add(16, 0)
        many:update(0.1)
        w, h = render(function() many:draw() end)
        check('batch draws every entry', w == 32 and h == 16 and many:getCount() == 2, w .. 'x' .. h)

        local stamp = 'desanim8-smoke.txt'
        love.filesystem.write(stamp, 'a')
        local polled = 0
        local watcher = desAnim8.newWatcher(stamp, function() polled = polled + 1 end)
        watcher:poll()
        check('watcher stats a real file', polled == 0 and love.filesystem.getInfo(stamp).modtime ~= nil)
        love.filesystem.remove(stamp)

        local slices = desAnim8.sliceByAlpha(sheet)
        check('sliceByAlpha on real ImageData', #slices == 2 and slices[2].x == 20, tostring(#slices))
    end)
    if not ok then print('FAIL error: ' .. tostring(err)); failures = failures + 1 end
    print(failures == 0 and 'smoke: all passed' or ('smoke: ' .. failures .. ' failed'))
    love.event.quit(failures == 0 and 0 or 1)
end
