-- Hooks, frame callbacks and time markers. Internal helpers plus the Animation
-- methods that register callbacks.

---@class desAnim8.Animation
local Animation = {}

-- Resolves a hook field that holds a function or the name of a method.
-- Level 3: hook <- callHook <- update <- the user's call.
local function callHook(self, name, ...)
    local cb = self[name]
    if cb == nil then return end
    if type(cb) == 'string' then
        local method = self[cb]
        if type(method) ~= 'function' then
            error(('%s: animation has no method %q'):format(name, cb), 3)
        end
        cb = method
    end
    if type(cb) ~= 'function' then
        error(('%s must be a function or a method name'):format(name), 3)
    end
    cb(self, ...)
end

-- Fires onFrame callbacks for every sequence position entered while moving from
-- oldPos to newPos. Callers pass loops already capped at 2: only the last cycle's
-- worth of entries is reported, so a huge dt cannot flood the callbacks.
local function fireFrames(self, oldPos, newPos, loops, reversed)
    local first, last = self._wrapFirst, self._wrapLast
    local len = last - first + 1
    local steps
    if not reversed then
        steps = loops == 0 and newPos - oldPos
            or (last - oldPos) + (loops - 1) * len + (newPos - first + 1)
    else
        steps = loops == 0 and oldPos - newPos
            or (oldPos - first) + (loops - 1) * len + (last - newPos + 1)
    end
    if steps <= 0 then return end
    local skip = steps > len and steps - len or 0
    local p, seq, cbs = oldPos, self._seq, self._onFrame
    for i = 1, steps do
        if reversed then
            p = p - 1
            if p < first then p = last end
        else
            p = p + 1
            if p > last then p = first end
        end
        if i > skip then
            local frame = seq[p]
            local list = cbs[frame]
            if list then
                for k = 1, #list do
                    local fn = list[k]
                    if fn then fn(self, frame) end
                end
            end
        end
    end
end

local function fireMarkers(self, oldT, newT, loops, reversed)
    local ms = self._markers
    local wstart, wend = self._wrapStart, self._wrapEnd
    for i = 1, #ms do
        local m = ms[i]
        local t = m.t
        local hit
        if not reversed then
            if loops == 0 then hit = t > oldT and t <= newT
            else hit = (t > oldT and t <= wend) or (t >= wstart and t <= newT) end
        else
            if loops == 0 then hit = t < oldT and t >= newT
            else hit = (t < oldT and t >= wstart) or (t <= wend and t >= newT) end
        end
        if hit then m.fn(self, t) end
    end
end

local function checkFrameNumber(self, n, what)
    if type(n) ~= 'number' or n ~= math.floor(n) or n < 1 or n > #self.frames then
        error(('%s: frame must be an integer in [1,%d], got %s'):format(what, #self.frames, tostring(n)), 3)
    end
end

-- Calls fn(anim, frame) every time frame `n` becomes the current frame.
---@param n integer
---@param fn fun(anim: desAnim8.Animation, frame: integer)
---@return desAnim8.Animation
function Animation:onFrame(n, fn)
    checkFrameNumber(self, n, 'onFrame')
    if type(fn) ~= 'function' then error('onFrame: expected a function', 2) end
    self._onFrame = self._onFrame or {}
    local list = self._onFrame[n]
    if not list then list = {}; self._onFrame[n] = list end
    list[#list + 1] = fn
    return self
end

-- Removes one callback, or every callback of the frame when fn is omitted.
---@param n integer
---@param fn function?
---@return desAnim8.Animation
function Animation:offFrame(n, fn)
    checkFrameNumber(self, n, 'offFrame')
    local list = self._onFrame and self._onFrame[n]
    if not list then return self end
    if fn == nil then
        self._onFrame[n] = nil
    else
        for i = #list, 1, -1 do
            if list[i] == fn then table.remove(list, i); break end
        end
    end
    return self
end

-- Calls fn(anim, t) when playback crosses `t` seconds into the sequence. A
-- marker fires at most once per update.
---@param t number seconds into the sequence
---@param fn fun(anim: desAnim8.Animation, t: number)
---@return desAnim8.Animation
function Animation:addMarker(t, fn)
    if type(t) ~= 'number' or not (t >= 0 and t <= self._totalDuration) then
        error(('addMarker: marker time must be in [0,%s], got %s'):format(
            tostring(self._totalDuration), tostring(t)), 2)
    end
    if type(fn) ~= 'function' then error('addMarker: expected a function', 2) end
    self._markers = self._markers or {}
    self._markers[#self._markers + 1] = { t = t, fn = fn }
    return self
end

---@return desAnim8.Animation
function Animation:clearMarkers()
    self._markers = nil
    return self
end

return {
    methods     = Animation,
    callHook    = callHook,
    fireFrames  = fireFrames,
    fireMarkers = fireMarkers,
}
