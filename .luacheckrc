-- Lua 5.1 / LuaJIT target; LÖVE provides the `love` global.
std = 'min'
read_globals = { 'love' }
max_line_length = false

-- Checks such as not (x >= y) are written that way on purpose: unlike x < y they
-- also reject NaN.
ignore = { '581' }

-- The tests replace parts of `love` and `print` to mock the environment and keep
-- throwaway locals for readability.
files['tests/**'] = {
    globals = { 'love', 'print' },
    ignore = { '581', '211', '212', '213', '231', '311', '331' },
}
-- Game code defines the love callbacks.
files['examples/**'] = { globals = { 'love' } }
