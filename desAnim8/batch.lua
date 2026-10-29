-- Many entries of one animation definition, advanced together and drawn through
-- a single SpriteBatch.
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local timing = require(PKG .. '.timing')
local build = require(PKG .. '.animation').build
local isInteger, seekIndex = util.isInteger, util.seekIndex
local PAUSE_AT_END, clock = timing.PAUSE_AT_END, timing.clock

local Batch = {}
Batch.__index = Batch

-- newBatch(image, frames, durations, playMode, capacity [, opts])
-- Thousands of entries that share one definition, advanced in a single call and
-- drawn through one SpriteBatch. A frame change rewrites only that sprite. Each
-- entry has a position, transform, flip, speed and phase; loop ranges, events
-- and the other per-animation features are not available here.
local function newBatch(image, frames, durations, playMode, capacity, opts)
    if not isInteger(capacity) or capacity < 1 then
        error(('newBatch: capacity must be a positive integer, got %s'):format(tostring(capacity)), 2)
    end
    local template = build(image, frames, durations, playMode, opts)
    local self = setmetatable({}, Batch)
    self._anim     = template
    self._batch    = love.graphics.newSpriteBatch(image, capacity)
    self._capacity = capacity
    self._count    = 0
    self._top      = 0
    self._free     = {}
    self._finish   = PAUSE_AT_END[template.playMode] or false
    self._timer, self._pos, self._speed, self._done, self._alive = {}, {}, {}, {}, {}
    self._flipH, self._flipV = {}, {}
    self._args = {}
    return self
end

local function batchWrite(self, id, isNew)
    local a, args = self._anim, self._args[id]
    a.currentFrame = a._seq[self._pos[id]]
    a._position    = self._pos[id]
    a._timer       = self._timer[id]
    a.flippedH, a.flippedV = self._flipH[id], self._flipV[id]
    local quad, x, y, r, sx, sy, ox, oy, kx, ky = a:getFrameInfo(
        args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9])
    if isNew then
        local got = self._batch:add(quad, x, y, r, sx, sy, ox, oy, kx, ky)
        assert(got == id, 'desAnim8 batch: sprite index out of step')
    else
        self._batch:set(id, quad, x, y, r, sx, sy, ox, oy, kx, ky)
    end
end

local function checkEntry(self, id, what)
    if not self._alive[id] then error(('%s: no entry %s'):format(what, tostring(id)), 3) end
end

-- Adds an entry drawn with the usual x, y, r, sx, sy, ox, oy, kx, ky; returns its id.
function Batch:add(x, y, r, sx, sy, ox, oy, kx, ky)
    if self._count >= self._capacity then
        error(('add: batch is full (capacity %d)'):format(self._capacity), 2)
    end
    local id = table.remove(self._free)
    local isNew = id == nil
    if isNew then
        self._top = self._top + 1
        id = self._top
    end
    self._alive[id], self._done[id] = true, false
    self._timer[id], self._pos[id], self._speed[id] = 0, 1, 1
    self._flipH[id], self._flipV[id] = false, false
    self._args[id] = { x, y, r, sx, sy, ox, oy, kx, ky }
    self._count = self._count + 1
    batchWrite(self, id, isNew)
    return id
end

-- Frees an entry; its sprite is hidden and the slot is reused by the next add.
function Batch:remove(id)
    checkEntry(self, id, 'remove')
    self._alive[id] = false
    self._free[#self._free + 1] = id
    self._count = self._count - 1
    self._batch:set(id, self._anim.frames[1], 0, 0, 0, 0, 0)
end

function Batch:clear()
    self._batch:clear()
    self._count, self._top, self._free = 0, 0, {}
    self._timer, self._pos, self._speed, self._done, self._alive = {}, {}, {}, {}, {}
    self._flipH, self._flipV, self._args = {}, {}, {}
end

function Batch:getCount()
    return self._count
end

function Batch:getFrame(id)
    checkEntry(self, id, 'getFrame')
    return self._anim._seq[self._pos[id]]
end

-- Moves or retransforms an entry.
function Batch:set(id, x, y, r, sx, sy, ox, oy, kx, ky)
    checkEntry(self, id, 'set')
    self._args[id] = { x, y, r, sx, sy, ox, oy, kx, ky }
    batchWrite(self, id, false)
end

function Batch:setFlip(id, horizontal, vertical)
    checkEntry(self, id, 'setFlip')
    self._flipH[id], self._flipV[id] = horizontal == true, vertical == true
    batchWrite(self, id, false)
end

function Batch:setSpeed(id, rate)
    checkEntry(self, id, 'setSpeed')
    if type(rate) ~= 'number' or rate ~= rate or rate == math.huge or rate == -math.huge then
        error(('setSpeed: speed must be a finite number, got %s'):format(tostring(rate)), 2)
    end
    self._speed[id] = rate
end

local function batchPhase(self, id, p)
    local a = self._anim
    p = math.max(0, math.min(1, p))
    local timer = p * a._totalDuration
    self._timer[id] = timer
    self._done[id]  = false
    self._pos[id]   = timer >= a._totalDuration and #a._seq or seekIndex(a._intervals, timer)
end

function Batch:setPhase(id, p)
    checkEntry(self, id, 'setPhase')
    if type(p) ~= 'number' or p ~= p then error('setPhase: phase must be a number', 2) end
    batchPhase(self, id, p)
    batchWrite(self, id, false)
end

-- Gives every entry a random phase (keeps a crowd out of sync).
function Batch:randomizePhases(rng)
    rng = rng or math.random
    for id = 1, self._top do
        if self._alive[id] then
            batchPhase(self, id, rng())
            batchWrite(self, id, false)
        end
    end
end

function Batch:update(dt)
    if type(dt) ~= 'number' then
        error(('update: dt must be a number, got %s'):format(type(dt)), 2)
    end
    if not (dt > 0) or dt == math.huge then return end
    local a = self._anim
    local total, intervals, seq = a._totalDuration, a._intervals, a._seq
    local finish = self._finish
    local timers, positions, speeds, done = self._timer, self._pos, self._speed, self._done
    for id = 1, self._top do
        if self._alive[id] and not done[id] then
            local step = dt * speeds[id]
            step = step * clock.scale
            if step ~= 0 then
                local timer, oldPos = timers[id], positions[id]
                local newPos
                timer = timer + step
                if step > 0 then
                    if timer >= total then
                        if finish then
                            done[id], timer, newPos = true, total, #seq
                        else
                            timer = timer - total * math.floor(timer / total)
                        end
                    end
                elseif timer < 0 then
                    if finish then
                        done[id], timer, newPos = true, 0, 1
                    else
                        timer = timer + total * math.ceil((0 - timer) / total)
                    end
                end
                timers[id] = timer
                newPos = newPos or seekIndex(intervals, timer)
                positions[id] = newPos
                if newPos ~= oldPos then batchWrite(self, id, false) end
            end
        end
    end
end

function Batch:draw(...)
    love.graphics.draw(self._batch, ...)
end

return { newBatch = newBatch }
