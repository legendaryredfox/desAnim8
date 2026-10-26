-- What gets drawn for the current frame: transform parameters with flip, trim,
-- pivot and keyframe transforms applied, per-frame data and SpriteBatch helpers.
local PKG = (...):match('^(.*)%.[^.]*$')
local timing = require(PKG .. '.timing')
local neighbourPosition, frameProgress = timing.neighbourPosition, timing.frameProgress
local EASINGS, resolveEasing = timing.EASINGS, timing.resolveEasing

---@class desAnim8.Animation
local Animation = {}

local IDENTITY_TRANSFORM = { x = 0, y = 0, r = 0, sx = 1, sy = 1 }
local HALF_PI = math.pi / 2

---@return number
---@nodiscard
function Animation:getFrameProgress()
    return frameProgress(self)
end

-- Keyframe offsets of the current frame, blended towards the next frame's when
-- interpolation is on. Returns x, y, r, sx, sy.
local function frameTransform(self, f)
    local c = self._transforms[f] or IDENTITY_TRANSFORM
    if not self._interp then return c.x, c.y, c.r, c.sx, c.sy end
    local p = neighbourPosition(self, 1)
    local n = p and (self._transforms[self._seq[p]] or IDENTITY_TRANSFORM) or c
    local t = self._interpEase(frameProgress(self))
    return c.x + (n.x - c.x) * t, c.y + (n.y - c.y) * t, c.r + (n.r - c.r) * t,
        c.sx + (n.sx - c.sx) * t, c.sy + (n.sy - c.sy) * t
end

-- Blends keyframe `transform` data (see the data option) between frames instead
-- of stepping. `easing` shapes the blend; default linear.
---@param enabled boolean
---@param easing desAnim8.Easing?
---@return desAnim8.Animation
function Animation:setInterpolation(enabled, easing)
    if type(enabled) ~= 'boolean' then error('setInterpolation: expected a boolean', 2) end
    self._interp = enabled or nil
    self._interpEase = resolveEasing(easing, 'setInterpolation', 3) or EASINGS.linear
    return self
end

-- Returns the quad and all love.graphics.draw transform parameters, with flip
-- and trim adjustments applied. Use this when you need to draw with extra
-- transforms, or to add the animation to a SpriteBatch.
--
-- A flip mirrors the sprite inside its (untrimmed) source frame of size W x H,
-- so the drawn position stays put. With a trim offset (tx, ty) the quad is only
-- part of that frame: the origin becomes ox - tx, or W - tx - ox once mirrored.
---@return love.Quad quad
---@return number? x
---@return number? y
---@return number? r
---@return number? sx
---@return number? sy
---@return number? ox
---@return number? oy
---@return number? kx
---@return number? ky
function Animation:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky)
    local fh, fv = self.flippedH, self.flippedV
    -- _fancy: some feature beyond a plain frame is configured (trim, transforms,
    -- pixel snap, auto pivot). Cached; the setters reset it to nil.
    local fancy = self._fancy
    if fancy == nil then
        fancy = (self._trim or self._transforms or self._rotated or self._snap or self._autoPivot) and true or false
        self._fancy = fancy
    end
    if not fancy then
        local frame = self.frames[self.currentFrame]
        if not (fh or fv) then return frame, x, y, r, sx, sy, ox, oy, kx, ky end
        -- flips only: the original, short formula
        r,  sx = r or 0, sx or 1
        sy     = sy or sx
        ox, oy = ox or 0, oy or 0
        kx, ky = kx or 0, ky or 0
        local _, _, w, h = frame:getViewport()
        if fh then
            sx = -sx
            ox = w - ox
            kx = -kx
            ky = -ky
        end
        if fv then
            sy = -sy
            oy = h - oy
            kx = -kx
            ky = -ky
        end
        return frame, x, y, r, sx, sy, ox, oy, kx, ky
    end
    local f = self.currentFrame
    local frame = self.frames[f]
    local trim = self._trim and self._trim[f]
    if self._snap then
        if x then x = math.floor(x + 0.5) end
        if y then y = math.floor(y + 0.5) end
    end
    if self._autoPivot then
        local d = self._data and self._data[f]
        local pivot = d and d.pivot
        if pivot then
            if ox == nil then ox = pivot.x end
            if oy == nil then oy = pivot.y end
        end
    end
    local dx, dy, dr, tsx, tsy
    if self._transforms then dx, dy, dr, tsx, tsy = frameTransform(self, f) end
    local rotated = self._rotated and self._rotated[f]
    if fh or fv or trim or dx or rotated then
        r,  sx = r or 0, sx or 1
        sy     = sy or sx -- love.graphics.draw defaults sy to sx
        ox, oy = ox or 0, oy or 0
        kx, ky = kx or 0, ky or 0
        if dx then
            -- Offsets are in sprite pixels: a mirrored sprite mirrors them, and a
            -- single mirror reverses the sense of rotation.
            if fh then dx = -dx end
            if fv then dy = -dy end
            if fh ~= fv then dr = -dr end
            ox, oy = ox - dx, oy - dy
            r = r + dr
            sy, sx = sy * tsy, sx * tsx
        end
        local tx, ty, w, h
        if trim then
            tx, ty, w, h = trim.x, trim.y, trim.w, trim.h
        else
            tx, ty = 0, 0
            local _
            _, _, w, h = frame:getViewport()
            if rotated then w, h = h, w end
        end
        if fh then
            sx = -sx
            ox = w - tx - ox
            kx = -kx
            ky = -ky
        else
            ox = ox - tx
        end
        if fv then
            sy = -sy
            oy = h - ty - oy
            kx = -kx
            ky = -ky
        else
            oy = oy - ty
        end
        if rotated then
            -- Everything above treated the frame as upright. The stored quad is that
            -- sprite turned 90 degrees, so turn the parameters the other way: swap
            -- the scale axes, swap and negate the shear, rotate by -90 (clockwise
            -- storage) or +90 degrees, and move the origin into the quad's axes.
            local _, _, qw, qh = frame:getViewport()
            sx, sy = sy, sx
            kx, ky = -ky, -kx
            if rotated == 'cw' then
                r = r - HALF_PI
                ox, oy = qw - oy, ox
            else
                r = r + HALF_PI
                ox, oy = oy, qh - ox
            end
        end
    end
    return frame, x, y, r, sx, sy, ox, oy, kx, ky
