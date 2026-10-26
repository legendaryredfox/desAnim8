-- Rough update() cost check. Usage: luajit tests/bench.lua [dist/desAnim8.lua]
-- With a path it benchmarks that single-file build; otherwise the modular source.
local root = (arg and arg[0] or ''):match('^(.*)/tests/[^/]*$') or '.'
package.path = root .. '/?.lua;' .. package.path
local bundle = arg and arg[1]
love = { graphics = { newQuad = function() return { getViewport = function() return 0, 0, 16, 16 end } end } }
local desAnim8 = bundle and dofile(bundle) or require 'desAnim8'
local frames = {}
for i = 1, 8 do frames[i] = love.graphics.newQuad(0, 0, 16, 16, 128, 16) end
local anims = {}
for i = 1, 100 do anims[i] = desAnim8.newAnimation(frames, 0.1) end
local n = 20000
local t0 = os.clock()
for _ = 1, n do
    for i = 1, #anims do anims[i]:update(1 / 60) end
end
local elapsed = os.clock() - t0
io.write(('%d updates in %.3fs (%.0f ns each)\n'):format(n * #anims, elapsed, elapsed / (n * #anims) * 1e9))
