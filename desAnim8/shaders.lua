-- GLSL sources as plain strings. Public as desAnim8.shaders.

-- GLSL sources for Animation:setShader. They are plain strings, so nothing is
-- compiled until you call love.graphics.newShader(desAnim8.shaders.whiteFlash).
local shaders = {
    -- uniform float amount: 0 leaves the sprite alone, 1 paints it white.
    whiteFlash = [[
        uniform float amount;
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
            vec4 p = Texel(tex, uv) * color;
            return vec4(mix(p.rgb, vec3(1.0), amount), p.a);
        }
    ]],
    -- Sprites store a palette index in the red channel (0..1). `palette` holds one
    -- row of colors per swap; `row` (0-based) picks the row out of `rows`.
    paletteSwap = [[
        uniform Image palette;
        uniform float row;
        uniform float rows;
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
            vec4 p = Texel(tex, uv);
            vec4 mapped = Texel(palette, vec2(p.r, (row + 0.5) / rows));
            return vec4(mapped.rgb, p.a) * color;
        }
    ]],
    -- Draws `outlineColor` on transparent pixels next to opaque ones. `texel` is
    -- 1 / image size; leave a pixel of padding around frames in the sheet.
    outline = [[
        uniform vec2 texel;
        uniform vec4 outlineColor;
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
            vec4 p = Texel(tex, uv);
            float around = Texel(tex, uv + vec2(texel.x, 0.0)).a + Texel(tex, uv - vec2(texel.x, 0.0)).a
                         + Texel(tex, uv + vec2(0.0, texel.y)).a + Texel(tex, uv - vec2(0.0, texel.y)).a;
            if (p.a < 0.5 && around > 0.0) return outlineColor;
            return p * color;
        }
    ]],
}

return shaders
