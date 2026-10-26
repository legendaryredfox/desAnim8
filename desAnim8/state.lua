-- Savable playback state. Mixed into Animation.
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local timing = require(PKG .. '.timing')
local isInteger = util.isInteger
local applyRegion, applySequence, locate = timing.applyRegion, timing.applySequence, timing.locate

---@class desAnim8.Animation
local Animation = {}

local STATE_VERSION = 1

-- Plain-table snapshot of the playback state, for save games, replays and
-- rollback. Restore it with setState on an animation built the same way.
---@return table
function Animation:getState()
    local state = {
        v        = STATE_VERSION,
        playMode = self.playMode,
        timer    = self._timer,
        status   = self.status,
        flippedH = self.flippedH,
        flippedV = self.flippedV,
        loops    = self._loops,
        speed    = self._speed,
        freeze   = self._freeze,
        started  = self._started,
        released = self._released,
    }
    if self.playMode == 'random' then
        state.seq = {}
        for i = 1, #self._seq do state.seq[i] = self._seq[i] end
    end
    return state
end

---@param s table
---@return desAnim8.Animation
function Animation:setState(s)
    if type(s) ~= 'table' then error('setState: state must be a table from getState()', 2) end
    if s.v ~= STATE_VERSION then
        error(('setState: unsupported state version %s'):format(tostring(s.v)), 2)
    end
    if s.playMode ~= self.playMode then
        error(('setState: play mode mismatch (state %s, animation %s)'):format(
            tostring(s.playMode), tostring(self.playMode)), 2)
    end
    local seq
    if self.playMode == 'random' then
        if type(s.seq) ~= 'table' or #s.seq == 0 then error('setState: random mode state needs a seq list', 2) end
        seq = {}
        for i = 1, #s.seq do
            local f = s.seq[i]
            if not isInteger(f) or f < 1 or f > #self.frames then
                error(('setState: seq entry %d is not a frame index'):format(i), 2)
            end
            seq[i] = f
        end
    end
    local seqDur
    if seq then
        seqDur = 0
        for i = 1, #seq do seqDur = seqDur + self._durations[seq[i]] end
    end
    local total = seqDur or self._totalDuration
    if type(s.timer) ~= 'number' or not (s.timer >= 0 and s.timer <= total) then
        error(('setState: timer %s outside [0,%s]'):format(tostring(s.timer), tostring(total)), 2)
    end
    if s.status ~= 'playing' and s.status ~= 'paused' then
        error(('setState: invalid status %s'):format(tostring(s.status)), 2)
    end
    if type(s.flippedH) ~= 'boolean' then error('setState: flippedH must be a boolean', 2) end
    if type(s.flippedV) ~= 'boolean' then error('setState: flippedV must be a boolean', 2) end
    if type(s.loops) ~= 'number' or s.loops < 0 or s.loops ~= math.floor(s.loops) then
        error(('setState: loops must be a non-negative integer, got %s'):format(tostring(s.loops)), 2)
    end
    local speed = s.speed == nil and 1 or s.speed
    if type(speed) ~= 'number' or speed ~= speed or speed == math.huge or speed == -math.huge then
        error(('setState: invalid speed %s'):format(tostring(s.speed)), 2)
    end
    local freeze = s.freeze == nil and 0 or s.freeze
    if type(freeze) ~= 'number' or not (freeze >= 0) or freeze == math.huge then
        error(('setState: invalid freeze %s'):format(tostring(s.freeze)), 2)
    end
    local started, released = s.started == true, s.released == true
    if released and not self._loopFrom then
        error('setState: state was released but this animation has no loop range', 2)
    end

    if seq then applySequence(self, seq) end
    self._released = released
    applyRegion(self)
    self._timer    = s.timer
    self.status    = s.status
    self.flippedH  = s.flippedH
    self.flippedV  = s.flippedV
    self._loops    = s.loops
    self._speed    = speed
    self._freeze   = freeze
    self._started  = started
    locate(self)
    return self
end

return { methods = Animation }
