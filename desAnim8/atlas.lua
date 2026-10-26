-- Atlas adapters and the Aseprite importer. Nothing here reads files or decodes
-- JSON: callers pass decoded tables (or a decoder callback).
local PKG = (...):match('^(.*)%.[^.]*$')
local util = require(PKG .. '.util')
local build = require(PKG .. '.animation').build
local assertPositiveInteger = util.assertPositiveInteger

-- Frame records are the common shape every adapter produces:
--   { x, y, w, h, trimX, trimY, sourceW, sourceH, name, duration, rotated }
-- x, y, w, h are the rectangle as stored in the image: for a rotated frame its
-- width and height are swapped. trim and source sizes describe the upright sprite.
-- rotated: true or 'cw' (stored turned 90 degrees clockwise, as TexturePacker,
-- Phaser and Starling do) or 'ccw' (counter-clockwise).
-- (trim and source fields default to "untrimmed"; duration is in seconds).

-- Returns quads, data (for the `data` constructor option) and, when every record
-- has one, a durations list.
---@param records desAnim8.FrameRecord[]
---@param imageWidth integer
---@param imageHeight integer
---@return love.Quad[] quads
---@return table<integer, table> data
---@return number[]? durations
local function newFramesFromRecords(records, imageWidth, imageHeight)
    if type(records) ~= 'table' or #records == 0 then
        error('newFramesFromRecords: records must be a non-empty list', 2)
    end
    assertPositiveInteger(imageWidth,  'imageWidth',  3)
    assertPositiveInteger(imageHeight, 'imageHeight', 3)
    local quads, data, durations, haveDurations = {}, {}, {}, true
    for i, rec in ipairs(records) do
        for _, key in ipairs({ 'x', 'y', 'w', 'h' }) do
            if type(rec[key]) ~= 'number' then
                error(('newFramesFromRecords: record %d needs a numeric %s'):format(i, key), 2)
            end
        end
        quads[i] = love.graphics.newQuad(rec.x, rec.y, rec.w, rec.h, imageWidth, imageHeight)
        local d = {}
        if rec.name ~= nil then d.name = rec.name end
        local tx, ty = rec.trimX or 0, rec.trimY or 0
        local sw, sh = rec.sourceW or rec.w, rec.sourceH or rec.h
        if tx ~= 0 or ty ~= 0 or sw ~= rec.w or sh ~= rec.h then
            d.trim = { x = tx, y = ty, w = sw, h = sh }
        end
        local rotated = rec.rotated
        if rotated == true or rotated == 'cw' then
            d.rotated = 'cw'
        elseif rotated == 'ccw' then
            d.rotated = 'ccw'
        elseif rotated ~= nil and rotated ~= false then
            error(('newFramesFromRecords: record %d has an invalid rotated value %s (use true, "cw" or "ccw")'):format(
                i, tostring(rotated)), 2)
        end
        if next(d) ~= nil then data[i] = d end
        durations[i] = rec.duration
        if rec.duration == nil then haveDurations = false end
    end
    return quads, data, haveDurations and durations or nil
end

local atlas = {}

local HASH_FORM = 'expected the array form of the export (JSON Array), got the hash form'

-- TexturePacker "JSON (Array)" export, already decoded. Returns records, the
-- image width and the image height (from meta.size, when present).
---@param decoded table
---@return desAnim8.FrameRecord[] records
---@return integer? imageWidth
---@return integer? imageHeight
function atlas.fromTexturePacker(decoded)
    if type(decoded) ~= 'table' or type(decoded.frames) ~= 'table' then
        error('fromTexturePacker: expected a decoded export table with a frames list', 2)
    end
    local frames = decoded.frames
    if frames[1] == nil then
        error('fromTexturePacker: ' .. (next(frames) ~= nil and HASH_FORM or 'the export has no frames'), 2)
    end
    local records = {}
    for i, f in ipairs(frames) do
        local fr, src, size = f.frame, f.spriteSourceSize, f.sourceSize
        if type(fr) ~= 'table' then error(('fromTexturePacker: frame %d has no frame rectangle'):format(i), 2) end
        records[i] = {
            x = fr.x, y = fr.y, w = fr.w, h = fr.h,
            trimX = src and src.x or 0, trimY = src and src.y or 0,
            sourceW = size and size.w or fr.w, sourceH = size and size.h or fr.h,
            name = f.filename, rotated = f.rotated,
            duration = f.duration and f.duration / 1000 or nil,
        }
    end
    local size = decoded.meta and decoded.meta.size
    return records, size and size.w, size and size.h
end

-- Starling / Sparrow sub-textures: a list of attribute tables (as produced by
-- any XML decoder) with x, y, width, height and optional frameX, frameY,
-- frameWidth, frameHeight. frameX and frameY are negative trim offsets.
---@param list table[]
---@return desAnim8.FrameRecord[]
function atlas.fromStarling(list)
    if type(list) ~= 'table' or list[1] == nil then
        error('fromStarling: expected a non-empty list of attribute tables', 2)
    end
    local records = {}
    for i, e in ipairs(list) do
        if e.rotated == true or e.rotated == 'true' then
            error(('fromStarling: entry %d is rotated; export the atlas without rotation'):format(i), 2)
        end
        records[i] = {
            x = e.x, y = e.y, w = e.width, h = e.height,
            trimX = -(e.frameX or 0), trimY = -(e.frameY or 0),
            sourceW = e.frameWidth or e.width, sourceH = e.frameHeight or e.height,
            name = e.name,
        }
    end
    return records
end

