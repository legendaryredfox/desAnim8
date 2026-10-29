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
        Animation library (also available as a single-file build): grids, play modes, per-frame durations,
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
        ['desAnim8.animation'] = 'desAnim8/animation.lua',
        ['desAnim8.atlas'] = 'desAnim8/atlas.lua',
        ['desAnim8.batch'] = 'desAnim8/batch.lua',
        ['desAnim8.composite'] = 'desAnim8/composite.lua',
        ['desAnim8.constructors'] = 'desAnim8/constructors.lua',
        ['desAnim8.debug'] = 'desAnim8/debug.lua',
        ['desAnim8.events'] = 'desAnim8/events.lua',
        ['desAnim8.frameinfo'] = 'desAnim8/frameinfo.lua',
        ['desAnim8.grid'] = 'desAnim8/grid.lua',
        ['desAnim8.options'] = 'desAnim8/options.lua',
        ['desAnim8.playback'] = 'desAnim8/playback.lua',
        ['desAnim8.render'] = 'desAnim8/render.lua',
        ['desAnim8.set'] = 'desAnim8/set.lua',
        ['desAnim8.shaders'] = 'desAnim8/shaders.lua',
        ['desAnim8.sheet'] = 'desAnim8/sheet.lua',
        ['desAnim8.state'] = 'desAnim8/state.lua',
        ['desAnim8.timeline'] = 'desAnim8/timeline.lua',
        ['desAnim8.timing'] = 'desAnim8/timing.lua',
        ['desAnim8.util'] = 'desAnim8/util.lua',
        ['desAnim8.watcher'] = 'desAnim8/watcher.lua',
    },
    copy_directories = { 'types' },
}

test = {
    type = 'command',
    command = 'lua tests/run.lua',
}
