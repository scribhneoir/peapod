import "CoreLibs/timer"
import "CoreLibs/keyboard"
import 'CoreLibs/ui/gridview.lua'
import 'CoreLibs/nineslice'
import 'CoreLibs/graphics'

import "network"
import "ui/ui"
import "sound"
import "handler/file"
import "xml"

local network <const> = Network
local ui <const> = UI

-- setup
playdate.display.setRefreshRate(0) -- uncapped framerate
-- local function setup()
--     local file = playdate.file.open("distractible.txt")
--     assert(file, "Failed to open distractible.txt")
--     local xml = file:read(playdate.file.getSize("distractible.txt"))
--     file:close()
--     local dat = string.gsub(xml, "<br>", "")
--     local items = ParseXML(dat)
--     print(items)
-- end
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
