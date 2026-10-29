---@meta desAnim8

---@class desAnim8
---@field _VERSION string
---@field _DESCRIPTION string
---@field _URL string
---@field _THANKS string
---@field _LICENSE string
---@field maxImageSize integer? advisory limit: newGrid warns when an image is larger
---@field shaders {whiteFlash: string, paletteSwap: string, outline: string}
local desAnim8 = {}

desAnim8.atlas = {}
desAnim8.debug = {}

---@alias desAnim8.PlayMode 'loop'|'once'|'bounce'|'bounceOnce'|'random'
---@alias desAnim8.Durations number|number[]|table<string, number>
---@alias desAnim8.Easing 'linear'|'inQuad'|'outQuad'|'inOutQuad'|'inCubic'|'outCubic'|'inOutCubic'|fun(t: number): number

---@class desAnim8.Options
---@field ticks boolean? integer durations and steps, exact on every platform
---@field weights number[]? per-frame weights for the 'random' mode
---@field jitter number? random duration spread in [0,1), per instance
---@field rng (fun(): number)? random source returning [0,1)
---@field randomLength integer? length of the generated 'random' order (default 32)
---@field data table<integer, table<string, any>>? per-frame data: hitbox, pivot, trim, transform, ...

---@class desAnim8.FrameRecord
---@field x number
---@field y number
---@field w number
---@field h number
---@field trimX number?
---@field trimY number?
---@field sourceW number?
---@field sourceH number?
---@field name string?
---@field duration number? seconds
---@field rotated (boolean|'cw'|'ccw')? stored turned 90 degrees (true is clockwise)

---@class desAnim8.Rect
---@field x number
---@field y number
---@field w number
---@field h number

---@class desAnim8.Animation
---@field status 'playing'|'paused' read only
---@field currentFrame integer 1-based, read only
---@field playMode desAnim8.PlayMode read only
---@field image love.Texture? the bound image
---@field frames love.Quad[] read only
---@field flippedH boolean
---@field flippedV boolean
---@field onLoop (string|fun(anim: desAnim8.Animation, loops: integer))?
---@field onStart (string|fun(anim: desAnim8.Animation))?
---@field onEnd (string|fun(anim: desAnim8.Animation))?
local Animation = {}

---@return desAnim8.Animation
function Animation:clone() end

---@param dt number
---@return nil
function Animation:update(dt) end

---@param n integer?
---@return nil
function Animation:tick(n) end

---@return integer index
---@return love.Quad quad
function Animation:getCurrentFrame() end

---@return integer
function Animation:getCurrentFrameNumber() end

---@return integer w
---@return integer h
function Animation:getDimensions() end

---@return integer
function Animation:getFrameCount() end

---@return number seconds
function Animation:getDuration() end

---@return desAnim8.PlayMode
function Animation:getPlayMode() end

---@return number seconds
function Animation:getRemainingTime() end

---@return number phase 0..1
function Animation:getPhase() end

---@param p number clamped to 0..1
---@return nil
function Animation:setPhase(p) end

---@return integer
function Animation:getLoopCount() end

---@return boolean
function Animation:isFinished() end

---@param n integer
---@return nil
function Animation:gotoFrame(n) end

---@return boolean
function Animation:isPlaying() end

---@return boolean
function Animation:isPaused() end

---@param rate number negative plays backwards
---@return desAnim8.Animation
function Animation:setSpeed(rate) end

---@return number
function Animation:getSpeed() end

---@param seconds number
---@return desAnim8.Animation
function Animation:fitDuration(seconds) end

---@param seconds number
---@return desAnim8.Animation
function Animation:freeze(seconds) end

---@param seconds number?
---@return desAnim8.Animation
function Animation:setStep(seconds) end

---@param easing desAnim8.Easing?
---@return desAnim8.Animation
function Animation:setEasing(easing) end

---@param rng (fun(): number)?
---@return nil
function Animation:randomizeStart(rng) end

---@param mode desAnim8.PlayMode
---@return desAnim8.Animation
function Animation:setPlayMode(mode) end

---@param durations desAnim8.Durations
---@return desAnim8.Animation
function Animation:setDurations(durations) end

---@param from integer
---@param to integer
---@return desAnim8.Animation
function Animation:setLoopRange(from, to) end

