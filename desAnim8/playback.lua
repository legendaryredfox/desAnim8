-- Advancing time and transport controls: update, pause/resume, reset, jumps and
-- the read-only queries. Methods are mixed into the Animation class.
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local timing = require(PKG .. '.timing')
local events = require(PKG .. '.events')
local seekIndex = util.seekIndex
local PAUSE_AT_END, clock = timing.PAUSE_AT_END, timing.clock
local applyRegion, displayTime, locate, timerFor = timing.applyRegion, timing.displayTime, timing.locate, timing.timerFor
local callHook, fireFrames, fireMarkers = events.callHook, events.fireFrames, events.fireMarkers

local Animation = {}

-- True when update can take its shortcut: forward playback at speed 1 with no
-- hooks, markers, freeze, flash, easing, step, loop range or tick mode in play.
-- The answer is cached in _plain, and every method that changes one of those
-- things sets _plain = nil so it is worked out again.
local function isPlain(self)
    return not self._ticks and self._speed == 1 and self._freeze == 0 and self._started
        and not self._onFrame and not self._markers and not self._ease and not self._step
        and not self._flash and self._wrapStart == 0 and self._wrapEnd == self._totalDuration
end

function Animation:update(dt)
    if type(dt) ~= 'number' then
        error(('update: dt must be a number, got %s'):format(type(dt)), 2)
    end
    local plain = self._plain
    if plain == nil then
        plain = isPlain(self)
        self._plain = plain
    end
    if plain and self.status == 'playing' and dt > 0 and dt < math.huge then
        local timer = self._timer + dt * clock.scale
        if timer < self._totalDuration then
            self._timer = timer
            local position = seekIndex(self._intervals, timer)
            self._position, self.currentFrame = position, self._seq[position]
            return
        end
    end
    local ticks = self._ticks
    if ticks and dt ~= math.floor(dt) then
        error(('update: ticks mode needs an integer step, got %s'):format(tostring(dt)), 2)
    end
    local flash = self._flash
    if flash and dt > 0 then
        flash.left = flash.left - dt
        if flash.left <= 0 then
            self._flash = nil
            self._plain = nil
            self._styled = nil
        end
    end
    -- Also rejects NaN, which would otherwise poison the timer permanently.
    if self.status ~= 'playing' or not (dt > 0) or dt == math.huge then return end

    if self._freeze > 0 then
        self._plain = nil
        if dt <= self._freeze then
            self._freeze = self._freeze - dt
            return
        end
        dt = dt - self._freeze
        self._freeze = 0
    end
    -- speed and the time scale are validated finite, so step is never NaN or infinite.
    local step = dt * self._speed
    if not ticks then step = step * clock.scale end
    if step == 0 then return end

    if not self._started then
        self._started = true
        self._plain = nil
        callHook(self, 'onStart')
    end

    local onFrame, markers = self._onFrame, self._markers
    local oldTimer, oldPos = self._timer, self._position
    local timer = oldTimer + step
    local wstart, wend = self._wrapStart, self._wrapEnd
    local reversed, loops = step < 0, 0
    if not reversed then
        if timer >= wend then
            local span = wend - wstart
            loops = math.floor((timer - wstart) / span)
            timer = timer - span * loops
        end
    elseif timer < wstart then
        local span = wend - wstart
        loops = math.ceil((wstart - timer) / span)
        timer = timer + span * loops
    end

    local finished = false
    if loops ~= 0 then
        self._loops = self._loops + loops
        if PAUSE_AT_END[self.playMode] or self._released then
            finished = true
            if reversed then self:pauseAtStart() else self:pauseAtEnd() end
        end
    end
    if not finished then
        self._timer = timer
        if self._ease or self._step then
            self._position = seekIndex(self._intervals, displayTime(self))
        else
            -- timer < wend <= total here, so the end sentinel cannot apply.
            self._position = seekIndex(self._intervals, timer)
        end
        self.currentFrame = self._seq[self._position]
    end

    if onFrame or markers then
        local eventLoops = finished and 0 or loops
        if onFrame then
            fireFrames(self, oldPos, self._position, eventLoops > 2 and 2 or eventLoops, reversed)
        end
        if markers then
            fireMarkers(self, oldTimer, self._timer, eventLoops, reversed)
        end
    end
    if loops ~= 0 then
        callHook(self, 'onLoop', loops)
        if finished then callHook(self, 'onEnd') end
    end
end

