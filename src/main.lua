import "CoreLibs/timer"
import "CoreLibs/keyboard"
import 'CoreLibs/ui/gridview.lua'
import 'CoreLibs/nineslice'
import 'CoreLibs/graphics'

import "network"
import "ui/ui"
import "sound"
import "handler/file"
import "handler/xml"

local network <const> = Network
local ui <const> = UI

-- setup
playdate.display.setRefreshRate(0) -- uncapped framerate

local lastFrameTime = playdate.getCurrentTimeMilliseconds()
DeltaTime = 0

function playdate.update()
    playdate.graphics.clear()
    playdate.timer.updateTimers()

    -- global delta time calculation
    local currentFrameTime = playdate.getCurrentTimeMilliseconds()
    DeltaTime = (currentFrameTime - lastFrameTime) / 1000
    lastFrameTime = currentFrameTime

    network.update()
    ui.update()
    playdate.drawFPS(385, 228)
end