---@return desAnim8.Animation
function Animation:clearLoopRange() end

---@return desAnim8.Animation
function Animation:release() end

---@return nil
function Animation:wait() end

---@param n integer
---@param fn fun(anim: desAnim8.Animation, frame: integer)
---@return desAnim8.Animation
function Animation:onFrame(n, fn) end

---@param n integer
---@param fn function?
---@return desAnim8.Animation
function Animation:offFrame(n, fn) end

---@param t number seconds into the sequence
---@param fn fun(anim: desAnim8.Animation, t: number)
---@return desAnim8.Animation
function Animation:addMarker(t, fn) end

---@return desAnim8.Animation
function Animation:clearMarkers() end

---@return number
---@nodiscard
function Animation:getFrameProgress() end

---@param enabled boolean
---@param easing desAnim8.Easing?
---@return desAnim8.Animation
function Animation:setInterpolation(enabled, easing) end

---@return love.Quad quad
---@return number? x
---@return number? y
---@return number? r
---@return number? sx
---@return number? sy
---@return number? ox
---@return number? oy
---@return number? kx
---@return number? ky
function Animation:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky) end

---@param name string
---@param frame integer?
---@return any
function Animation:getFrameData(name, frame) end

---@param enabled boolean
---@return desAnim8.Animation
function Animation:setAutoPivot(enabled) end

---@param name string
---@return number? x
---@return number? y
---@return number? w
---@return number? h
function Animation:getWorldRect(name, x, y, sx, sy, ox, oy) end

---@param batch love.SpriteBatch
---@param ... number x, y, r, sx, sy, ox, oy, kx, ky
---@return integer id
function Animation:addToBatch(batch, ...) end

---@param batch love.SpriteBatch
---@param id integer
---@param ... number x, y, r, sx, sy, ox, oy, kx, ky
function Animation:setInBatch(batch, id, ...) end

---@param a number|love.Texture x, or the image for an image-less animation
---@param b number y, or x for an image-less animation
---@param ... number r, sx, sy, ox, oy, kx, ky
function Animation:draw(a, b, ...) end

---@param r number?
---@param g number?
---@param b number?
---@param a number?
---@return desAnim8.Animation
function Animation:setColor(r, g, b, a) end

---@param a number
---@return desAnim8.Animation
function Animation:setAlpha(a) end

---@param mode love.BlendMode?
---@param alphaMode love.BlendAlphaMode?
---@return desAnim8.Animation
function Animation:setBlendMode(mode, alphaMode) end

---@param shader love.Shader?
---@param uniforms table<string, any>?
---@return desAnim8.Animation
function Animation:setShader(shader, uniforms) end

---@param seconds number
---@param r number?
---@param g number?
---@param b number?
---@return desAnim8.Animation
function Animation:flash(seconds, r, g, b) end

---@param dx number
---@return desAnim8.Animation
function Animation:faceTowards(dx) end

---@param direction 1|-1
---@return desAnim8.Animation
function Animation:setDefaultFacing(direction) end

---@param enabled boolean
---@return desAnim8.Animation
function Animation:setPixelSnap(enabled) end

---@param count integer?
---@param spacing integer?
---@param alpha number?
---@return desAnim8.Animation
function Animation:setTrail(count, spacing, alpha) end

---@return table[]
function Animation:getTrail() end

---@param before integer?
---@param after integer?
---@return desAnim8.Animation
function Animation:setOnion(before, after) end

---@return nil
function Animation:drawBounds(x, y, r, sx, sy, ox, oy, kx, ky) end

---@return desAnim8.Animation
function Animation:flipH() end

---@return desAnim8.Animation
function Animation:flipV() end

---@param flipped boolean
---@return desAnim8.Animation
function Animation:setFlipH(flipped) end

---@param flipped boolean
---@return desAnim8.Animation
function Animation:setFlipV(flipped) end

---@return table
function Animation:getState() end

---@param s table
---@return desAnim8.Animation
function Animation:setState(s) end

---@class desAnim8.Grid
---@field frameWidth integer
---@field frameHeight integer
---@field imageWidth integer
---@field imageHeight integer
---@field left integer
---@field top integer
---@field border integer
---@field inset number
---@field cols integer
---@field rows integer
---@overload fun(self: desAnim8.Grid, ...: number|string): love.Quad[]
local Grid = {}

