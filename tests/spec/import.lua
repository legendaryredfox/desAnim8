-- Atlas adapters, the Aseprite importer and the sheet tools.
local env = ...
local desAnim8, test, eq, near, throws, seqString, IMG, grid, four, drawCalls, drawStates, gfxLog, gstate, fakeBatch, lcg, withTimeScale, span, framesWith, viewportXs, ASE, fakeImageData, resetGfx, countLog, clearDraws = env.desAnim8, env.test, env.eq, env.near, env.throws, env.seqString, env.IMG, env.grid, env.four, env.drawCalls, env.drawStates, env.gfxLog, env.gstate, env.fakeBatch, env.lcg, env.withTimeScale, env.span, env.framesWith, env.viewportXs, env.ASE, env.fakeImageData, env.resetGfx, env.countLog, env.clearDraws

test('atlas adapters: TexturePacker array, hash form, Starling', function()
    local tp = {
        frames = {
            { filename = 'a', frame = { x = 0, y = 0, w = 8, h = 8 }, rotated = false, trimmed = true,
              spriteSourceSize = { x = 2, y = 1, w = 8, h = 8 }, sourceSize = { w = 16, h = 16 } },
        },
        meta = { size = { w = 64, h = 32 } },
    }
    local records, iw, ih = desAnim8.atlas.fromTexturePacker(tp)
    eq(#records, 1); eq(iw, 64); eq(ih, 32)
    eq(records[1].trimX, 2); eq(records[1].trimY, 1); eq(records[1].sourceW, 16); eq(records[1].name, 'a')
    throws(function() desAnim8.atlas.fromTexturePacker({ frames = { a = {} }, meta = {} }) end, 'array')
    local st = desAnim8.atlas.fromStarling({
        { name = 'x', x = 4, y = 5, width = 8, height = 9, frameX = -2, frameY = -1, frameWidth = 16, frameHeight = 16 },
    })
    eq(st[1].x, 4); eq(st[1].w, 8); eq(st[1].trimX, 2); eq(st[1].trimY, 1); eq(st[1].sourceW, 16)
end)

test('aseprite: tags map to frames, durations and play modes', function()
    local idle = desAnim8.newFromAseprite(ASE, IMG, 'idle')
    eq(idle:getFrameCount(), 2); eq(idle:getPlayMode(), 'loop'); near(idle:getDuration(), 0.3)
    eq(idle.image, IMG)
    local run = desAnim8.newFromAseprite(ASE, IMG, 'run')
    eq(run:getPlayMode(), 'bounce'); eq(viewportXs(run), '16,32,48')
    near(run:getDuration(), 0.2 + 0.1 + 0.3 + 0.1)
    local back = desAnim8.newFromAseprite(ASE, IMG, 'back')
    eq(viewportXs(back), '48,32,16,0'); eq(back:getPlayMode(), 'loop')
    near(back:getDuration(), 0.7)
    eq(back._durations[1], 0.3)
    local pr = desAnim8.newFromAseprite(ASE, IMG, 'pr')
    eq(viewportXs(pr), '32,16,0'); eq(pr:getPlayMode(), 'bounce')
    local all = desAnim8.newFromAseprite(ASE, IMG)
    eq(all:getFrameCount(), 4)
    local img = desAnim8.newFromAseprite(ASE, nil, 'idle')
    eq(img.image, nil)
end)

test('aseprite: slices become frame data and pivots', function()
    local run = desAnim8.newFromAseprite(ASE, IMG, 'run')
    local b1 = run:getFrameData('hit', 1)
    eq(b1.x, 1); eq(b1.w, 4)
    eq(run:getFrameData('hit', 2).x, 2)
    eq(run:getFrameData('pivot', 1), nil)
    eq(run:getFrameData('pivot', 2).y, 16)
    eq(run:getFrameData('hit', 3).w, 5)
end)

test('aseprite: decoder callback, errors', function()
    local a = desAnim8.newFromAseprite('JSON TEXT', IMG, 'idle', { decode = function(s)
        eq(s, 'JSON TEXT'); return ASE
    end })
    eq(a:getFrameCount(), 2)
    throws(function() desAnim8.newFromAseprite('JSON TEXT', IMG, 'idle') end, 'decode')
    throws(function() desAnim8.newFromAseprite(ASE, IMG, 'nope') end, 'idle')
    throws(function() desAnim8.newFromAseprite({ frames = { f0 = {} }, meta = {} }, IMG, nil) end, 'Array')
    throws(function() desAnim8.newFromAseprite(5, IMG, 'idle') end, 'source')
    local once = desAnim8.newFromAseprite(ASE, IMG, 'idle', { playMode = 'once' })
    eq(once:getPlayMode(), 'once')
end)

test('scanBounds finds the opaque area of each frame', function()
    local data = fakeImageData(32, 16, { { 3, 2, 6, 4 } })
    local quads = grid()('1-2', 1)
    local g = desAnim8.newGrid(16, 16, 32, 16)
    local b = desAnim8.scanBounds(g('1-2', 1), data)
    eq(b[1].x, 3); eq(b[1].y, 2); eq(b[1].w, 6); eq(b[1].h, 4)
    eq(b[2].w, 0)
    local merged = desAnim8.dataFromLists({ bounds = b })
    eq(merged[1].bounds, b[1])
end)

test('sliceByAlpha finds blobs, merges close ones and orders row-major', function()
    local img = fakeImageData(40, 20, { { 2, 2, 6, 6 }, { 20, 3, 8, 6 }, { 4, 12, 6, 6 }, { 9, 2, 2, 2 } })
    local rects = desAnim8.sliceByAlpha(img)
    eq(#rects, 4)
    eq(rects[1].x, 2); eq(rects[2].x, 9); eq(rects[3].x, 20); eq(rects[4].y, 12)
    local merged = desAnim8.sliceByAlpha(img, { mergeGap = 2 })
    eq(#merged, 3); eq(merged[1].x, 2); eq(merged[1].w, 9)
    local filtered = desAnim8.sliceByAlpha(img, { minSize = 3 })
    eq(#filtered, 3)
    local quads = desAnim8.newQuadsFromRects(filtered, 40, 20)
    eq(#quads, 3)
    local x, y, w, h = quads[1]:getViewport()
    eq(x, 2); eq(w, 6)
end)
