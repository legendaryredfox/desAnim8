-- Layered sprites that share one clock.
local PKG = (...):match('^(.*)%.[^.]*$')
local flipFor = require(PKG .. '.util').flipFor

local Composite = {}
Composite.__index = Composite

-- newComposite(layers)
-- layers: { { anim = a }, { anim = b, dx = 4, dy = -2, hidden = false, image = img }, ... }
-- Animations or sets. The first layer is the clock; the others follow its phase
-- (and so do not fire their own events). dx and dy shift a layer in sprite
-- pixels and are mirrored when the composite is flipped. `image` is only needed
-- for image-less animations.
local function newComposite(layers)
    if type(layers) ~= 'table' or #layers == 0 then
        error('newComposite: layers must be a non-empty list of { anim = ... }', 2)
    end
    local self = setmetatable({ _layers = {}, flippedH = false, flippedV = false }, Composite)
    for i, l in ipairs(layers) do
        local anim = l.anim
        if type(anim) ~= 'table' or type(anim.getFrameInfo) ~= 'function' then
            error(('newComposite: layer %d needs an anim (an animation or a set)'):format(i), 2)
        end
        self._layers[i] = { anim = anim, dx = l.dx or 0, dy = l.dy or 0, hidden = l.hidden == true, image = l.image }
    end
    return self
end

function Composite:update(dt)
    local layers = self._layers
    local master = layers[1].anim
    master:update(dt)
    local phase = master:getPhase()
    for i = 2, #layers do layers[i].anim:setPhase(phase) end
end

function Composite:draw(x, y, r, sx, sy, ox, oy, kx, ky)
    for _, layer in ipairs(self._layers) do
        if not layer.hidden then
            local dx, dy = layer.dx, layer.dy
            if self.flippedH then dx = -dx end
            if self.flippedV then dy = -dy end
            local lox, loy = (ox or 0) - dx, (oy or 0) - dy
            if layer.image ~= nil then
                layer.anim:draw(layer.image, x, y, r, sx, sy, lox, loy, kx, ky)
            else
                layer.anim:draw(x, y, r, sx, sy, lox, loy, kx, ky)
            end
        end
    end
end

function Composite:getLayer(index)
    local layer = self._layers[index]
    return layer and layer.anim
end

function Composite:setHidden(index, hidden)
    local layer = self._layers[index]
    if not layer then error(('setHidden: no layer %s'):format(tostring(index)), 2) end
    layer.hidden = hidden == true
    return self
end

function Composite:setFlipH(flipped)
    self.flippedH = flipped
    for _, layer in ipairs(self._layers) do layer.anim:setFlipH(flipped) end
    return self
end

function Composite:setFlipV(flipped)
    self.flippedV = flipped
    for _, layer in ipairs(self._layers) do layer.anim:setFlipV(flipped) end
    return self
end

function Composite:flipH() return self:setFlipH(not self.flippedH) end
function Composite:flipV() return self:setFlipV(not self.flippedV) end

function Composite:faceTowards(dx)
    if type(dx) ~= 'number' or dx ~= dx then
        error(('faceTowards: dx must be a number, got %s'):format(tostring(dx)), 2)
    end
    if dx ~= 0 then self:setFlipH(flipFor(dx, self._layers[1].anim._facing or 1)) end
    return self
end

function Composite:setPhase(p)
    for _, layer in ipairs(self._layers) do layer.anim:setPhase(p) end
    return self
end

function Composite:getPhase()
    return self._layers[1].anim:getPhase()
end

function Composite:isPlaying()
    return self._layers[1].anim:isPlaying()
end

for _, name in ipairs({ 'pause', 'resume', 'reset', 'stop', 'pauseAtEnd', 'pauseAtStart' }) do
    Composite[name] = function(self)
        for _, layer in ipairs(self._layers) do layer.anim[name](layer.anim) end
        return self
    end
end

return { newComposite = newComposite }
