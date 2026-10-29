-- Timing model: durations, play-mode sequences, the wrap region, easing and
-- the helpers that turn a timer into a frame. Internal: not part of the public API.
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local parseRange, seekIndex = util.parseRange, util.seekIndex

local function assertDuration(dur, what, level)
    if type(dur) ~= 'number' or not (dur > 0) or dur == math.huge then
        error(('%s must be a positive number, got %s'):format(what, tostring(dur)), level)
    end
end

-- durations can be:
--   number              -> same duration for every frame
--   {d1, d2, ...}       -> per-frame array
--   {['2-4'] = 0.2, ..} -> range-keyed table
local function parseDurations(durations, frameCount, level)
    if type(durations) == 'number' then
        assertDuration(durations, 'frameDuration', level + 1)
        local t = {}
        for i = 1, frameCount do t[i] = durations end
        return t
    end
    if type(durations) ~= 'table' then
        error('durations must be a positive number or a table', level)
    end
    local result = {}
    for key, dur in pairs(durations) do
        assertDuration(dur, ('duration for key %q'):format(tostring(key)), level + 1)
        local from, to, step = parseRange(key, frameCount, level + 1, 'durations key')
        for k = from, to, step do
            if result[k] then
                error(('durations: frame %d is assigned more than once (key %q)'):format(k, tostring(key)), level)
            end
            result[k] = dur
        end
    end
    for i = 1, frameCount do
        if not result[i] then error(('no duration specified for frame %d'):format(i), level) end
    end
    return result
end

local function buildIntervals(durations)
    local t, intervals = 0, { 0 }
    for i = 1, #durations do
        t = t + durations[i]
        intervals[i + 1] = t
    end
    return intervals, t
end

local VALID_MODES  = { loop=true, once=true, bounce=true, bounceOnce=true, random=true }
local PAUSE_AT_END = { once=true, bounceOnce=true }
local MODE_LIST    = "'loop', 'once', 'bounce', 'bounceOnce' or 'random'"

local DEFAULT_RANDOM_LENGTH = 32

