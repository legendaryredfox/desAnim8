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
    throws(function() desAnim8.atlas.fromTexturePacker({ frames = { a = {} }, meta = {} }) end, 'frame "a"')
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
    throws(function() desAnim8.newFromAseprite({ frames = { f0 = {} }, meta = {} }, IMG, nil) end, 'frame "f0"')
    throws(function() desAnim8.newFromAseprite(5, IMG, 'idle') end, 'source')
    local once = desAnim8.newFromAseprite(ASE, IMG, 'idle', { playMode = 'once' })
    eq(once:getPlayMode(), 'once')
end)

local function hashExport(count, reorder)
    local frames, names = {}, {}
    for i = 0, count - 1 do
        local key = ('hero %d.aseprite'):format(i)
        frames[key] = { frame = { x = i * 16, y = 0, w = 16, h = 16 }, duration = 100 + i,
            spriteSourceSize = { x = 0, y = 0, w = 16, h = 16 }, sourceSize = { w = 16, h = 16 } }
        names[#names + 1] = key
    end
    return {
        frames = frames,
        meta = { size = { w = count * 16, h = 16 }, frameTags = { { name = 'all', from = 0, to = count - 1, direction = 'forward' } } },
    }
end

test('hash-form exports: frames sort by name with numbers in numeric order', function()
    local export = hashExport(12)
    local anim = desAnim8.newFromAseprite(export, IMG, 'all')
    eq(anim:getFrameCount(), 12)
    eq(viewportXs(anim), '0,16,32,48,64,80,96,112,128,144,160,176', 'hero 10 follows hero 9')
    near(anim._durations[11], 0.110, 'durations follow the same order')
    local records, iw, ih = desAnim8.atlas.fromAseprite(export)
    eq(records[11].name, 'hero 10.aseprite'); eq(iw, 192); eq(ih, 16)

    local tp = { frames = {
        ['walk_10'] = { frame = { x = 10, y = 0, w = 8, h = 8 } },
        ['walk_2']  = { frame = { x = 2,  y = 0, w = 8, h = 8 } },
        ['walk_02'] = { frame = { x = 3,  y = 0, w = 8, h = 8 } },
        ['walk']    = { frame = { x = 0,  y = 0, w = 8, h = 8 } },
    }, meta = { size = { w = 64, h = 8 } } }
    local recs = desAnim8.atlas.fromTexturePacker(tp)
    eq(recs[1].name, 'walk'); eq(recs[2].name, 'walk_02'); eq(recs[3].name, 'walk_2'); eq(recs[4].name, 'walk_10')
    eq(recs[1].x, 0); eq(recs[4].x, 10)

    local explicit = { frames = { b = { filename = 'a2', frame = { x = 1, y = 0, w = 8, h = 8 } },
                                  a = { filename = 'a10', frame = { x = 2, y = 0, w = 8, h = 8 } } },
                       meta = { size = { w = 8, h = 8 } } }
    eq(desAnim8.atlas.fromAseprite(explicit)[1].name, 'a2', 'an explicit filename wins over the key')
    throws(function() desAnim8.atlas.fromAseprite({ frames = { [2] = {}, [5] = {} }, meta = {} }) end, 'string keys')
end)

local function repeatExport(direction, count)
    return { frames = ASE.frames, meta = { size = ASE.meta.size, frameTags = {
        { name = 't', from = 0, to = 2, direction = direction, ['repeat'] = count },
    } } }
end

test('aseprite: tag repeat plays a finite number of times', function()
    for _, infinite in ipairs({ 0, '0' }) do
        local a = desAnim8.newFromAseprite(repeatExport('forward', infinite), IMG, 't')
        eq(a:getPlayMode(), 'loop'); eq(a.onLoop, nil)
    end
    local a = desAnim8.newFromAseprite(repeatExport('forward'), IMG, 't')
    eq(a:getPlayMode(), 'loop')

    local once = desAnim8.newFromAseprite(repeatExport('forward', '1'), IMG, 't')
    eq(once:getPlayMode(), 'once')
    local pp = desAnim8.newFromAseprite(repeatExport('pingpong', 1), IMG, 't')
    eq(pp:getPlayMode(), 'bounceOnce')
    pp:update(10)
    eq(pp.currentFrame, 1); eq(pp.status, 'paused'); eq(pp:isFinished(), true)

    local three = desAnim8.newFromAseprite(repeatExport('forward', '3'), IMG, 't')
    eq(three:getPlayMode(), 'loop')
    local total = three:getDuration()
    three:update(total * 2 - 0.01)
    eq(three.status, 'playing', 'still in the second play')
    three:update(0.02)
    eq(three.status, 'playing', 'third play started')
    three:update(total - 0.01 + 0.001)
    eq(three.status, 'paused', 'parked after three plays')
    eq(three.currentFrame, 3)
    eq(three:getLoopCount(), 3)

    three:reset(); three:resume()
    three:update(total * 2.5)
    eq(three.status, 'playing', 'reset restarts the count')
    local twin = three:clone()
    twin:update(total * 3)
    eq(twin.status, 'paused', 'a clone keeps the limit')

    local big = desAnim8.newFromAseprite(repeatExport('forward', 2), IMG, 't')
    big:update(total * 50)
    eq(big.status, 'paused'); eq(big.currentFrame, 3, 'a huge dt still parks at the end')

    throws(function() desAnim8.newFromAseprite(repeatExport('forward', -1), IMG, 't') end, 'repeat')
    throws(function() desAnim8.newFromAseprite(repeatExport('forward', 1.5), IMG, 't') end, 'repeat')
    throws(function() desAnim8.newFromAseprite(repeatExport('forward', 'x'), IMG, 't') end, 'repeat')
    local over = desAnim8.newFromAseprite(repeatExport('forward', 2), IMG, 't', { playMode = 'bounce' })
    eq(over:getPlayMode(), 'bounce', 'an explicit playMode still wins')
    eq(over.onLoop, nil, 'and drops the repeat limit')
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

test('aseprite and atlas: size fallback, bad tags, passthrough options, bad input', function()
    local noSize = { frames = ASE.frames, meta = { frameTags = ASE.meta.frameTags } }
    throws(function() desAnim8.newFromAseprite(noSize, IMG, 'idle') end, 'meta.size')
    local sized = { getDimensions = function() return 64, 16 end }
    eq(desAnim8.newFromAseprite(noSize, sized, 'idle'):getFrameCount(), 2, 'size comes from the image')

    local function withTag(tag)
        return { frames = ASE.frames, meta = { size = ASE.meta.size, frameTags = { tag } } }
    end
    throws(function() desAnim8.newFromAseprite(withTag({ name = 'x', from = 2, to = 9, direction = 'forward' }), IMG, 'x') end, 'invalid frame range')
    throws(function() desAnim8.newFromAseprite(withTag({ name = 'x', from = 0, to = 1, direction = 'sideways' }), IMG, 'x') end, 'direction')

    local jittered = desAnim8.newFromAseprite(ASE, IMG, 'idle', { jitter = 0.5, rng = function() return 1 end })
    near(jittered:getDuration(), 0.45, 'constructor options pass through')
    throws(function() desAnim8.newFromAseprite(ASE, IMG, 'idle', { data = {} }) end, 'opts.data')

    eq(#desAnim8.atlas.fromAseprite(ASE), 4)
    throws(function() desAnim8.atlas.fromAseprite(5) end, 'frames list')
    throws(function() desAnim8.atlas.fromAseprite({ frames = {}, meta = {} }) end, 'no frames')
    throws(function() desAnim8.atlas.fromTexturePacker(5) end, 'frames list')
    throws(function() desAnim8.atlas.fromStarling({}) end, 'non%-empty')
    throws(function() desAnim8.newFramesFromRecords({ { x = 'a', y = 0, w = 1, h = 1 } }, 8, 8) end, 'numeric')
end)

test('the Aseprite example: its JSON decoder and export import cleanly', function()
    local json = dofile(env.root .. '/examples/aseprite/json.lua')
    local file = assert(io.open(env.root .. '/examples/aseprite/hero.json', 'rb'))
    local text = file:read('*a')
    file:close()

    local set = desAnim8.newSetFromAseprite(text, IMG, { decode = json.decode, initial = 'idle' })
    local idle, name = set:getCurrent()
    eq(name, 'idle'); eq(idle:getPlayMode(), 'bounce'); eq(idle:getFrameCount(), 4)
    near(idle:getDuration(), 0.12 * 6)
    local run = set:getClip('run')
    eq(run:getPlayMode(), 'loop'); eq(run:getFrameCount(), 4)
    local box = idle:getFrameData('hurtbox')
    eq(box.x, 8); eq(box.w, 16)
    eq(idle:getFrameData('pivot').y, 28)

    -- decoder details the importer relies on
    local decoded = json.decode('{"a":[1,2.5,-3e2,true,false,null,"x\\n\\u0041"],"b":{}}')
    eq(decoded.a[2], 2.5); eq(decoded.a[3], -300); eq(decoded.a[4], true); eq(decoded.a[6], 'x\nA', 'null leaves no hole in an array')
    eq(next(decoded.b), nil)
    local ok = pcall(json.decode, '{"a": }')
    eq(ok, false)
end)