end

-- Value stored under `name` for a frame (default: the current one) through the
-- `data` constructor option, or nil. Shared with clones; treat it as read only.
---@param name string
---@param frame integer?
---@return any
function Animation:getFrameData(name, frame)
    local d = self._data and self._data[frame or self.currentFrame]
    return d and d[name]
end

-- When on, ox and oy default to the frame's `pivot` data ({ x, y } in source
-- frame pixels) wherever the caller leaves them out.
---@param enabled boolean
---@return desAnim8.Animation
function Animation:setAutoPivot(enabled)
    if type(enabled) ~= 'boolean' then error('setAutoPivot: expected a boolean', 2) end
    self._autoPivot = enabled
    self._fancy = nil
    return self
end

-- World-space rectangle of a { x, y, w, h } stored under `name` (for example a
-- hitbox), given the same x, y, sx, sy, ox, oy you draw with. Honours the
-- current flips; rotation is not supported. Returns x, y, w, h or nil.
---@param name string
---@return number? x
---@return number? y
---@return number? w
---@return number? h
function Animation:getWorldRect(name, x, y, sx, sy, ox, oy)
    local f = self.currentFrame
    local rect = self:getFrameData(name, f)
    if rect == nil then return nil end
    sx = sx or 1
    sy = sy or sx
    if self._autoPivot then
        local pivot = self:getFrameData('pivot', f)
        if pivot then
            if ox == nil then ox = pivot.x end
            if oy == nil then oy = pivot.y end
        end
    end
    ox, oy = ox or 0, oy or 0
    local trim = self._trim and self._trim[f]
    local w, h
    if trim then
        w, h = trim.w, trim.h
    else
        local _
        _, _, w, h = self.frames[f]:getViewport()
        if self._rotated and self._rotated[f] then w, h = h, w end
    end
    local rx, ry = rect.x, rect.y
    if self.flippedH then rx = w - rx - rect.w end
    if self.flippedV then ry = h - ry - rect.h end
    local x0, y0 = x + sx * (rx - ox), y + sy * (ry - oy)
    local x1, y1 = x0 + sx * rect.w, y0 + sy * rect.h
    return math.min(x0, x1), math.min(y0, y1), math.abs(x1 - x0), math.abs(y1 - y0)
end

-- Adds the current frame (flip applied) to a SpriteBatch and returns its id.
---@param batch love.SpriteBatch
---@param ... number x, y, r, sx, sy, ox, oy, kx, ky
---@return integer id
function Animation:addToBatch(batch, ...)
    return batch:add(self:getFrameInfo(...))
end

-- Rewrites sprite `id` of a SpriteBatch with the current frame.
---@param batch love.SpriteBatch
---@param id integer
---@param ... number x, y, r, sx, sy, ox, oy, kx, ky
function Animation:setInBatch(batch, id, ...)
    return batch:set(id, self:getFrameInfo(...))
end

return { methods = Animation }
