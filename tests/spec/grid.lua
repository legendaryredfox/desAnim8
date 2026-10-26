-- Grid construction, ranges, memoization, inset and the size advisory.
local env = ...
local desAnim8, test, eq, near, throws, seqString, IMG, grid, four, drawCalls, drawStates, gfxLog, gstate, fakeBatch, lcg, withTimeScale, span, framesWith, viewportXs, ASE, fakeImageData, resetGfx, countLog, clearDraws = env.desAnim8, env.test, env.eq, env.near, env.throws, env.seqString, env.IMG, env.grid, env.four, env.drawCalls, env.drawStates, env.gfxLog, env.gstate, env.fakeBatch, env.lcg, env.withTimeScale, env.span, env.framesWith, env.viewportXs, env.ASE, env.fakeImageData, env.resetGfx, env.countLog, env.clearDraws

test('grid: cols and rows without border', function()
    local g = desAnim8.newGrid(16, 16, 64, 32)
    eq(g.cols, 4); eq(g.rows, 2)
end)

test('grid: cols and rows account for border', function()
    -- 20 frames of 16px with a 1px border before each frame = 20*17 + 1 = 341
    local g = desAnim8.newGrid(16, 16, 341, 18, 0, 0, 1)
    eq(g.cols, 20)
    throws(function() g(21, 1) end, 'out of range')
    eq(#g('1-20', 1), 20)
end)

test('grid: cols and rows account for left and top offsets', function()
    local g = desAnim8.newGrid(16, 16, 64, 64, 32, 16)
    eq(g.cols, 2); eq(g.rows, 3)
    throws(function() g(3, 1) end, 'out of range')
end)

test('grid: quad positions with left, top and border', function()
    local g = desAnim8.newGrid(16, 16, 200, 200, 10, 20, 2)
    local f = g('1-2', '1-2')
    eq(#f, 4)
    eq(f[1].x, 12); eq(f[1].y, 22)
    eq(f[2].x, 30); eq(f[2].y, 22)
    eq(f[3].x, 12); eq(f[3].y, 40)
end)

test('grid: ranges, reverse ranges and chained pairs', function()
    local g = grid()
    eq(#g('1-4', '1-2'), 8)
    local rev = g('4-1', 1)
    eq(rev[1].x, 48); eq(rev[4].x, 0)
    eq(#g('1-4', 1, '4-1', 1), 8)
    eq(#g(' 1 - 3 ', 1), 3)
    eq(#g(2, 2), 1)
    eq(#g('2', '2'), 1)
end)

test('grid: invalid ranges raise errors attributed to the caller', function()
    local g = grid()
    throws(function() g('0-2', 1) end, 'out of range', 'zero')
    throws(function() g(5, 1) end, 'out of range', 'too high')
    throws(function() g('a', 1) end, 'invalid', 'letters')
    throws(function() g('3-', 1) end, 'invalid', 'open range')
    throws(function() g('-1', 1) end, 'invalid', 'negative')
    throws(function() g(1.5, 1) end, 'integer', 'fraction')
    throws(function() g('1-2') end, 'row', 'odd argument count')
    throws(function() g() end, 'no frames', 'no arguments')
end)

test('grid: constructor validation', function()
    throws(function() desAnim8.newGrid(0, 16, 64, 32) end, 'frameWidth')
    throws(function() desAnim8.newGrid(16, 16, 64) end, 'imageHeight')
    throws(function() desAnim8.newGrid(16.5, 16, 64, 32) end, 'frameWidth')
    throws(function() desAnim8.newGrid('16', 16, 64, 32) end, 'frameWidth')
    throws(function() desAnim8.newGrid(16, 16, 64, 32, -1) end, 'left')
    throws(function() desAnim8.newGrid(16, 16, 64, 32, 0, 'x') end, 'top')
    throws(function() desAnim8.newGrid(16, 16, 64, 32, 0, 0, 1.5) end, 'border')
end)

test('grid: getFrames memoizes identical calls', function()
    local g = grid()
    local real, n = love.graphics.newQuad, 0
    love.graphics.newQuad = function(...) n = n + 1; return real(...) end
    local ok, err = pcall(function()
        local f1 = g('1-4', 1); eq(n, 4)
        local f2 = g('1-4', 1); eq(n, 4, 'second call builds nothing')
        eq(#f2, 4); eq(f2[1], f1[1])
        assert(f1 ~= f2, 'each call returns its own list')
        f2[1] = nil
        eq(g('1-4', 1)[1], f1[1], 'mutating a returned list does not poison the cache')
        g('1-3', 1); eq(n, 7, 'different arguments miss')
        g:clearCache(); g('1-4', 1); eq(n, 11)
    end)
    love.graphics.newQuad = real
    if not ok then error(err, 0) end
end)

test('grid: failed getFrames calls are not cached', function()
    local g = grid()
    throws(function() g('1-9', 1) end, 'out of range')
    throws(function() g('1-9', 1) end, 'out of range')
end)

test('grid: inset shrinks every quad', function()
    local g = desAnim8.newGrid(16, 16, 64, 32, 0, 0, 0, 0.5)
    local x, y, w, h = g(2, 1)[1]:getViewport()
    eq(x, 16.5); eq(y, 0.5); eq(w, 15); eq(h, 15)
    x, y, w, h = grid()(2, 1)[1]:getViewport()
    eq(x, 16); eq(y, 0); eq(w, 16); eq(h, 16)
    throws(function() desAnim8.newGrid(16, 16, 64, 32, 0, 0, 0, 8) end, 'inset')
    throws(function() desAnim8.newGrid(16, 16, 64, 32, 0, 0, 0, -1) end, 'inset')
end)

test('grid: maxImageSize advisory warns once and is off by default', function()
    local realPrint, lines = print, {}
    print = function(s) lines[#lines + 1] = s end
    local ok, err = pcall(function()
        desAnim8.newGrid(16, 16, 1024, 32)
        eq(#lines, 0, 'off by default')
        desAnim8.maxImageSize = 512
        desAnim8.newGrid(16, 16, 512, 512); eq(#lines, 0, 'at the limit')
        desAnim8.newGrid(16, 16, 1024, 32); eq(#lines, 1)
        desAnim8.newGrid(16, 16, 32, 1024); eq(#lines, 1, 'only once')
    end)
    print = realPrint
    desAnim8.maxImageSize = nil
    if not ok then error(err, 0) end
end)

test('newGridFromImage reads the image size', function()
    local image = { getDimensions = function() return 64, 32 end }
    local g = desAnim8.newGridFromImage(image, 16, 16)
    eq(g.cols, 4); eq(g.rows, 2)
    throws(function() desAnim8.newGridFromImage({}, 16, 16) end, 'image')
end)