---@param frameWidth integer
---@param frameHeight integer
---@param imageWidth integer
---@param imageHeight integer
---@param left integer?
---@param top integer?
---@param border integer?
---@param inset number?
---@return desAnim8.Grid
function desAnim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight, left, top, border, inset) end

---@param ... number|string column and row ranges, in pairs
---@return love.Quad[]
function Grid:getFrames(...) end

---@return nil
function Grid:clearCache() end

---@param image love.Texture
---@param frameWidth integer
---@param frameHeight integer
---@param left integer?
---@param top integer?
---@param border integer?
---@param inset number?
---@return desAnim8.Grid
function desAnim8.newGridFromImage(image, frameWidth, frameHeight, left, top, border, inset) end

---@param image love.Texture?
---@param ... any frames, durations [, playMode [, opts]] or the legacy single-row arguments
---@return desAnim8.Animation
function desAnim8.new(image, ...) end

---@param frames love.Quad[]
---@param durations desAnim8.Durations
---@param playMode desAnim8.PlayMode?
---@param opts desAnim8.Options?
---@return desAnim8.Animation
function desAnim8.newAnimation(frames, durations, playMode, opts) end

---@param image love.Texture?
---@param quads love.Quad[]
---@param durations desAnim8.Durations
---@param playMode desAnim8.PlayMode?
---@param opts desAnim8.Options?
---@return desAnim8.Animation
function desAnim8.newAnimationFromQuads(image, quads, durations, playMode, opts) end

---@param records desAnim8.FrameRecord[]
---@param imageWidth integer
---@param imageHeight integer
---@return love.Quad[] quads
---@return table<integer, table> data
---@return number[]? durations
function desAnim8.newFramesFromRecords(records, imageWidth, imageHeight) end

---@param decoded table
---@return desAnim8.FrameRecord[] records
---@return integer? imageWidth
---@return integer? imageHeight
function desAnim8.atlas.fromTexturePacker(decoded) end

---@param list table[]
---@return desAnim8.FrameRecord[]
function desAnim8.atlas.fromStarling(list) end

---@param decoded table
---@return desAnim8.FrameRecord[] records
---@return integer? imageWidth
---@return integer? imageHeight
---@return table[] tags
---@return table[] slices
function desAnim8.atlas.fromAseprite(decoded) end

---@param source table|string decoded export, or JSON text with opts.decode
---@param image love.Texture?
---@param tag string? tag name; nil takes every frame
---@param opts (desAnim8.Options|{decode: (fun(text: string): table)?, playMode: desAnim8.PlayMode?})?
---@return desAnim8.Animation
function desAnim8.newFromAseprite(source, image, tag, opts) end

---@param quads love.Quad[]
---@param imageData love.ImageData
---@param threshold number?
---@return desAnim8.Rect[]
function desAnim8.scanBounds(quads, imageData, threshold) end

---@param lists table<string, any[]>
---@return table<integer, table<string, any>>
function desAnim8.dataFromLists(lists) end

---@param imageData love.ImageData
---@param opts {threshold: number?, mergeGap: integer?, minSize: integer?}?
---@return desAnim8.Rect[]
function desAnim8.sliceByAlpha(imageData, opts) end

---@param rects desAnim8.Rect[]
---@param imageWidth integer
---@param imageHeight integer
---@return love.Quad[]
function desAnim8.newQuadsFromRects(rects, imageWidth, imageHeight) end

---@class desAnim8.Set
---@field onChange (fun(set: desAnim8.Set, from: string, to: string))?
local Set = {}

---@param clips table<string, desAnim8.Animation>
---@param initial string?
---@return desAnim8.Set
function desAnim8.newSet(clips, initial) end

---@param name string
---@param opts {keepPhase: boolean?, restart: boolean?}?
---@return desAnim8.Set
function Set:play(name, opts) end

---@param name string
---@return desAnim8.Set
function Set:queue(name) end

---@param name string
---@param nextName string?
---@return desAnim8.Set
function Set:setNext(name, nextName) end

---@param dt number
function Set:update(dt) end

---@return desAnim8.Animation
---@return string name
function Set:getCurrent() end

