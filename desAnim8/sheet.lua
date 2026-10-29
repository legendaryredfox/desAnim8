-- Tools that analyse a spritesheet's pixels. They take an ImageData-like object
-- (anything with getDimensions and getPixel) supplied by the caller.

-- Tight opaque rectangle of every quad, relative to the quad's top-left corner
-- ({ x = 0, y = 0, w = 0, h = 0 } for an empty frame). `imageData` is anything
-- with getPixel(x, y) -> r, g, b, a; pixels with alpha above `threshold` (default 0)
-- count as opaque.
local function scanBounds(quads, imageData, threshold)
    threshold = threshold or 0
    local out = {}
    for i, quad in ipairs(quads) do
        local qx, qy, qw, qh = quad:getViewport()
        qx, qy, qw, qh = math.floor(qx), math.floor(qy), math.floor(qw), math.floor(qh)
        local minX, minY, maxX, maxY = qw, qh, -1, -1
        for y = 0, qh - 1 do
            for x = 0, qw - 1 do
                local _, _, _, a = imageData:getPixel(qx + x, qy + y)
                if a > threshold then
                    if x < minX then minX = x end
                    if x > maxX then maxX = x end
                    if y < minY then minY = y end
                    if y > maxY then maxY = y end
                end
            end
        end
        out[i] = maxX < 0 and { x = 0, y = 0, w = 0, h = 0 }
            or { x = minX, y = minY, w = maxX - minX + 1, h = maxY - minY + 1 }
    end
    return out
end

-- Turns { name = listPerFrame } into the frame-indexed table the `data` option takes.
local function dataFromLists(lists)
    local data = {}
    for name, list in pairs(lists) do
        for i, value in pairs(list) do
            data[i] = data[i] or {}
            data[i][name] = value
        end
    end
    return data
end

-- Finds the opaque regions of an image (4-connected) and returns their bounding
-- rectangles { x, y, w, h } in row-major order, for sheets without a regular grid.
-- opts: threshold (alpha above it is opaque, default 0), mergeGap (join regions at
-- most this many empty pixels apart, default: no merging), minSize (drop regions
-- narrower or shorter than this).
local function sliceByAlpha(imageData, opts)
    opts = opts or {}
    local threshold = opts.threshold or 0
    local w, h = imageData:getDimensions()
    local opaque = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = imageData:getPixel(x, y)
            opaque[y * w + x] = a > threshold
        end
    end

    local boxes = {}
    for y0 = 0, h - 1 do
        for x0 = 0, w - 1 do
            if opaque[y0 * w + x0] then
                local minX, maxX, minY, maxY = x0, x0, y0, y0
                local stack, top = { y0 * w + x0 }, 1
                opaque[y0 * w + x0] = false
                while top > 0 do
                    local idx = stack[top]
                    top = top - 1
                    local x, y = idx % w, math.floor(idx / w)
                    if x < minX then minX = x end
                    if x > maxX then maxX = x end
                    if y < minY then minY = y end
                    if y > maxY then maxY = y end
                    local n1, n2, n3, n4 = idx - 1, idx + 1, idx - w, idx + w
                    if x > 0 and opaque[n1] then opaque[n1] = false; top = top + 1; stack[top] = n1 end
                    if x < w - 1 and opaque[n2] then opaque[n2] = false; top = top + 1; stack[top] = n2 end
                    if y > 0 and opaque[n3] then opaque[n3] = false; top = top + 1; stack[top] = n3 end
                    if y < h - 1 and opaque[n4] then opaque[n4] = false; top = top + 1; stack[top] = n4 end
                end
                boxes[#boxes + 1] = { minX, minY, maxX, maxY }
            end
        end
    end

    local gap = opts.mergeGap
    if gap and #boxes > 1 then
        local merged = true
        while merged do
            merged = false
            for i = 1, #boxes do
                for j = i + 1, #boxes do
                    local a, b = boxes[i], boxes[j]
                    local dx = math.max(b[1] - a[3] - 1, a[1] - b[3] - 1, 0)
                    local dy = math.max(b[2] - a[4] - 1, a[2] - b[4] - 1, 0)
                    if a and b and dx <= gap and dy <= gap then
                        a[1], a[2] = math.min(a[1], b[1]), math.min(a[2], b[2])
                        a[3], a[4] = math.max(a[3], b[3]), math.max(a[4], b[4])
                        table.remove(boxes, j)
                        merged = true
                        break
                    end
                end
                if merged then break end
            end
        end
    end

    local rects = {}
    local minSize = opts.minSize or 1
    for _, b in ipairs(boxes) do
        local rw, rh = b[3] - b[1] + 1, b[4] - b[2] + 1
        if rw >= minSize and rh >= minSize then rects[#rects + 1] = { x = b[1], y = b[2], w = rw, h = rh } end
    end

    table.sort(rects, function(p, q)
        if p.y ~= q.y then return p.y < q.y end
        return p.x < q.x
    end)
    local ordered, row, ref = {}, nil, nil
    for _, r in ipairs(rects) do
        if ref and r.y < ref.y + ref.h then
            row[#row + 1] = r
        else
            if row then
                table.sort(row, function(p, q) return p.x < q.x end)
                for _, e in ipairs(row) do ordered[#ordered + 1] = e end
            end
            row, ref = { r }, r
        end
    end
    if row then
        table.sort(row, function(p, q) return p.x < q.x end)
        for _, e in ipairs(row) do ordered[#ordered + 1] = e end
    end
    return ordered
end

-- Quads for a list of { x, y, w, h } rectangles (for example from sliceByAlpha).
local function newQuadsFromRects(rects, imageWidth, imageHeight)
    local quads = {}
    for i, r in ipairs(rects) do
        quads[i] = love.graphics.newQuad(r.x, r.y, r.w, r.h, imageWidth, imageHeight)
    end
    return quads
end

return {
    scanBounds         = scanBounds,
    dataFromLists      = dataFromLists,
    sliceByAlpha       = sliceByAlpha,
    newQuadsFromRects  = newQuadsFromRects,
}
