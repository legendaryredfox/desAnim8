-- desAnim8: sprite animation for LÖVE 11.5. This file is the entry point: it
-- assembles the public API from the modules in desAnim8/. Console targets without
-- a working require can use the single-file build in dist/ (see tools/bundle.lua).
local PKG = ... or 'desAnim8'

local desAnim8 = {
    _VERSION     = 'desAnim8 v0.10.0',
    _DESCRIPTION = 'An animation library for LÖVE 11.5 games',
    _URL         = 'https://github.com/legendaryredfox/desAnim8',
    _THANKS      = 'All thanks, recognition and incentives should go to https://github.com/kikito',
    _LICENSE     = [[
      MIT LICENSE

      Copyright (c) 2024 Legendary Redfox

      Permission is hereby granted, free of charge, to any person obtaining a
      copy of this software and associated documentation files (the
      "Software"), to deal in the Software without restriction, including
      without limitation the rights to use, copy, modify, merge, publish,
      distribute, sublicense, and/or sell copies of the Software, and to
      permit persons to whom the Software is furnished to do so, subject to
      the following conditions:

      The above copyright notice and this permission notice shall be included
      in all copies or substantial portions of the Software.

      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
      IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
      CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
      TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
      SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    ]]
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function load(name)
    return require(PKG .. '.' .. name)
end

-- Copies a module's public members into desAnim8; names starting with an
-- underscore are internal and stay behind.
local function merge(api)
    for name, value in pairs(api) do
        if name:sub(1, 1) ~= '_' then desAnim8[name] = value end
    end
end

local grid = load('grid')
grid._bind(desAnim8)      -- newGrid reads desAnim8.maxImageSize
merge(grid)

for _, name in ipairs({
    'constructors', 'atlas', 'sheet', 'set', 'composite', 'batch', 'watcher',
}) do
    merge(load(name))
end

local timing = load('timing')
desAnim8.setTimeScale = timing.setTimeScale
desAnim8.getTimeScale = timing.getTimeScale

desAnim8.debug   = load('debug')
desAnim8.shaders = load('shaders')

return desAnim8
