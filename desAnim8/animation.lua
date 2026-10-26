-- The Animation class: construction and cloning. Behavior lives in the mixin
-- modules (playback, timeline, events, frameinfo, render, state), merged below.
local PKG = (...):match('^(.*)%.[^.]*$')
local timing = require(PKG .. '.timing')
local options = require(PKG .. '.options')
local VALID_MODES, MODE_LIST = timing.VALID_MODES, timing.MODE_LIST
local parseDurations, initTiming = timing.parseDurations, timing.initTiming
local applyTiming, applyRegion = timing.applyTiming, timing.applyRegion
local checkOptions, assertTickDurations, jittered = options.checkOptions, options.assertTickDurations, options.jittered

-- Instances get their own class table so they do not inherit the module's
-- constructors and metadata.
---@class desAnim8.Animation
---@field status 'playing'|'paused' read only
---@field currentFrame integer 1-based, read only
---@field playMode desAnim8.PlayMode read only
---@field image love.Texture? the bound image
---@field frames love.Quad[] read only
---@field flippedH boolean
---@field flippedV boolean
---@field onLoop (string|fun(anim: desAnim8.Animation, loops: integer))?
---@field onStart (string|fun(anim: desAnim8.Animation))?
---@field onEnd (string|fun(anim: desAnim8.Animation))?
local Animation = {}
Animation.__index = Animation

-- Called from desAnim8.new / newAnimation, so the user's call is 3 frames up.
local function build(image, frames, durations, playMode, opts)
    if type(frames) ~= 'table' then
        error('frames must be a list of quads, e.g. from grid(\'1-4\', 1)', 3)
    end
    if #frames == 0 then error('desAnim8.new: frames list is empty', 3) end
    playMode = playMode or 'loop'
    if not VALID_MODES[playMode] then
        error(('desAnim8.new: unknown play mode %s; expected %s ' ..
            '(callbacks go in the onLoop field: anim.onLoop = fn)'):format(
            type(playMode) == 'string' and ('%q'):format(playMode) or tostring(playMode), MODE_LIST), 3)
    end

    local self = setmetatable({}, Animation)
    self.image    = image
    self.flippedH = false
    self.flippedV = false
    self.onLoop   = nil
    self.playMode = playMode
    -- Copied so later changes to the caller's list cannot desync the timing data.
    self.frames   = {}
    for i = 1, #frames do self.frames[i] = frames[i] end
    self._opts      = checkOptions(opts, #self.frames, 4)
    self._ticks     = self._opts.ticks or false
    self._speed     = 1
    self._baseDurations = parseDurations(durations, #self.frames, 4)
    if self._ticks then assertTickDurations(self._baseDurations, 4) end
    self._durations = self._opts.jitter
        and jittered(self._baseDurations, self._opts.jitter, self._opts.rng or math.random)
        or self._baseDurations

    self._data = self._opts.data
    if self._data then
        for frame, d in pairs(self._data) do
            if d.trim then
                self._trim = self._trim or {}
                self._trim[frame] = d.trim
            end
            if d.transform then
                self._transforms = self._transforms or {}
                self._transforms[frame] = d.transform
            end
        end
    end

    initTiming(self)
    return self
end

-- Returns a new animation sharing the same immutable data (frames, durations,
-- sequence, intervals). Playback state starts fresh; flip, speed, onLoop and
-- registered callbacks are copied. Random-order and jittered animations get
-- their own order and durations.
---@return desAnim8.Animation
function Animation:clone()
    local c = setmetatable({}, Animation)
    for k, v in pairs(self) do c[k] = v end
    if self._onFrame then
        c._onFrame = {}
        for frame, list in pairs(self._onFrame) do
            local copy = {}
            for i = 1, #list do copy[i] = list[i] end
            c._onFrame[frame] = copy
        end
    end
    if self._markers then
        c._markers = {}
        for i, m in ipairs(self._markers) do c._markers[i] = { t = m.t, fn = m.fn } end
    end
    if self._color then c._color = { self._color[1], self._color[2], self._color[3], self._color[4] } end
    if self._trail then
        local t = self._trail
        c._trail = { count = t.count, spacing = t.spacing, alpha = t.alpha, entries = {}, draws = 0 }
    end
    c._flash    = nil
    c._plain    = nil
    c._styled   = nil
    c._timer    = 0
    c._position = 1
    c._loops    = 0
    c._freeze   = 0
    c._started  = false
    c._released = false
    c.status    = 'playing'
    local o = self._opts
    if self.playMode == 'random' or o.jitter then
        if o.jitter then c._durations = jittered(c._baseDurations, o.jitter, o.rng or math.random) end
        applyTiming(c)
    else
        applyRegion(c)
    end
    c.currentFrame = c._seq[1]
    return c
end

for _, name in ipairs({ 'playback', 'timeline', 'events', 'frameinfo', 'render', 'state' }) do
    for method, fn in pairs(require(PKG .. '.' .. name).methods) do Animation[method] = fn end
end

return { Animation = Animation, build = build }
