rockspec_format = '3.0'
package = 'desanim8'
version = '0.10.0-1'

source = {
    url = 'git+https://github.com/legendaryredfox/desAnim8.git',
    tag = 'v0.10.0',
}

description = {
    summary = 'Sprite animation library for LÖVE 11.5, based on anim8',
    detailed = [[
        Single-file animation library: grids, play modes, per-frame durations,
        speed and reverse playback, frame events, Aseprite and atlas import,
        named clips, layered composites, keyframe transforms and batched
        animations. Draws with love.graphics.draw and Quads only, so it also
        runs on LÖVE-compatible console layers.
    ]],
    homepage = 'https://github.com/legendaryredfox/desAnim8',
    license = 'MIT',
}

dependencies = {
    'lua >= 5.1',
}

build = {
    type = 'builtin',
    modules = {
        desAnim8 = 'desAnim8.lua',
    },
}

test = {
    type = 'command',
    command = 'lua tests/run.lua',
}
