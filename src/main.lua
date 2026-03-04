import "CoreLibs/timer"
import "CoreLibs/keyboard"
import 'CoreLibs/ui/gridview.lua'
import 'CoreLibs/nineslice'
import 'CoreLibs/graphics'
import 'CoreLibs/string'


import "util"
import "network"
import "handler/file"
import "handler/xml"
import "handler/mp3"
import "ui/ui"


local network <const> = Network
local ui <const> = UI
local timer <const> = playdate.timer
local getCurrentTimeMilliseconds <const> = playdate.getCurrentTimeMilliseconds

-- setup
playdate.display.setRefreshRate(0) -- uncapped framerate

local lastFrameTime = getCurrentTimeMilliseconds()
DeltaTime = 0
local click = playdate.sound.sampleplayer.new("assets/sound/click")
PlayClick = function()
    if click:isPlaying() then return end
    click:play()
end

function playdate.update()
    timer.updateTimers()

    -- global delta time calculation
    local currentFrameTime = getCurrentTimeMilliseconds()
    DeltaTime = (currentFrameTime - lastFrameTime) / 1000
    lastFrameTime = currentFrameTime

    ui.update()
    playdate.drawFPS(385, 228)
end
