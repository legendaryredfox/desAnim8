-- Spritesheet grids: quad lists addressed by column and row.
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local assertPositiveInteger, assertNonNegativeInteger, parseRange = util.assertPositiveInteger, util.assertNonNegativeInteger, util.parseRange

-- The public table, handed over by _bind(); newGrid reads maxImageSize from it.
local root

local Grid = {}
Grid.__index = Grid

-- Advisory limit for constrained targets (PSP textures are at most 512x512).
-- nil disables the check; set it before creating grids.
local sizeWarned = false

-- newGrid(frameWidth, frameHeight, imageWidth, imageHeight [, left, top, border, inset])
-- border: pixel gap around every frame in the spritesheet (default 0). Like
-- anim8, one border precedes the first frame as well as separating frames.
-- inset: pixels trimmed from every side of each frame (default 0, may be
-- fractional) so linear filtering cannot bleed in a neighbouring frame.
local function newGrid(frameWidth, frameHeight, imageWidth, imageHeight, left, top, border, inset)
    assertPositiveInteger(frameWidth,  'frameWidth',  3)
    assertPositiveInteger(frameHeight, 'frameHeight', 3)
    assertPositiveInteger(imageWidth,  'imageWidth',  3)
    assertPositiveInteger(imageHeight, 'imageHeight', 3)
    left, top, border, inset = left or 0, top or 0, border or 0, inset or 0
    assertNonNegativeInteger(left,   'left',   3)
    assertNonNegativeInteger(top,    'top',    3)
    assertNonNegativeInteger(border, 'border', 3)
    if type(inset) ~= 'number' or not (inset >= 0) or inset * 2 >= math.min(frameWidth, frameHeight) then
        error(('inset must be a number in [0, %s), got %s'):format(
            tostring(math.min(frameWidth, frameHeight) / 2), tostring(inset)), 2)
    end
    local limit = root and root.maxImageSize
    if limit and not sizeWarned and (imageWidth > limit or imageHeight > limit) then
        sizeWarned = true
        print(('desAnim8: %sx%s image exceeds maxImageSize %s; split the sheet for this target'):format(
            tostring(imageWidth), tostring(imageHeight), tostring(limit)))
    end
    return setmetatable({
        frameWidth  = frameWidth,
        frameHeight = frameHeight,
        imageWidth  = imageWidth,
        imageHeight = imageHeight,
        left        = left,
        top         = top,
        border      = border,
        inset       = inset,
        _cache      = {},
        cols        = math.max(0, math.floor((imageWidth  - left - border) / (frameWidth  + border))),
        rows        = math.max(0, math.floor((imageHeight - top  - border) / (frameHeight + border))),
    }, Grid)
end

-- getFrames(colRange, rowRange [, colRange, rowRange ...])
-- Each pair selects a rectangle of frames in row-major order.
-- Returns a list of love.graphics.newQuad objects. Identical calls reuse the
-- quads built the first time (each call still gets its own list); see
-- Grid:clearCache.
function Grid:getFrames(...)
    local count = select('#', ...)
    local args  = { ... }
    local parts = {}
    for i = 1, count do parts[i] = tostring(args[i]) end
    local key = table.concat(parts, '|')
    local cached = self._cache[key]
    if cached then
        local copy = {}
        for i = 1, #cached do copy[i] = cached[i] end
        return copy
    end

    local frames = {}
    local fw, fh, bw = self.frameWidth, self.frameHeight, self.border
    local iw, ih     = self.imageWidth, self.imageHeight
    local inset      = self.inset
    local i = 1
    while i <= count do
        local cmin, cmax, cstep = parseRange(args[i],     self.cols, 3, 'column')
        local rmin, rmax, rstep = parseRange(args[i + 1], self.rows, 3, 'row')
        i = i + 2
        for row = rmin, rmax, rstep do
            for col = cmin, cmax, cstep do
                local x = self.left + (col - 1) * (fw + bw) + bw
                local y = self.top  + (row - 1) * (fh + bw) + bw
                frames[#frames + 1] = love.graphics.newQuad(
                    x + inset, y + inset, fw - 2 * inset, fh - 2 * inset, iw, ih)
            end
        end
    end
    if #frames == 0 then error('getFrames: no frames selected', 2) end
    local copy = {}
    for n = 1, #frames do copy[n] = frames[n] end
    self._cache[key] = copy
    return frames
end

-- Drops the memoized quad lists.
function Grid:clearCache()
    self._cache = {}
end

Grid.__call = Grid.getFrames

-- Like newGrid, reading the sheet size from the image.
local function newGridFromImage(image, frameWidth, frameHeight, left, top, border, inset)
    if image == nil or type(image.getDimensions) ~= 'function' then
        error('newGridFromImage: image must be an Image (it needs getDimensions)', 2)
    end
    local iw, ih = image:getDimensions()
    return newGrid(frameWidth, frameHeight, iw, ih, left, top, border, inset)
end

return {
    newGrid          = newGrid,
    newGridFromImage = newGridFromImage,
    _bind            = function(publicTable) root = publicTable end,
}
