-- Unit tests for desAnim8. Plain Lua, no dependencies.
-- Run from the repository root: luajit tests/run.lua
-- DESANIM8_BUNDLE=dist/desAnim8.lua runs them against the single-file build.
local root = (arg and arg[0] or ''):match('^(.*)/tests/[^/]*$') or '.'
local h = dofile(root .. '/tests/helpers.lua')

local SPECS = {
    'grid', 'construction', 'timing', 'events', 'core', 'frameinfo', 'render', 'state', 'import',
    'composition', 'fuzz',
}

for _, name in ipairs(SPECS) do
    assert(loadfile(root .. '/tests/spec/' .. name .. '.lua'))(h)
end

local results = h.results
if #results.failures > 0 then
    io.write(('%d passed, %d failed\n\n'):format(results.passed, #results.failures))
    for _, failure in ipairs(results.failures) do io.write('FAIL ', failure, '\n') end
    os.exit(1)
end
io.write(('%d passed, 0 failed\n'):format(results.passed))
