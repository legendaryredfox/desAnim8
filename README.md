### An animation library for making LÖVE games for the PSP

This project was based on [kikito's anim8](https://github.com/kikito/anim8). If you like it, please consider supporting his work

### Funny story

Not really, but I like the LÖVE framework, and one day decided to try and make games for the PSP, which is a great handheld. I ended up creating a few tools and adding a bit of code to repos that already existed. Then, a friend told  me that there could be a few people out there for whom this code could be useful, and I decided to make it public.  

This code will be updated whenever I have the time to spare on this project, so please be patient

### Disclaimers

- I'm not an experienced Lua or LÖVE developer, keep that in mind when using this code
- The code here has been tested by using RetroArch on a Linux system, in addition to a Sony PSP 3000
- Feel free to open issues, but if you decide to do so, please include a detailed description

### Example of implementation

```
local desAnim8 = require 'libraries.desAnim8'

local screenWidth = 480
local screenHeight = 272
local frameDuration = 0.15 -- Duration of each frame in seconds
local numFrames = 6 -- Number of frames in the animation
local imageWidth = 288 -- Width of the entire sprite sheet
local imageHeight = 48 -- Height of the entire sprite sheet

function love.load()
    local sprite = love.graphics.newImage('player.png')
    player = {}
    player.animations = {}
    player.animations['idle'] = desAnim8.new(sprite, <frame width>, <frame height>, numFrames, frameDuration, imageWidth, imageHeight)
    player.x = screenWidth / 2
    player.y = screenHeight / 2
end

function love.update(dt)
    player.animations['idle']:update(dt)
end

function love.draw()
    player.animations['idle']:draw(player.x, player.y)
end
```
