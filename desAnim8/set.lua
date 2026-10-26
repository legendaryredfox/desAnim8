-- Named clips: a Set plays one animation at a time and switches between them.
local PKG = (...):match('^(.*)%.[^.]*$')
local Animation = require(PKG .. '.animation').Animation
local atlas = require(PKG .. '.atlas')
local newFromAseprite, parseAseprite = atlas.newFromAseprite, atlas._parseAseprite

---@class desAnim8.Set
---@field onChange (fun(set: desAnim8.Set, from: string, to: string))?
local Set = {}
Set.__index = Set

-- newSet(clips [, initial])
-- clips: { name = animation, ... }. `initial` defaults to the first name in
-- alphabetical order. Playback controls act on the current clip; the style setters
-- (setColor, setShader, ...) apply to every clip. Flip state follows the sprite
-- from clip to clip.
---@param clips table<string, desAnim8.Animation>
---@param initial string?
---@return desAnim8.Set
local function newSet(clips, initial)
    if type(clips) ~= 'table' or next(clips) == nil then
        error('newSet: clips must be a non-empty table of name -> animation', 2)
    end
    local self = setmetatable({ _clips = {} }, Set)
    local first
    for name, anim in pairs(clips) do
        if getmetatable(anim) ~= Animation then
            error(('newSet: clip %q is not an animation'):format(tostring(name)), 2)
        end
        self._clips[name] = anim
        if first == nil or tostring(name) < tostring(first) then first = name end
    end
    if initial == nil then initial = first end
    if not self._clips[initial] then
        error(('newSet: unknown clip %q'):format(tostring(initial)), 2)
    end
    self._name, self._cur = initial, self._clips[initial]
    return self
end

-- Switches clip (the new one starts over unless opts.keepPhase carries the
-- current phase across; opts.restart replays the clip that is already current).
-- Clears any queued clip and calls set.onChange(set, from, to) on a change.
---@param name string
---@param opts {keepPhase: boolean?, restart: boolean?}?
---@return desAnim8.Set
function Set:play(name, opts)
    local nextClip = self._clips[name]
    if not nextClip then error(('play: unknown clip %q'):format(tostring(name)), 2) end
    self._queued = nil
    local restart = opts and opts.restart
    if nextClip == self._cur and not restart then return self end
    local prev, prevName = self._cur, self._name
    nextClip.flippedH, nextClip.flippedV = prev.flippedH, prev.flippedV
    local phase = opts and opts.keepPhase and prev:getPhase()
    nextClip:reset()
    if phase then nextClip:setPhase(phase) end
    self._cur, self._name = nextClip, name
    if prevName ~= name and self.onChange then self.onChange(self, prevName, name) end
    return self
end

-- Plays `name` when the current clip finishes (once modes) or completes its
-- current loop (looping modes).
---@param name string
---@return desAnim8.Set
function Set:queue(name)
    if not self._clips[name] then error(('queue: unknown clip %q'):format(tostring(name)), 2) end
    self._queued = name
    return self
end

---@param dt number
function Set:update(dt)
    local clip = self._cur
    local loops = clip._loops
    clip:update(dt)
    local queued = self._queued
    if queued and (clip._loops > loops or clip:isFinished()) then self:play(queued) end
end

-- Returns the current animation and its name.
---@return desAnim8.Animation
---@return string name
function Set:getCurrent()
    return self._cur, self._name
end

---@param name string
---@return desAnim8.Animation?
function Set:getClip(name)
    return self._clips[name]
end

local function passThrough(clip, set, ...)
    if select('#', ...) == 1 and (...) == clip then return set end
    return ...
end

for _, name in ipairs({
    'draw', 'getFrameInfo', 'pause', 'resume', 'pauseAtEnd', 'pauseAtStart', 'stop', 'reset', 'gotoFrame',
    'isPlaying', 'isPaused', 'getCurrentFrame', 'getCurrentFrameNumber', 'getDimensions', 'getFrameCount',
    'getDuration', 'getPlayMode', 'getRemainingTime', 'getPhase', 'setPhase', 'getLoopCount', 'isFinished',
    'flipH', 'flipV', 'setFlipH', 'setFlipV', 'faceTowards', 'setSpeed', 'getSpeed', 'fitDuration', 'freeze',
    'flash', 'getFrameData', 'getWorldRect', 'drawBounds', 'addToBatch', 'setInBatch', 'wait',
    'getFrameProgress',
}) do
    Set[name] = function(self, ...)
        local clip = self._cur
        return passThrough(clip, self, clip[name](clip, ...))
    end
end

for _, name in ipairs({
    'setColor', 'setAlpha', 'setBlendMode', 'setShader', 'setPixelSnap', 'setDefaultFacing', 'setAutoPivot',
}) do
    Set[name] = function(self, ...)
        for _, clip in pairs(self._clips) do clip[name](clip, ...) end
        return self
    end
end

-- One clip per frame tag of an Aseprite export (decoded table, or a JSON string
-- with opts.decode). opts.initial names the starting clip (default: the first
-- tag in the file); the other opts go to newFromAseprite.
---@param source table|string
---@param image love.Texture?
---@param opts table?
---@return desAnim8.Set
local function newSetFromAseprite(source, image, opts)
    local clipOpts, initial, decoded = {}, nil, source
    for k, v in pairs(opts or {}) do
        if k == 'initial' then initial = v else clipOpts[k] = v end
    end
    if type(source) == 'string' then
        if type(clipOpts.decode) ~= 'function' then
            error('newSetFromAseprite: a JSON string needs opts.decode = function(text) returning a table', 2)
        end
        decoded = clipOpts.decode(source)
        clipOpts.decode = nil
    end
    local _, _, _, tags = parseAseprite(decoded, 3)
    local clips = {}
    if #tags == 0 then
        clips.default = newFromAseprite(decoded, image, nil, clipOpts)
        initial = initial or 'default'
    else
        for _, tag in ipairs(tags) do
            clips[tag.name] = newFromAseprite(decoded, image, tag.name, clipOpts)
        end
        initial = initial or tags[1].name
    end
    return newSet(clips, initial)
end

return {
    newSet             = newSet,
    newSetFromAseprite = newSetFromAseprite,
}
