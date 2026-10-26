-- Drawing and its style: tint, blend, shader, flash, flips, facing, pixel snap,
-- trail, onion skin and bounds. Methods are mixed into the Animation class.
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local timing = require(PKG .. '.timing')
local dbg = require(PKG .. '.debug')
local isInteger, flipFor = util.isInteger, util.flipFor
local neighbourPosition = timing.neighbourPosition

---@class desAnim8.Animation
local Animation = {}

-- Frame info for another frame index of the same animation.
local function frameInfoFor(self, frameIndex, ...)
    local saved = self.currentFrame
    self.currentFrame = frameIndex
    local info = { self:getFrameInfo(...) }
    self.currentFrame = saved
    return info
end

-- Draws with whatever render state is configured (tint, blend, shader, trail,
-- onion skin) and puts the previous graphics state back afterwards. Without any
-- of that it is a single love.graphics.draw call.
local function drawFrame(self, image, ...)
    local gfx = love.graphics
    local trail, onion = self._trail, self._onion
    local tint, flash, blend, shader = self._color, self._flash, self._blend, self._shader
    if not (tint or flash or blend or shader or trail or onion) then
        gfx.draw(image, self:getFrameInfo(...))
        return
    end

    local pr, pg, pb, pa = gfx.getColor()
    local cr, cg, cb, ca = pr, pg, pb, pa
    if flash then
        cr, cg, cb, ca = flash.r, flash.g, flash.b, tint and tint[4] or pa
    elseif tint then
        cr, cg, cb, ca = tint[1], tint[2], tint[3], tint[4]
    end
    local recolor = tint or flash or trail or onion
    local pbm, pbam, psh
    if blend then
        pbm, pbam = gfx.getBlendMode()
        gfx.setBlendMode(blend[1], blend[2])
    end
    if shader then
        psh = gfx.getShader()
        local uniforms = self._uniforms
        if uniforms then
            for name, value in pairs(uniforms) do shader:send(name, value) end
        end
        gfx.setShader(shader)
    end

    if trail then
        local entries = trail.entries
        local n = #entries
        for i = 1, n do
            local e = entries[i]
            gfx.setColor(cr, cg, cb, ca * trail.alpha * i / (n + 1))
            gfx.draw(image, e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9], e[10])
        end
    end
    if onion then
        local before, after = dbg.onionBefore, dbg.onionAfter
        for k = onion[1], 1, -1 do
            local p = neighbourPosition(self, -k)
            if p then
                local e = frameInfoFor(self, self._seq[p], ...)
                gfx.setColor(before[1], before[2], before[3], before[4] * ca)
                gfx.draw(image, e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9], e[10])
            end
        end
        for k = 1, onion[2] do
            local p = neighbourPosition(self, k)
            if p then
                local e = frameInfoFor(self, self._seq[p], ...)
                gfx.setColor(after[1], after[2], after[3], after[4] * ca)
                gfx.draw(image, e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9], e[10])
            end
        end
    end

    if recolor then gfx.setColor(cr, cg, cb, ca) end
    if trail then
        local info = { self:getFrameInfo(...) }
        gfx.draw(image, info[1], info[2], info[3], info[4], info[5], info[6], info[7], info[8], info[9], info[10])
        trail.draws = trail.draws + 1
        if (trail.draws - 1) % trail.spacing == 0 then
            local entries = trail.entries
            entries[#entries + 1] = info
            if #entries > trail.count then table.remove(entries, 1) end
        end
    else
        gfx.draw(image, self:getFrameInfo(...))
    end

    if shader then gfx.setShader(psh) end
    if blend then gfx.setBlendMode(pbm, pbam) end
    if recolor then gfx.setColor(pr, pg, pb, pa) end
end

-- With a bound image:    anim:draw(x, y [, r, sx, sy, ox, oy, kx, ky])
-- Without one (image=nil): anim:draw(image, x, y [, ...]) -- the leading
-- argument is the image to draw onto.
---@param a number|love.Texture x, or the image for an image-less animation
---@param b number y, or x for an image-less animation
---@param ... number r, sx, sy, ox, oy, kx, ky
function Animation:draw(a, b, ...)
    if self.image ~= nil then
        if type(a) ~= 'number' then
            error('draw: this animation has an image bound; call anim:draw(x, y [, ...]) without the image', 2)
        end
        drawFrame(self, self.image, a, b, ...)
    else
        if a == nil or type(a) == 'number' then
            error('draw: no image bound; call anim:draw(image, x, y [, ...])', 2)
        end
        drawFrame(self, a, b, ...)
    end
end

-- Tint multiplied into the sprite; call with no arguments to go back to the
-- current graphics color. Values are 0..1.
---@param r number?
---@param g number?
---@param b number?
---@param a number?
---@return desAnim8.Animation
function Animation:setColor(r, g, b, a)
    if r == nil then
        self._color = nil
        return self
    end
    a = a == nil and 1 or a
    if type(r) ~= 'number' or type(g) ~= 'number' or type(b) ~= 'number' or type(a) ~= 'number' then
        error('setColor: expected numeric r, g, b [, a] (0..1) or no arguments', 2)
    end
    self._color = { r, g, b, a }
    return self
end

---@param a number
---@return desAnim8.Animation
function Animation:setAlpha(a)
    if type(a) ~= 'number' then error('setAlpha: alpha must be a number (0..1)', 2) end
    local c = self._color
    if c then c[4] = a else self._color = { 1, 1, 1, a } end
    return self
end

---@param mode love.BlendMode?
---@param alphaMode love.BlendAlphaMode?
---@return desAnim8.Animation
function Animation:setBlendMode(mode, alphaMode)
    if mode ~= nil and type(mode) ~= 'string' then error('setBlendMode: blend mode must be a string or nil', 2) end
    self._blend = mode and { mode, alphaMode } or nil
    return self
end

-- Draws with `shader`, sending the name -> value pairs in `uniforms` first.
---@param shader love.Shader?
---@param uniforms table<string, any>?
---@return desAnim8.Animation
function Animation:setShader(shader, uniforms)
    if uniforms ~= nil and type(uniforms) ~= 'table' then error('setShader: uniforms must be a table', 2) end
    self._shader   = shader
    self._uniforms = shader and uniforms or nil
    return self
end

-- Overrides the tint for `seconds` of update time (hit flash). The tint is
-- multiplicative, so a white flash needs desAnim8.shaders.whiteFlash.
---@param seconds number
---@param r number?
---@param g number?
---@param b number?
---@return desAnim8.Animation
function Animation:flash(seconds, r, g, b)
    if type(seconds) ~= 'number' or not (seconds > 0) or seconds == math.huge then
        error(('flash: seconds must be a positive number, got %s'):format(tostring(seconds)), 2)
    end
    self._flash = { left = seconds, r = r or 1, g = g or 1, b = b or 1 }
    self._plain = nil
    return self
end

-- Flips horizontally so the sprite faces the sign of dx (0 keeps the current
-- side). Sheets are assumed to face right; see setDefaultFacing.
---@param dx number
---@return desAnim8.Animation
function Animation:faceTowards(dx)
    if type(dx) ~= 'number' or dx ~= dx then
        error(('faceTowards: dx must be a number, got %s'):format(tostring(dx)), 2)
    end
    if dx ~= 0 then self.flippedH = flipFor(dx, self._facing or 1) end
    return self
end

---@param direction 1|-1
---@return desAnim8.Animation
function Animation:setDefaultFacing(direction)
    if direction ~= 1 and direction ~= -1 then
        error('setDefaultFacing: facing must be 1 (sheet faces right) or -1 (faces left)', 2)
    end
    self._facing = direction
    return self
end

-- Rounds the draw position to whole pixels.
---@param enabled boolean
---@return desAnim8.Animation
function Animation:setPixelSnap(enabled)
    if type(enabled) ~= 'boolean' then error('setPixelSnap: expected a boolean', 2) end
    self._snap = enabled or nil
    return self
end

-- Keeps `count` ghosts of earlier draws (one every `spacing` draws) and draws
-- them behind the sprite with alpha rising towards the newest. `alpha` is the
-- strongest ghost's share (default 0.5). nil clears the trail.
---@param count integer?
---@param spacing integer?
---@param alpha number?
---@return desAnim8.Animation
function Animation:setTrail(count, spacing, alpha)
    if count == nil or count == 0 then
        self._trail = nil
        return self
    end
    spacing, alpha = spacing or 1, alpha or 0.5
    if not isInteger(count) or count < 1 or not isInteger(spacing) or spacing < 1
            or type(alpha) ~= 'number' or not (alpha > 0 and alpha <= 1) then
        error('setTrail: expected an integer count >= 1, an integer spacing >= 1 and an alpha in (0,1]', 2)
    end
    self._trail = { count = count, spacing = spacing, alpha = alpha, entries = {}, draws = 0 }
    return self
end

-- Recorded ghosts, oldest first. Each entry is { quad, x, y, r, sx, sy, ox, oy, kx, ky },
-- ready for love.graphics.draw or a SpriteBatch.
---@return table[]
function Animation:getTrail()
    return self._trail and self._trail.entries or {}
end

-- Draws `before` earlier and `after` later frames of the sequence, tinted, behind
-- the sprite (animation debugging). Pass 0, 0 or nil to turn it off.
---@param before integer?
---@param after integer?
---@return desAnim8.Animation
function Animation:setOnion(before, after)
    before, after = before or 0, after or 0
    if not isInteger(before) or not isInteger(after) or before < 0 or after < 0 then
        error('setOnion: before and after must be non-negative integers', 2)
    end
    self._onion = (before > 0 or after > 0) and { before, after } or nil
    return self
end

-- Outlines the current frame's rectangle with the transform draw would use.
---@return nil
function Animation:drawBounds(x, y, r, sx, sy, ox, oy, kx, ky)
    local gfx = love.graphics
    local quad, fx, fy, fr, fsx, fsy, fox, foy, fkx, fky = self:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky)
    local _, _, w, h = quad:getViewport()
    gfx.push()
    gfx.translate(fx, fy)
    gfx.rotate(fr or 0)
    gfx.scale(fsx or 1, fsy or fsx or 1)
    if fkx or fky then gfx.shear(fkx or 0, fky or 0) end
    gfx.translate(-(fox or 0), -(foy or 0))
    gfx.rectangle('line', 0, 0, w, h)
    gfx.pop()
end

-- Toggle horizontal flip. Returns self so calls can be chained.
---@return desAnim8.Animation
function Animation:flipH()
    self.flippedH = not self.flippedH
    return self
end

-- Toggle vertical flip. Returns self so calls can be chained.
---@return desAnim8.Animation
function Animation:flipV()
    self.flippedV = not self.flippedV
    return self
end

-- Absolute flip setters; safe to call every frame, unlike the toggles.
---@param flipped boolean
---@return desAnim8.Animation
function Animation:setFlipH(flipped)
    if type(flipped) ~= 'boolean' then error('setFlipH: expected a boolean', 2) end
    self.flippedH = flipped
    return self
end

---@param flipped boolean
---@return desAnim8.Animation
function Animation:setFlipV(flipped)
    if type(flipped) ~= 'boolean' then error('setFlipV: expected a boolean', 2) end
    self.flippedV = flipped
    return self
end

return { methods = Animation }