-- Expand play mode into a flat sequence of frame indices:
--   loop/once      -> [1, 2, ..., n]
--   bounce         -> [1, 2, ..., n, n-1, ..., 2]   endpoints appear once
--   bounceOnce     -> [1, 2, ..., n, n-1, ..., 1]
local function buildSequence(n, playMode)
    if n == 1 then return { 1 } end
    local seq = {}
    if playMode == 'loop' or playMode == 'once' then
        for i = 1, n do seq[i] = i end
    elseif playMode == 'bounce' then
        for i = 1, n         do seq[#seq + 1] = i end
        for i = n - 1, 2, -1 do seq[#seq + 1] = i end
    else -- bounceOnce
        for i = 1, n         do seq[#seq + 1] = i end
        for i = n - 1, 1, -1 do seq[#seq + 1] = i end
    end
    return seq
end

-- Weighted pick of a frame index, skipping up to two excluded frames.
local function pickRandom(n, weights, rng, skipA, skipB)
    local total = 0
    for i = 1, n do
        if i ~= skipA and i ~= skipB then total = total + (weights and weights[i] or 1) end
    end
    if total <= 0 then return nil end
    local r, last = rng() * total, nil
    for i = 1, n do
        if i ~= skipA and i ~= skipB then
            local w = weights and weights[i] or 1
            if w > 0 then
                last = i
                r = r - w
                if r < 0 then return i end
            end
        end
    end
    return last
end

-- A fixed random order generated up front, so the regular sequence machinery
-- (intervals, events, state) works unchanged. No frame repeats back to back,
-- including across the wrap, when the weights allow it.
local function buildRandomSequence(n, length, weights, rng)
    if n == 1 then return { 1 } end
    local seq = { pickRandom(n, weights, rng) }
    for i = 2, length do
        local frame
        if i == length then frame = pickRandom(n, weights, rng, seq[i - 1], seq[1]) end
        seq[i] = frame or pickRandom(n, weights, rng, seq[i - 1])
    end
    return seq
end

-- Loop range support: playback wraps inside [_wrapStart, _wrapEnd], which is the
-- whole sequence unless setLoopRange narrowed it and release() has not been called.
local function applyRegion(self)
    self._plain = nil
    local from, to = self._loopFrom, self._loopTo
    if from and not self._released then
        self._wrapStart, self._wrapEnd = self._intervals[from], self._intervals[to + 1]
        self._wrapFirst, self._wrapLast = from, to
    else
        self._wrapStart, self._wrapEnd = 0, self._totalDuration
        self._wrapFirst, self._wrapLast = 1, #self._seq
    end
end

-- Installs a sequence and derives intervals from the durations. Always assigns
-- new tables, because clones may still share the old ones.
local function applySequence(self, seq)
    local seqDur = {}
    for i, fi in ipairs(seq) do seqDur[i] = self._durations[fi] end
    local intervals, total = buildIntervals(seqDur)
    self._seq           = seq
    self._intervals     = intervals
    self._totalDuration = total
    applyRegion(self)
end

local function applyTiming(self)
    local seq
    if self.playMode == 'random' then
        local o = self._opts
        seq = buildRandomSequence(#self.frames, o.randomLength or DEFAULT_RANDOM_LENGTH,
            o.weights, o.rng or math.random)
    else
        seq = buildSequence(#self.frames, self.playMode)
    end
    applySequence(self, seq)
end

local function initTiming(self)
    applyTiming(self)
    self._timer       = 0
    self._position    = 1
    self._loops       = 0
    self._freeze      = 0
    self._started     = false
    self._released    = false
    applyRegion(self)
    self.currentFrame = self._seq[1]
    self.status       = 'playing'
end

-- Time as seen by the frame lookup: eased and quantized when configured.
local function displayTime(self)
    local t, total = self._timer, self._totalDuration
    local ease = self._ease
    if ease then t = ease(t / total) * total end
    local step = self._step
    if step then t = math.floor(t / step + 1e-9) * step end
    return t
end

-- Recomputes position and frame from the timer. The end of the sequence is a
-- sentinel (timer == total) that always shows the last entry.
local function locate(self)
    if self._timer >= self._totalDuration then
        self._position = #self._seq
    else
        self._position = seekIndex(self._intervals, displayTime(self))
    end
    self.currentFrame = self._seq[self._position]
end

-- Timer whose eased display time reaches `target`: the inverse of the easing,
-- found by bisection, which works because easings never decrease.
local function timerForDisplay(self, target)
    local ease, total = self._ease, self._totalDuration
    if not ease or target <= 0 then return target end
    if target >= total then return total end
    local lo, hi = 0, total
    for _ = 1, 50 do
        local mid = (lo + hi) / 2
        if ease(mid / total) * total >= target then hi = mid else lo = mid end
    end
    return hi
end

-- Timer that displays sequence `position`: its start time, nudged to the first
-- instant the step lets through and mapped back through the easing.
local function timerFor(self, position)
    local intervals = self._intervals
    local target = intervals[position]
    local step = self._step
    if step then
        -- a frame shorter than the step may have no displayable instant, in which
        -- case its start time is kept
        local snapped = math.ceil(target / step - 1e-9) * step
        if snapped < intervals[position + 1] then target = snapped end
    end
    return timerForDisplay(self, target)
end

local EASINGS = {
    linear     = function(t) return t end,
    inQuad     = function(t) return t * t end,
    outQuad    = function(t) return t * (2 - t) end,
    inOutQuad  = function(t) return t < 0.5 and 2 * t * t or 1 - (2 - 2 * t) ^ 2 / 2 end,
    inCubic    = function(t) return t * t * t end,
    outCubic   = function(t) return 1 - (1 - t) ^ 3 end,
    inOutCubic = function(t) return t < 0.5 and 4 * t * t * t or 1 - (2 - 2 * t) ^ 3 / 2 end,
}

-- Validated easing function for a name, a user function or nil (-> nil).
local function resolveEasing(easing, what, level)
    if easing == nil then return nil end
    if type(easing) == 'string' then
        local fn = EASINGS[easing]
        if not fn then error(('%s: unknown easing %q'):format(what, easing), level) end
        return fn
    end
    if type(easing) ~= 'function' then
        error(('%s: expected a name, a function or nil'):format(what), level)
    end
    local previous = -math.huge
    for i = 0, 16 do
        local v = easing(i / 16)
        if type(v) ~= 'number' or v ~= v or v < previous - 1e-9 then
            error(('%s: the function must be monotonic (never decrease) on [0,1]'):format(what), level)
        end
        previous = v
    end
    if math.abs(easing(0)) > 1e-9 or math.abs(easing(1) - 1) > 1e-9 then
        error(('%s: the function must map 0 to 0 and 1 to 1'):format(what), level)
    end
    return function(t)
        local v = easing(t)
        return v < 0 and 0 or v > 1 and 1 or v
    end
end

-- Sequence position `delta` steps away, wrapping only for repeating modes.
local function neighbourPosition(self, delta)
    local n = #self._seq
    local p = self._position + delta
    if p >= 1 and p <= n then return p end
    if PAUSE_AT_END[self.playMode] or self._released then return nil end
    return (p - 1) % n + 1
end

-- How far into the current frame playback is, 0 to 1.
local function frameProgress(self)
    local pos = self._position
    local lo, hi = self._intervals[pos], self._intervals[pos + 1]
    local p = (displayTime(self) - lo) / (hi - lo)
    return p < 0 and 0 or p > 1 and 1 or p
end

-- Global multiplier applied to every animation's update (slow motion, pause menus).
local clock = { scale = 1 }

local function setTimeScale(scale)
    if type(scale) ~= 'number' or not (scale >= 0) or scale == math.huge then
        error(('time scale must be a finite number >= 0, got %s'):format(tostring(scale)), 2)
    end
    clock.scale = scale
end

local function getTimeScale()
    return clock.scale
end

return {
    clock               = clock,
    setTimeScale        = setTimeScale,
    getTimeScale        = getTimeScale,
    VALID_MODES         = VALID_MODES,
    PAUSE_AT_END        = PAUSE_AT_END,
    MODE_LIST           = MODE_LIST,
    EASINGS             = EASINGS,
    parseDurations      = parseDurations,
    buildIntervals      = buildIntervals,
    applyRegion         = applyRegion,
    applySequence       = applySequence,
    applyTiming         = applyTiming,
    initTiming          = initTiming,
    displayTime         = displayTime,
    locate              = locate,
    timerFor            = timerFor,
    timerForDisplay     = timerForDisplay,
    resolveEasing       = resolveEasing,
    neighbourPosition   = neighbourPosition,
    frameProgress       = frameProgress,
}
