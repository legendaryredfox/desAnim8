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

---@class desAnim8.Animation
local Animation = {}

---@param dt number
---@return nil
function Animation:update(dt)
    if type(dt) ~= 'number' then
        error(('update: dt must be a number, got %s'):format(type(dt)), 2)
    end
    local ticks = self._ticks
    if ticks and dt ~= math.floor(dt) then
        error(('update: ticks mode needs an integer step, got %s'):format(tostring(dt)), 2)
    end
    local flash = self._flash
    if flash and dt > 0 then
        flash.left = flash.left - dt
        if flash.left <= 0 then self._flash = nil end
    end
    -- Also rejects NaN, which would otherwise poison the timer permanently.
    if self.status ~= 'playing' or not (dt > 0) or dt == math.huge then return end

    if self._freeze > 0 then
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
---@param n integer?
---@return nil
function Animation:tick(n)
    self:update(n or 1)
end

-- Returns the current 1-based frame index and its Quad.
---@return integer index
---@return love.Quad quad
function Animation:getCurrentFrame()
    return self.currentFrame, self.frames[self.currentFrame]
end

---@return integer
function Animation:getCurrentFrameNumber()
    return self.currentFrame
end

---@return integer w
---@return integer h
function Animation:getDimensions()
    local _, _, w, h = self.frames[self.currentFrame]:getViewport()
    return w, h
end

---@return integer
function Animation:getFrameCount()
    return #self.frames
end

-- Length in seconds of one full play-through. For 'bounce' modes that includes
-- the return trip.
---@return number seconds
function Animation:getDuration()
    return self._totalDuration
end

---@return desAnim8.PlayMode
function Animation:getPlayMode()
    return self.playMode
end

-- Seconds left until the end of the sequence.
---@return number seconds
function Animation:getRemainingTime()
    if self._speed < 0 then return self._timer end
    return self._totalDuration - self._timer
end

-- Position inside one play-through, 0 (start) to 1 (end).
---@return number phase 0..1
function Animation:getPhase()
    return self._timer / self._totalDuration
end

-- Jumps to a position inside one play-through; values outside 0..1 are clamped.
---@param p number clamped to 0..1
---@return nil
function Animation:setPhase(p)
    if type(p) ~= 'number' or p ~= p then
        error(('setPhase: phase must be a number, got %s'):format(tostring(p)), 2)
    end
    p = math.max(0, math.min(1, p))
    self._timer = p * self._totalDuration
    locate(self)
end

-- Completed play-throughs since construction or reset().
---@return integer
function Animation:getLoopCount()
    return self._loops
end

-- True once a 'once'/'bounceOnce' (or released loop-range) animation has reached
-- its end, which is the start when it plays backwards.
---@return boolean
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
    self._released    = false
    applyRegion(self)
    self.currentFrame = self._seq[1]
    self.status       = 'playing'
end

---@param n integer
---@return nil
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
            self._timer       = timerFor(self, self._intervals[i])
            self.currentFrame = n
            return
        end
    end
end

---@return boolean
function Animation:isPlaying()
    return self.status == 'playing'
end

---@return boolean
function Animation:isPaused()
    return self.status == 'paused'
end

return { methods = Animation }
