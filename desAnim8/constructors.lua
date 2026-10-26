-- desAnim8.new, newAnimation and newAnimationFromQuads.
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local build = require(PKG .. '.animation').build
local assertPositiveInteger = util.assertPositiveInteger

local USAGE = 'desAnim8.new: expected (image, frames, durations [, playMode]) or the legacy ' ..
    '(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight [, playMode]); ' ..
    'for an animation without an image use desAnim8.newAnimation(frames, durations [, playMode])'

-- Legacy single-row form. Returns the frame list, durations and play mode.
-- Called from desAnim8.new, so the user's call is 3 frames up (4 from a helper).
local function legacyArgs(...)
    local fw, fh, n, dur, iw, ih, mode = ...
    if type(fw) ~= 'number' or select('#', ...) < 3 then error(USAGE, 3) end
    assertPositiveInteger(fw, 'frameWidth',  4)
    assertPositiveInteger(fh, 'frameHeight', 4)
    assertPositiveInteger(n,  'numFrames',   4)
    assertPositiveInteger(iw, 'imageWidth',  4)
    assertPositiveInteger(ih, 'imageHeight', 4)
    local frames = {}
    for i = 0, n - 1 do
        frames[#frames + 1] = love.graphics.newQuad(i * fw, 0, fw, fh, iw, ih)
    end
    return frames, dur, mode
end

-- New API:    new(image, frames, durations [, playMode [, opts]])
--             frames is a list of Quads, typically from Grid:getFrames()
-- Legacy API: new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight [, playMode])
-- image may be nil: the image is then supplied at draw time (see newAnimation
-- and :draw), so one animation can be reused across several images and the
-- library never has to hold a backend's image handle.
---@param image love.Texture?
---@param ... any frames, durations [, playMode [, opts]] or the legacy single-row arguments
---@return desAnim8.Animation
local function new(image, ...)
    local frames, durations, playMode, opts
    if type((...)) == 'table' then
        frames, durations, playMode, opts = ...
    else
        frames, durations, playMode = legacyArgs(...)
    end
    local anim = build(image, frames, durations, playMode, opts)
    return anim
end

-- Image-less constructor. Equivalent to new(nil, frames, durations, playMode);
-- the image is passed to :draw at render time.
---@param frames love.Quad[]
---@param durations desAnim8.Durations
---@param playMode desAnim8.PlayMode?
---@param opts desAnim8.Options?
---@return desAnim8.Animation
local function newAnimation(frames, durations, playMode, opts)
    local anim = build(nil, frames, durations, playMode, opts)
    return anim
end

-- Same as new(image, frames, durations, playMode), named for hand-made quad
-- lists (non-grid atlases, cropped regions).
---@param image love.Texture?
---@param quads love.Quad[]
---@param durations desAnim8.Durations
---@param playMode desAnim8.PlayMode?
---@param opts desAnim8.Options?
---@return desAnim8.Animation
local function newAnimationFromQuads(image, quads, durations, playMode, opts)
    local anim = build(image, quads, durations, playMode, opts)
    return anim
end

return {
    new                   = new,
    newAnimation          = newAnimation,
    newAnimationFromQuads = newAnimationFromQuads,
}
