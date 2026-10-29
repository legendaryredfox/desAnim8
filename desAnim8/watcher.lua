-- Reload-on-change helper.

local Watcher = {}
Watcher.__index = Watcher

local function defaultStat(path)
    local info = love.filesystem.getInfo(path)
    return info and info.modtime
end

-- newWatcher(path, onChange [, statFn])
-- Call watcher:poll() now and then (once a second is plenty). The first poll only
-- records the file's modification time; later polls call onChange(path) when it
-- moves and return true. statFn(path) -> modification time or nil; the default
-- uses love.filesystem.getInfo.
local function newWatcher(path, onChange, statFn)
    if type(onChange) ~= 'function' then error('newWatcher: onChange must be a function', 2) end
    return setmetatable({ _path = path, _onChange = onChange, _stat = statFn or defaultStat }, Watcher)
end

function Watcher:poll()
    local modified = self._stat(self._path)
    if modified == nil then return false end
    if self._last == nil then
        self._last = modified
        return false
    end
    if modified ~= self._last then
        self._last = modified
        self._onChange(self._path)
        return true
    end
    return false
end

return { newWatcher = newWatcher }