---@param name string
---@return desAnim8.Animation?
function Set:getClip(name) end

---@param source table|string
---@param image love.Texture?
---@param opts table?
---@return desAnim8.Set
function desAnim8.newSetFromAseprite(source, image, opts) end

---@class desAnim8.Composite
---@field flippedH boolean
---@field flippedV boolean
local Composite = {}

---@param layers {anim: desAnim8.Animation|desAnim8.Set, dx: number?, dy: number?, hidden: boolean?, image: love.Texture?}[]
---@return desAnim8.Composite
function desAnim8.newComposite(layers) end

---@class desAnim8.Batch
local Batch = {}

---@param image love.Texture
---@param frames love.Quad[]
---@param durations desAnim8.Durations
---@param playMode desAnim8.PlayMode?
---@param capacity integer
---@param opts desAnim8.Options?
---@return desAnim8.Batch
function desAnim8.newBatch(image, frames, durations, playMode, capacity, opts) end

---@return integer id
function Batch:add(x, y, r, sx, sy, ox, oy, kx, ky) end

---@param id integer
function Batch:remove(id) end

---@param id integer
---@return integer
function Batch:getFrame(id) end

---@param dt number
function Batch:update(dt) end

---@class desAnim8.Watcher
local Watcher = {}

---@param path string
---@param onChange fun(path: string)
---@param statFn (fun(path: string): number?)?
---@return desAnim8.Watcher
function desAnim8.newWatcher(path, onChange, statFn) end

---@return boolean changed
function Watcher:poll() end

---@param anim desAnim8.Animation
---@return nil
function desAnim8.debug.drawTimeline(anim, x, y, w, h) end

---@param anim desAnim8.Animation
---@return boolean
function desAnim8.debug.scrub(anim, mx, my, x, y, w, h) end

---@param scale number >= 0
---@return nil
function desAnim8.setTimeScale(scale) end

---@return number
function desAnim8.getTimeScale() end

---@param a number|love.Texture x, or the image for an image-less animation
---@param b number y, or x for an image-less animation
---@param ... number r, sx, sy, ox, oy, kx, ky
function Set:draw(a, b, ...) end

---@return love.Quad quad
---@return number? x
---@return number? y
---@return number? r
---@return number? sx
---@return number? sy
---@return number? ox
---@return number? oy
---@return number? kx
---@return number? ky
function Set:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky) end

---@return nil
function Set:pause() end

---@return nil
function Set:resume() end

---@return nil
function Set:pauseAtEnd() end

---@return nil
function Set:pauseAtStart() end

---@return nil
function Set:stop() end

---@return nil
function Set:reset() end

---@param n integer
---@return nil
function Set:gotoFrame(n) end

---@return boolean
function Set:isPlaying() end

---@return boolean
function Set:isPaused() end

---@return integer index
---@return love.Quad quad
function Set:getCurrentFrame() end

---@return integer
function Set:getCurrentFrameNumber() end

---@return integer w
---@return integer h
function Set:getDimensions() end

---@return integer
function Set:getFrameCount() end

---@return number seconds
function Set:getDuration() end

---@return desAnim8.PlayMode
function Set:getPlayMode() end

---@return number seconds
function Set:getRemainingTime() end

---@return number phase 0..1
function Set:getPhase() end

---@param p number clamped to 0..1
---@return nil
function Set:setPhase(p) end

---@return integer
function Set:getLoopCount() end

---@return boolean
function Set:isFinished() end

---@return desAnim8.Set
function Set:flipH() end

---@return desAnim8.Set
function Set:flipV() end

---@param flipped boolean
---@return desAnim8.Set
function Set:setFlipH(flipped) end

---@param flipped boolean
---@return desAnim8.Set
function Set:setFlipV(flipped) end

---@param dx number
---@return desAnim8.Set
function Set:faceTowards(dx) end

---@param rate number negative plays backwards
---@return desAnim8.Set
function Set:setSpeed(rate) end

---@return number
function Set:getSpeed() end

---@param seconds number
---@return desAnim8.Set
function Set:fitDuration(seconds) end

---@param seconds number
---@return desAnim8.Set
function Set:freeze(seconds) end

---@param seconds number
---@param r number?
---@param g number?
---@param b number?
---@return desAnim8.Set
function Set:flash(seconds, r, g, b) end

