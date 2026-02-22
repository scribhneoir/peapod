import "CoreLibs/timer"
import "CoreLibs/keyboard"
import 'CoreLibs/ui/gridview.lua'
import 'CoreLibs/nineslice'
import 'CoreLibs/graphics'


import "util"
import "network"
import "handler/file"
import "handler/xml"
import "ui/ui"
import "sound"


local network <const> = Network
local ui <const> = UI
local sound <const> = Sound
local timer <const> = playdate.timer
local getCurrentTimeMilliseconds <const> = playdate.getCurrentTimeMilliseconds

-- setup
playdate.display.setRefreshRate(0) -- uncapped framerate

local lastFrameTime = getCurrentTimeMilliseconds()
DeltaTime = 0

function playdate.update()
    timer.updateTimers()

    -- global delta time calculation
    local currentFrameTime = getCurrentTimeMilliseconds()
    DeltaTime = (currentFrameTime - lastFrameTime) / 1000
    lastFrameTime = currentFrameTime

    network.update()
    ui.update()
    sound.update()
    playdate.drawFPS(385, 228)
end