-- Advances by whole ticks; for animations built with { ticks = true }.
function Animation:tick(n)
    self:update(n or 1)
end

-- Returns the current 1-based frame index and its Quad.
function Animation:getCurrentFrame()
    return self.currentFrame, self.frames[self.currentFrame]
end

function Animation:getCurrentFrameNumber()
    return self.currentFrame
end

function Animation:getDimensions()
    local _, _, w, h = self.frames[self.currentFrame]:getViewport()
    if self._rotated and self._rotated[self.currentFrame] then return h, w end
    return w, h
end

function Animation:getFrameCount()
    return #self.frames
end

-- Length in seconds of one full play-through. For 'bounce' modes that includes
-- the return trip.
function Animation:getDuration()
    return self._totalDuration
end

function Animation:getPlayMode()
    return self.playMode
end

-- Seconds left until the end of the sequence.
function Animation:getRemainingTime()
    if self._speed < 0 then return self._timer end
    return self._totalDuration - self._timer
end

-- Position inside one play-through, 0 (start) to 1 (end).
function Animation:getPhase()
    return self._timer / self._totalDuration
end

-- Jumps to a position inside one play-through; values outside 0..1 are clamped.
function Animation:setPhase(p)
    if type(p) ~= 'number' or p ~= p then
        error(('setPhase: phase must be a number, got %s'):format(tostring(p)), 2)
    end
    p = math.max(0, math.min(1, p))
    self._timer = p * self._totalDuration
    locate(self)
end

-- Completed play-throughs since construction or reset().
function Animation:getLoopCount()
    return self._loops
end

-- True once a 'once'/'bounceOnce' (or released loop-range) animation has reached
-- its end, which is the start when it plays backwards.
function Animation:isFinished()
    if not (PAUSE_AT_END[self.playMode] or self._released) then return false end
    if self._speed >= 0 then return self._timer >= self._totalDuration end
    return self._timer <= 0 and self.status == 'paused'
end

function Animation:pause()
    self.status = 'paused'
end

-- Does nothing once a 'once'/'bounceOnce' animation has finished (it would only
-- re-fire onLoop); use reset() or gotoFrame() to play it again. A looping
-- animation parked at its end starts over instead.
function Animation:resume()
    local finishMode = PAUSE_AT_END[self.playMode] or self._released
    if self._speed >= 0 then
        if self._timer >= self._totalDuration then
            if finishMode then return end
            self._timer = 0
            locate(self)
        end
    elseif self._timer <= 0 then
        if finishMode then return end
        self._timer = self._totalDuration
        locate(self)
    end
    self.status = 'playing'
end

-- "End" is the last entry of the play sequence: the last frame for loop and
-- once, frame 2 for bounce (the frame before the cycle repeats) and frame 1
-- for bounceOnce.
function Animation:pauseAtEnd()
    self._position    = #self._seq
    self._timer       = self._totalDuration
    self.currentFrame = self._seq[self._position]
    self.status       = 'paused'
end

function Animation:pauseAtStart()
    self._position    = 1
    self._timer       = 0
    self._started     = false
    self._plain       = nil
    self.currentFrame = self._seq[1]
    self.status       = 'paused'
end

-- Alias for pauseAtStart (backward compat).
function Animation:stop()
    self:pauseAtStart()
end

function Animation:reset()
    self._position    = 1
    self._timer       = 0
    self._loops       = 0
    self._freeze      = 0
    self._started     = false
    self._plain       = nil
    self._released    = false
    applyRegion(self)
    self.currentFrame = self._seq[1]
    self.status       = 'playing'
end

function Animation:gotoFrame(n)
    if type(n) ~= 'number' or n ~= math.floor(n) then
        error(('gotoFrame: frame must be an integer, got %s'):format(tostring(n)), 2)
    end
    if n < 1 or n > #self.frames then
        error(('gotoFrame: %d out of range [1,%d]'):format(n, #self.frames), 2)
    end
    for i, fi in ipairs(self._seq) do
        if fi == n then
            self._position    = i
            self._timer       = timerFor(self, i)
            self.currentFrame = n
            -- with setStep a frame shorter than the step cannot be shown: keep
            -- the displayed frame consistent with the timer
            if self._step or self._ease then locate(self) end
            return
        end
    end
end

function Animation:isPlaying()
    return self.status == 'playing'
end

function Animation:isPaused()
    return self.status == 'paused'
end

return { methods = Animation }
