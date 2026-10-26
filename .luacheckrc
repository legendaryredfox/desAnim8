-- Lua 5.1 / LuaJIT target; LÖVE provides the `love` global.
std = 'min'
read_globals = { 'love' }
max_line_length = false
-- tests assign to love and print to mock the environment
files['tests/**'] = { globals = { 'love', 'print' } }
