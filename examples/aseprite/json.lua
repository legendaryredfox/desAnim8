-- Minimal JSON decoder (objects, arrays, strings, numbers, true/false/null; a null
-- simply leaves no entry).
-- desAnim8 never decodes JSON itself: this is the `decode` function the importer
-- is given. Any JSON library (rxi/json.lua, lunajson, ...) works the same way.
-- UTF-8 for a \uXXXX escape (basic multilingual plane only).
local function utf8char(code)
    if code < 0x80 then return string.char(code) end
    if code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
    end
    return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

local function decode(text)
    local pos = 1

    local function skip()
        pos = text:find('%S', pos) or #text + 1
    end

    local function fail(message)
        error(('json: %s at position %d'):format(message, pos), 0)
    end

    local value

    local function string_()
        local out, i = {}, pos + 1
        while true do
            local c = text:sub(i, i)
            if c == '' then fail('unterminated string') end
            if c == '"' then pos = i + 1; return table.concat(out) end
            if c == '\\' then
                local e = text:sub(i + 1, i + 1)
                local map = { n = '\n', t = '\t', r = '\r', b = '\b', f = '\f', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
                if e == 'u' then
                    out[#out + 1] = utf8char(tonumber(text:sub(i + 2, i + 5), 16))
                    i = i + 6
                else
                    out[#out + 1] = map[e] or fail('bad escape')
                    i = i + 2
                end
            else
                out[#out + 1] = c
                i = i + 1
            end
        end
    end

    function value()
        skip()
        local c = text:sub(pos, pos)
        if c == '{' then
            local obj = {}
            pos = pos + 1
            skip()
            if text:sub(pos, pos) == '}' then pos = pos + 1; return obj end
            while true do
                skip()
                if text:sub(pos, pos) ~= '"' then fail('expected a key') end
                local key = string_()
                skip()
                if text:sub(pos, pos) ~= ':' then fail("expected ':'") end
                pos = pos + 1
                obj[key] = value()
                skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d == '}' then return obj end
                if d ~= ',' then fail("expected ',' or '}'") end
            end
        elseif c == '[' then
            local list = {}
            pos = pos + 1
            skip()
            if text:sub(pos, pos) == ']' then pos = pos + 1; return list end
            while true do
                list[#list + 1] = value()
                skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d == ']' then return list end
                if d ~= ',' then fail("expected ',' or ']'") end
            end
        elseif c == '"' then
            return string_()
        elseif text:find('^true', pos) then pos = pos + 4; return true
        elseif text:find('^false', pos) then pos = pos + 5; return false
        elseif text:find('^null', pos) then pos = pos + 4; return nil
        end
        local number = text:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
        if not number or number == '' then fail('unexpected character') end
        pos = pos + #number
        return tonumber(number)
    end

    local result = value()
    skip()
    if pos <= #text then fail('trailing characters') end
    return result
end

return { decode = decode }