-- Aseprite "Array" export with frame tags, already decoded. Returns records
-- (durations in seconds), image width, image height, tags (1-based from/to) and
-- the slice list.
local function parseAseprite(decoded, level)
    if type(decoded) ~= 'table' or type(decoded.frames) ~= 'table' then
        error('fromAseprite: expected a decoded export table with a frames list', level)
    end
    local frames = decoded.frames
    if frames[1] == nil then
        error('fromAseprite: ' .. (next(frames) ~= nil and HASH_FORM or 'the export has no frames'), level)
    end
    local records = {}
    for i, f in ipairs(frames) do
        local fr, src, size = f.frame, f.spriteSourceSize, f.sourceSize
        if type(fr) ~= 'table' then error(('fromAseprite: frame %d has no frame rectangle'):format(i), level) end
        records[i] = {
            x = fr.x, y = fr.y, w = fr.w, h = fr.h,
            trimX = src and src.x or 0, trimY = src and src.y or 0,
            sourceW = size and size.w or fr.w, sourceH = size and size.h or fr.h,
            name = f.filename, rotated = f.rotated,
            duration = (f.duration or 100) / 1000,
        }
    end
    local meta = decoded.meta or {}
    local tags = {}
    for i, t in ipairs(meta.frameTags or {}) do
        tags[i] = { name = t.name, from = t.from + 1, to = t.to + 1, direction = t.direction or 'forward' }
    end
    return records, meta.size and meta.size.w, meta.size and meta.size.h, tags, meta.slices or {}
end

---@param decoded table
---@return desAnim8.FrameRecord[] records
---@return integer? imageWidth
---@return integer? imageHeight
---@return table[] tags
---@return table[] slices
function atlas.fromAseprite(decoded)
    return parseAseprite(decoded, 3)
end

local ASEPRITE_DIRECTIONS = { forward = true, reverse = true, pingpong = true, pingpong_reverse = true }

-- newFromAseprite(source, image, tag [, opts])
-- source: decoded export table, or a JSON string together with opts.decode.
-- tag: tag name; nil takes every frame, forward. Frame order and play mode come
-- from the tag direction (opts.playMode overrides the mode). Slices become frame
-- data (a slice with a pivot also sets `pivot`). Other opts go to the constructor.
-- The library never reads files or decodes JSON itself.
---@param source table|string decoded export, or JSON text with opts.decode
---@param image love.Texture?
---@param tag string? tag name; nil takes every frame
---@param opts (desAnim8.Options|{decode: (fun(text: string): table)?, playMode: desAnim8.PlayMode?})?
---@return desAnim8.Animation
local function newFromAseprite(source, image, tag, opts)
    local ctor = {}
    local decode, playMode
    for k, v in pairs(opts or {}) do
        if k == 'decode' then decode = v
        elseif k == 'playMode' then playMode = v
        else ctor[k] = v end
    end
    if ctor.data ~= nil then error('newFromAseprite: build the data from the export; opts.data is not accepted', 2) end
    local decoded = source
    if type(source) == 'string' then
        if type(decode) ~= 'function' then
            error('newFromAseprite: a JSON string needs opts.decode = function(text) returning a table', 2)
        end
        decoded = decode(source)
    elseif type(source) ~= 'table' then
        error('newFromAseprite: source must be a decoded export table or a JSON string', 2)
    end

    local records, iw, ih, tags, slices = parseAseprite(decoded, 3)
    if not (iw and ih) then
        if image ~= nil and type(image.getDimensions) == 'function' then
            iw, ih = image:getDimensions()
        else
            error('newFromAseprite: the export has no meta.size; pass the image so its size can be read', 2)
        end
    end

    local from, to, direction = 1, #records, 'forward'
    if tag ~= nil then
        local found
        for _, t in ipairs(tags) do
            if t.name == tag then found = t; break end
        end
        if not found then
            local names = {}
            for i, t in ipairs(tags) do names[i] = t.name end
            error(('newFromAseprite: no tag %q; the export has: %s'):format(
                tostring(tag), #names > 0 and table.concat(names, ', ') or '(none)'), 2)
        end
        from, to, direction = found.from, found.to, found.direction
        if from < 1 or to > #records or from > to then
            error(('newFromAseprite: tag %q has an invalid frame range'):format(tostring(tag)), 2)
        end
    end
    if not ASEPRITE_DIRECTIONS[direction] then
        error(('newFromAseprite: unknown tag direction %q'):format(tostring(direction)), 2)
    end

    local reverse = direction == 'reverse' or direction == 'pingpong_reverse'
    local order, subset = {}, {}
    for i = from, to do order[#order + 1] = i end
    if reverse then
        for i = 1, math.floor(#order / 2) do
            order[i], order[#order - i + 1] = order[#order - i + 1], order[i]
        end
    end
    for k, i in ipairs(order) do subset[k] = records[i] end

    local quads, data, durations = newFramesFromRecords(subset, iw, ih)
    for k, i in ipairs(order) do
        local absolute = i - 1
        for _, slice in ipairs(slices) do
            local key
            for _, candidate in ipairs(slice.keys or {}) do
                if candidate.frame <= absolute and (key == nil or candidate.frame > key.frame) then key = candidate end
            end
            if key then
                data[k] = data[k] or {}
                data[k][slice.name] = key.bounds
                if key.pivot and not data[k].pivot then data[k].pivot = key.pivot end
            end
        end
    end
    ctor.data = next(data) ~= nil and data or nil
    local mode = playMode or ((direction == 'pingpong' or direction == 'pingpong_reverse') and 'bounce' or 'loop')
    local anim = build(image, quads, durations, mode, ctor)
    return anim
end

return {
    newFramesFromRecords = newFramesFromRecords,
    newFromAseprite      = newFromAseprite,
    atlas                = atlas,
    _parseAseprite       = parseAseprite,
}
