-- Playback shaping: speed, hit-stop, stepped time, easing, loop ranges, waiting
-- and runtime changes of play mode and durations. Mixed into Animation.
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local timing = require(PKG .. '.timing')
local options = require(PKG .. '.options')
local isInteger = util.isInteger
local VALID_MODES, MODE_LIST = timing.VALID_MODES, timing.MODE_LIST
local parseDurations, applyTiming, applySequence = timing.parseDurations, timing.applyTiming, timing.applySequence
local applyRegion, locate, resolveEasing = timing.applyRegion, timing.locate, timing.resolveEasing
local assertTickDurations = options.assertTickDurations

---@class desAnim8.Animation
local Animation = {}

local function assertSpeedValue(self, v, what)
    if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then
        error(('%s must be a finite number, got %s'):format(what, tostring(v)), 3)
    end
    if self._ticks and v ~= math.floor(v) then
        error(('%s must be an integer in ticks mode, got %s'):format(what, tostring(v)), 3)
    end
end

-- Playback rate: 1 is normal, 2 doubles it, negative plays backwards, 0 holds.
---@param rate number negative plays backwards
---@return desAnim8.Animation
function Animation:setSpeed(rate)
    assertSpeedValue(self, rate, 'setSpeed: speed')
    self._speed = rate
    return self
end

---@return number
function Animation:getSpeed()
    return self._speed
end

-- Sets the speed so one play-through lasts `seconds`; the direction is kept.
---@param seconds number
---@return desAnim8.Animation
function Animation:fitDuration(seconds)
    if self._ticks then error('fitDuration: not available in ticks mode', 2) end
    if type(seconds) ~= 'number' or not (seconds > 0) or seconds == math.huge then
        error(('fitDuration: seconds must be a positive number, got %s'):format(tostring(seconds)), 2)
    end
    self._speed = (self._speed < 0 and -1 or 1) * self._totalDuration / seconds
    return self
end

-- Ignores updates for `seconds` of dt (hit-stop). Leftover dt in the same call
-- advances normally.
---@param seconds number
---@return desAnim8.Animation
function Animation:freeze(seconds)
    if type(seconds) ~= 'number' or not (seconds >= 0) or seconds == math.huge then
        error(('freeze: seconds must be a non-negative number, got %s'):format(tostring(seconds)), 2)
    end
    if self._ticks and seconds ~= math.floor(seconds) then
        error('freeze: seconds must be an integer in ticks mode', 2)
    end
    self._freeze = seconds
    return self
end

-- Quantizes the displayed time to multiples of `seconds` (animating "on twos").
-- nil turns it off.
---@param seconds number?
---@return desAnim8.Animation
function Animation:setStep(seconds)
    if seconds ~= nil and (type(seconds) ~= 'number' or not (seconds > 0) or seconds == math.huge) then
        error(('setStep: step must be a positive number or nil, got %s'):format(tostring(seconds)), 2)
    end
    self._step = seconds
    locate(self)
    return self
end

-- Remaps time across the sequence. `easing` is a name from EASINGS, a function
-- from [0,1] to [0,1] that never decreases, or nil for linear.
---@param easing desAnim8.Easing?
---@return desAnim8.Animation
function Animation:setEasing(easing)
    self._ease = resolveEasing(easing, 'setEasing', 3)
    locate(self)
    return self
end

-- Jumps to a random point of the play-through, to keep crowds out of sync.
---@param rng (fun(): number)?
---@return nil
function Animation:randomizeStart(rng)
    local v = (rng or math.random)()
    if type(v) ~= 'number' or not (v >= 0 and v <= 1) then
        error('randomizeStart: rng must return a number in [0,1]', 2)
    end
    self:setPhase(v)
end

-- Switches the play mode, keeping the current frame where the new sequence has it.
---@param mode desAnim8.PlayMode
---@return desAnim8.Animation
function Animation:setPlayMode(mode)
    if not VALID_MODES[mode] then
        error(('setPlayMode: unknown play mode %s; expected %s'):format(
            type(mode) == 'string' and ('%q'):format(mode) or tostring(mode), MODE_LIST), 2)
    end
    local frame, oldPos = self.currentFrame, self._position
    self.playMode = mode
    self._loopFrom, self._loopTo, self._released = nil, nil, false
    applyTiming(self)
    local seq = self._seq
    local n, found = #seq, 1
    for k = 0, n - 1 do
        local i = (oldPos - 1 + k) % n + 1
        if seq[i] == frame then found = i; break end
    end
    self._position    = found
    self._timer       = self._intervals[found]
    self.currentFrame = seq[found]
    return self
end

-- Replaces the durations (same formats as the constructor) keeping the position
-- and how far into the current frame playback is.
---@param durations desAnim8.Durations
---@return desAnim8.Animation
function Animation:setDurations(durations)
    local fresh = parseDurations(durations, #self.frames, 3)
    if self._ticks then assertTickDurations(fresh, 3) end
    local pos = self._position
    local lo, hi = self._intervals[pos], self._intervals[pos + 1]
    local progress = (self._timer - lo) / (hi - lo)
    self._baseDurations, self._durations = fresh, fresh
    applySequence(self, self._seq)
    local timer = self._intervals[pos] + progress * (self._intervals[pos + 1] - self._intervals[pos])
    self._timer = math.min(timer, self._totalDuration)
    locate(self)
    return self
end

-- Loop frames from..to (loop mode only): playback runs 1..to once, then keeps
-- wrapping back to `from`. release() lets it run on to the end and finish.
---@param from integer
---@param to integer
---@return desAnim8.Animation
function Animation:setLoopRange(from, to)
    if self.playMode ~= 'loop' then error('setLoopRange: only available in loop mode', 2) end
    local n = #self.frames
    if not isInteger(from) or not isInteger(to) or from < 1 or to > n or from > to then
        error(('setLoopRange: range %s-%s invalid for %d frames'):format(tostring(from), tostring(to), n), 2)
    end
    self._loopFrom, self._loopTo, self._released = from, to, false
    applyRegion(self)
    return self
end

---@return desAnim8.Animation
function Animation:clearLoopRange()
    self._loopFrom, self._loopTo, self._released = nil, nil, false
    applyRegion(self)
    return self
end

---@return desAnim8.Animation
function Animation:release()
    if not self._loopFrom then error('release: no loop range set (see setLoopRange)', 2) end
    self._released = true
    applyRegion(self)
    return self
end

-- Inside a coroutine: yields until the animation finishes (once modes) or
-- completes its next loop. Polls once per resume, so it works with any scheduler
-- that resumes the coroutine every frame.
---@return nil
function Animation:wait()
    local co, isMain = coroutine.running()
    if co == nil or isMain then error('wait: must be called inside a coroutine', 2) end
    local start = self._loops
    while not (self:isFinished() or self._loops > start) do coroutine.yield() end
end

return { methods = Animation }
