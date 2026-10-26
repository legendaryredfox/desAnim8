-- Small helpers shared by every module. Internal: not part of the public API.
-- `level` arguments follow error(): the number of stack frames from the raising
-- function up to the user's call, so messages point at user code.

-- `level` arguments below follow error(): the number of stack frames from the
-- raising function up to the user's call, so messages point at user code.

local function assertPositiveInteger(value, name, level)
    if type(value) ~= 'number' or value < 1 or value == math.huge or value ~= math.floor(value) then
        error(('%s must be a positive integer, got %s'):format(name, tostring(value)), level)
    end
end

local function assertNonNegativeInteger(value, name, level)
    if type(value) ~= 'number' or value < 0 or value == math.huge or value ~= math.floor(value) then
        error(('%s must be a non-negative integer, got %s'):format(name, tostring(value)), level)
    end
end

-- Binary search: find i such that intervals[i] <= t < intervals[i+1].
-- Correctly returns the last index when t == totalDuration.
local function seekIndex(intervals, t)
    local low, high, i = 1, #intervals - 1, 1
    while low <= high do
        i = math.floor((low + high) / 2)
        if     t >= intervals[i + 1] then low  = i + 1
        elseif t <  intervals[i]     then high = i - 1
        else   break
        end
    end
    return i
end

-- Returns (from, to, step) with no table allocation.
-- Accepts a number, a "n" string, or a "n-m" range string (spaces ignored).
-- `what` names the argument in error messages.
local function parseRange(v, max, level, what)
    if v == nil then
        error(('missing %s argument: ranges come in (columns, rows) pairs'):format(what), level)
    end
    local a, b
    if type(v) == 'number' then
        if v ~= math.floor(v) then
            error(('%s must be an integer, got %s'):format(what, tostring(v)), level)
        end
        a, b = v, v
    else
        local s = tostring(v):gsub('%s+', '')
        local x, y = s:match('^(%d+)-(%d+)$')
        if x then
            a, b = tonumber(x), tonumber(y)
        else
            a = tonumber(s:match('^(%d+)$'))
            b = a
        end
        if not a then
            error(('invalid %s %q, expected a number or "n-m"'):format(what, tostring(v)), level)
        end
    end
    if a < 1 or a > max or b < 1 or b > max then
        error(('%s %s out of range [1,%d]'):format(what, tostring(v), max), level)
    end
    return a, b, a <= b and 1 or -1
end

local function isInteger(v)
    return type(v) == 'number' and v == math.floor(v) and v > -math.huge and v < math.huge
end

local function flipFor(dx, facing) return dx * facing < 0 end

return {
    assertPositiveInteger    = assertPositiveInteger,
    assertNonNegativeInteger = assertNonNegativeInteger,
    seekIndex                = seekIndex,
    parseRange               = parseRange,
    isInteger                = isInteger,
    flipFor                  = flipFor,
}
