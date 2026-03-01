Episodes = {
    switchScene = nil, -- will be set by ui.lua
}

local file <const> = playdate.file
local gfx <const> = playdate.graphics

local numberOfEpisodes = 5
local id
local title
local strippedTitle
local subtitle
local feedUrl
local episodes
local xmlHandle
local image
local mp3Handle

local maskImage <const> = gfx.image.new(60, 60, gfx.kColorBlack)
gfx.lockFocus(maskImage)
gfx.setColor(gfx.kColorWhite)
gfx.fillRoundRect(0, 0, 60, 60, 3)
gfx.unlockFocus()

local listview = playdate.ui.gridview.new(0, 35)
listview:setNumberOfRows(1)
listview:setCellPadding(5, 5, 2, 2)

function Episodes.init(args)
    id, title, subtitle, feedUrl = args.id, args.title, args.subtitle, args.feedUrl
    print(id)
    episodes = {}
    numberOfEpisodes = 5
    listview:setNumberOfRows(1)
    xmlHandle = XmlHandle.new({
        description = "description",
        link = "link",
    }, "item", {
        title = "title",
        description = "description",
        pubDate = "pubDate",
        enclosure = "enclosure._attr",
        episode = "itunes:episode",
        season = "itunes:season",
    }, "shows/" .. id .. "/", "episodes", feedUrl)
    Network.fetch(feedUrl, xmlHandle)
end

local titleFont = gfx.font.new('assets/fonts/Quickboot/Quickboot')
titleFont:setTracking(8)

local subfont = gfx.font.new('assets/fonts/Nontendo/Nontendo-Light')

function listview:drawCell(_, row, _, selected, x, y, width, height)
    if episodes and episodes[row] then
        local episode = episodes[row]
        local title = episode.title or "No title"
        if selected then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(x, y, width, height, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
            gfx.drawRoundRect(x, y, width, height, 4)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
        gfx.setFont(subfont)
        gfx.drawTextInRect(title, x + 6, y + 6, width - 12, 32, nil, "...", kTextAlignment.left)
    else
        gfx.drawRoundRect(x, y, width, height, 4)
        gfx.setFont(subfont)
        gfx.drawText("Loading...", x + 6, y + 6)
    end
end

local function getEpisodes()
    if numberOfEpisodes > #episodes then
        local fileNames = {}
        local fileList = file.listFiles("shows/" .. id .. "/episodes")
        table.move(fileList, #fileList - numberOfEpisodes - 1, #fileList - #episodes - 1, 1, fileNames)
        fileList = {}
        for i = #fileNames, 1, -1 do
            local fileName = fileNames[i]
            if fileName then
                local path = "shows/" .. id .. "/episodes/" .. fileName
                local data = json.decodeFile(path)
                table.insert(episodes, data)
            else
                print(i)
            end
            listview:setNumberOfRows(#episodes + 1)
        end
    end
end


function Episodes.update()
    if listview.needsDisplay then
        playdate.graphics.clear()
        if image then
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            image:draw(5, 5)
        elseif file.exists("cache/artwork/" .. id .. ".pdi") then
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            local image = gfx.image.new("cache/artwork/" .. id .. ".pdi")
            assert(image, "Failed to load image for " .. title)
            image:setMaskImage(maskImage)
            image = image
            image:draw(5, 5)
        else
            gfx.fillRoundRect(5, 5, 60, 60, 3)
        end
        gfx.setFont(titleFont)
        gfx.drawText(title, 70, 5, 380)
        if subtitle and subtitle ~= "" then
            gfx.setFont(subfont)
            gfx.drawText(subtitle, 70, 22, 380)
        end
        listview:drawInRect(0, 70, 400, 170)
    end
    if xmlHandle then
        xmlHandle:update()
    end
    getEpisodes()
end

local function handleUp()
    listview:selectPreviousRow(false)
end

local function handleDown()
    if not xmlHandle then
        return
    end
    if listview:getSelectedRow() >= #episodes - 2 then
        numberOfEpisodes = numberOfEpisodes + 5
    end
    listview:selectNextRow(false)
end

function Episodes.upButtonUp()
    handleUp()
end

function Episodes.downButtonUp()
    handleDown()
end

function Episodes.AButtonUp()
    if not episodes or not episodes[listview:getSelectedRow()] then
        return
    end
    local episode = episodes[listview:getSelectedRow()]
    if episode.enclosure then
        local url = episode.enclosure.url
        mp3Handle = Mp3Handle.new("shows/" .. id .. "/" .. StripString(episode.title) .. ".mp3")
        Network.fetch(url, mp3Handle, 10, true)
    end
end

function Episodes.BButtonUp()
    Episodes.switchScene("DISCOVER")
    Network.cancel(feedUrl)
    -- todo: cancelling early will keep old episodes from ever being fetched,
    -- due to the xml handler prematurely haulting download / parse once it runs into redundant data
    listview:setNumberOfRows(1)
    episodes = {}

    xmlHandle = nil
    image = nil
    collectgarbage()
end

local clickDegrees <const> = 360 / 15
local degreesSinceClick = 0

function Episodes.cranked(change, acceleratedChange)
    degreesSinceClick += acceleratedChange

    local clickCount = 0

    if degreesSinceClick > clickDegrees then
        while degreesSinceClick > clickDegrees do
            clickCount += 1
            degreesSinceClick -= clickDegrees
        end
        degreesSinceClick = 0
    elseif degreesSinceClick < -clickDegrees then
        while degreesSinceClick < -clickDegrees do
            clickCount -= 1
            degreesSinceClick += clickDegrees
        end
        degreesSinceClick = 0
    end

    if clickCount > 0 then
        handleUp()
    elseif clickCount < 0 then
        handleDown()
    end
end

function playdate.gameWillPause()
    if mp3Handle then
        mp3Handle:pause()
    end
end

function playdate.gameWillResume()
    if mp3Handle then
        mp3Handle:resume()
    end
end