---@param name string
---@param frame integer?
---@return any
function Set:getFrameData(name, frame) end

---@param name string
---@return number? x
---@return number? y
---@return number? w
---@return number? h
function Set:getWorldRect(name, x, y, sx, sy, ox, oy) end

---@return nil
function Set:drawBounds(x, y, r, sx, sy, ox, oy, kx, ky) end

---@param batch love.SpriteBatch
---@param ... number x, y, r, sx, sy, ox, oy, kx, ky
---@return integer id
function Set:addToBatch(batch, ...) end

---@param batch love.SpriteBatch
---@param id integer
---@param ... number x, y, r, sx, sy, ox, oy, kx, ky
function Set:setInBatch(batch, id, ...) end

---@return nil
function Set:wait() end

---@return number
---@nodiscard
function Set:getFrameProgress() end

---@param r number?
---@param g number?
---@param b number?
---@param a number?
---@return desAnim8.Set
function Set:setColor(r, g, b, a) end

---@param a number
---@return desAnim8.Set
function Set:setAlpha(a) end

---@param mode love.BlendMode?
---@param alphaMode love.BlendAlphaMode?
---@return desAnim8.Set
function Set:setBlendMode(mode, alphaMode) end

---@param shader love.Shader?
---@param uniforms table<string, any>?
---@return desAnim8.Set
function Set:setShader(shader, uniforms) end

---@param enabled boolean
---@return desAnim8.Set
function Set:setPixelSnap(enabled) end

---@param direction 1|-1
---@return desAnim8.Set
function Set:setDefaultFacing(direction) end

---@param enabled boolean
---@return desAnim8.Set
function Set:setAutoPivot(enabled) end

---@return nil
function Animation:pause() end

---@return nil
function Animation:resume() end

---@return nil
function Animation:pauseAtEnd() end

---@return nil
function Animation:pauseAtStart() end

---@return nil
function Animation:stop() end

---@return nil
function Animation:reset() end

---@return nil
function Batch:clear() end

---@return integer
function Batch:getCount() end

---@param id integer
---@param x number
---@param y number
---@param r number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
---@return nil
function Batch:set(id, x, y, r, sx, sy, ox, oy, kx, ky) end

---@param id integer
---@param horizontal boolean?
---@param vertical boolean?
---@return nil
function Batch:setFlip(id, horizontal, vertical) end

---@param id integer
---@param rate number
---@return nil
function Batch:setSpeed(id, rate) end

---@param id integer
---@param p number clamped to 0..1
---@return nil
function Batch:setPhase(id, p) end

---@param rng (fun(): number)?
---@return nil
function Batch:randomizePhases(rng) end

---@param ... number x, y, r, sx, sy, ox, oy, kx, ky
---@return nil
function Batch:draw(...) end

---@param dt number
---@return nil
function Composite:update(dt) end

---@param x number
---@param y number
---@param r number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
---@return nil
function Composite:draw(x, y, r, sx, sy, ox, oy, kx, ky) end

---@param index integer
---@return desAnim8.Animation|desAnim8.Set?
function Composite:getLayer(index) end

---@param index integer
---@param hidden boolean
---@return desAnim8.Composite
function Composite:setHidden(index, hidden) end

---@param flipped boolean
---@return desAnim8.Composite
function Composite:setFlipH(flipped) end

---@param flipped boolean
---@return desAnim8.Composite
function Composite:setFlipV(flipped) end

---@return desAnim8.Composite
function Composite:flipH() end

---@return desAnim8.Composite
function Composite:flipV() end

---@param dx number
---@return desAnim8.Composite
function Composite:faceTowards(dx) end

---@param p number
---@return desAnim8.Composite
function Composite:setPhase(p) end

---@return number
function Composite:getPhase() end

---@return boolean
function Composite:isPlaying() end

---@return desAnim8.Composite
function Composite:pause() end

---@return desAnim8.Composite
function Composite:resume() end

---@return desAnim8.Composite
function Composite:reset() end

---@return desAnim8.Composite
function Composite:stop() end

---@return desAnim8.Composite
function Composite:pauseAtEnd() end

---@return desAnim8.Composite
function Composite:pauseAtStart() end

return desAnim8
