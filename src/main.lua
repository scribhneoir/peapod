import "CoreLibs/timer"
import "CoreLibs/keyboard"
import 'CoreLibs/ui/gridview.lua'
import 'CoreLibs/nineslice'
import 'CoreLibs/graphics'

import "network"
import "ui"
import "sound"
import "file"
import "xml"

local network  <const> = Network
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

function playdate.update()
    playdate.graphics.clear()

    playdate.timer.updateTimers()


    network.update()
    ui.update()
    playdate.drawFPS(385, 228)
end
