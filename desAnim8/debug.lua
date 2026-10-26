-- Debug drawing helpers and the onion-skin colors. Public as desAnim8.debug.

local dbg = {
    onionBefore = { 1, 0.3, 0.3, 0.35 },
    onionAfter  = { 0.3, 1, 0.3, 0.35 },
}

-- Segment bar of the whole sequence with a playhead, for debugging timing.
---@param anim desAnim8.Animation
---@return nil
function dbg.drawTimeline(anim, x, y, w, h)
    local gfx = love.graphics
    local pr, pg, pb, pa = gfx.getColor()
    local total, intervals = anim._totalDuration, anim._intervals
    for i = 1, #anim._seq do
        local x0 = x + w * intervals[i] / total
        local x1 = x + w * intervals[i + 1] / total
        local shade = i == anim._position and 0.9 or (i % 2 == 0 and 0.35 or 0.5)
        gfx.setColor(shade, shade, shade, 0.8)
        gfx.rectangle('fill', x0, y, x1 - x0, h)
    end
    gfx.setColor(1, 1, 1, 1)
    gfx.rectangle('line', x, y, w, h)
    local px = x + w * anim._timer / total
    gfx.setColor(1, 0.2, 0.2, 1)
    gfx.line(px, y, px, y + h)
    gfx.setColor(pr, pg, pb, pa)
end

-- If the point (mx, my) is inside the timeline rectangle, pauses the animation
-- on the matching phase and returns true.
---@param anim desAnim8.Animation
---@return boolean
function dbg.scrub(anim, mx, my, x, y, w, h)
    if mx < x or mx > x + w or my < y or my > y + h then return false end
    anim:setPhase((mx - x) / w)
    anim:pause()
    return true
end

return dbg
