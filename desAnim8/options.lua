-- Validation of the constructor `opts` table. Internal.
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local isInteger = util.isInteger

local OPTION_NAMES = { 'ticks', 'weights', 'jitter', 'rng', 'randomLength', 'data' }
local KNOWN_OPTIONS  = {}
for _, name in ipairs(OPTION_NAMES) do KNOWN_OPTIONS[name] = true end

-- Returns a private copy of opts after validating it. `level` as in error().
local function checkOptions(opts, frameCount, level)
    if opts == nil then return {} end
    if type(opts) ~= 'table' then
        error(('opts must be a table, got %s'):format(type(opts)), level)
    end
    local o = {}
    for key, value in pairs(opts) do
        if not KNOWN_OPTIONS[key] then
            error(('unknown option %q'):format(tostring(key)), level)
        end
        o[key] = value
    end
    if o.ticks ~= nil and type(o.ticks) ~= 'boolean' then error('option ticks must be a boolean', level) end
    if o.rng ~= nil and type(o.rng) ~= 'function' then error('option rng must be a function returning [0,1)', level) end
    if o.jitter ~= nil and (type(o.jitter) ~= 'number' or not (o.jitter >= 0 and o.jitter < 1)) then
        error(('option jitter must be a number in [0,1), got %s'):format(tostring(o.jitter)), level)
    end
    if o.jitter and o.ticks then error('option jitter cannot be combined with ticks', level) end
    if o.randomLength ~= nil and (not isInteger(o.randomLength) or o.randomLength < 2) then
        error(('option randomLength must be an integer >= 2, got %s'):format(tostring(o.randomLength)), level)
    end
    if o.weights ~= nil then
        local w = o.weights
        if type(w) ~= 'table' then error('option weights must be a table', level) end
        local positive = 0
        for i = 1, frameCount do
            if type(w[i]) ~= 'number' or not (w[i] >= 0) or w[i] == math.huge then
                error(('option weights: entry %d must be a non-negative number, got %s'):format(i, tostring(w[i])), level)
            end
            if w[i] > 0 then positive = positive + 1 end
        end
        if frameCount > 1 and positive < 2 then
            error('option weights: at least two frames need a positive weight', level)
        end
        local copy = {}
        for i = 1, frameCount do copy[i] = w[i] end
        o.weights = copy
    end
    if o.data ~= nil then
        if type(o.data) ~= 'table' then
            error('option data must be a table of frame -> { name = value }', level)
        end
        local copy = {}
        for frame, values in pairs(o.data) do
            if not isInteger(frame) or frame < 1 or frame > frameCount then
                error(('option data: frame %s is outside [1,%d]'):format(tostring(frame), frameCount), level)
            end
            if type(values) ~= 'table' then
                error(('option data: frame %d must map to a table'):format(frame), level)
            end
            local c = {}
            for k, v in pairs(values) do c[k] = v end
            local rot = c.rotated
            if rot == true or rot == 'cw' then
                c.rotated = 'cw'
            elseif rot == false then
                c.rotated = nil
            elseif rot ~= nil and rot ~= 'ccw' then
                error(('option data: frame %d rotated must be true, "cw" or "ccw"'):format(frame), level)
            end
            local tf = c.transform
            if tf ~= nil then
                if type(tf) ~= 'table' then
                    error(('option data: frame %d transform must be a table'):format(frame), level)
                end
                local n = { x = 0, y = 0, r = 0, sx = 1, sy = 1 }
                for key in pairs(n) do
                    local v = tf[key]
                    if v ~= nil then
                        if type(v) ~= 'number' or v ~= v then
                            error(('option data: frame %d transform %s must be a number'):format(frame, key), level)
                        end
                        n[key] = v
                    end
                end
                c.transform = n
            end
            local t = c.trim
            if t ~= nil and (type(t) ~= 'table' or type(t.x) ~= 'number' or type(t.y) ~= 'number'
                    or type(t.w) ~= 'number' or type(t.h) ~= 'number' or not (t.w > 0 and t.h > 0)) then
                error(('option data: frame %d trim must be { x, y, w, h } with positive w and h'):format(frame), level)
            end
            copy[frame] = c
        end
        o.data = copy
    end
    return o
end

local function assertTickDurations(durations, level)
    for i = 1, #durations do
        if not isInteger(durations[i]) then
            error(('ticks mode needs integer durations, frame %d has %s'):format(i, tostring(durations[i])), level)
        end
    end
end

local function jittered(base, jitter, rng)
    local t = {}
    for i = 1, #base do t[i] = base[i] * (1 + (rng() * 2 - 1) * jitter) end
    return t
end

return {
    checkOptions        = checkOptions,
    assertTickDurations = assertTickDurations,
    jittered            = jittered,
}
