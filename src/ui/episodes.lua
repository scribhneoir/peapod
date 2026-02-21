Episodes = {}

local file <const> = playdate.file
local gfx <const> = playdate.graphics

local NUMBER_OF_EPISODES = 5
local title
local strippedTitle
local subtitle
local feedUrl
local episodes
local xmlHandle
local image

local maskImage <const> = gfx.image.new(60, 60, gfx.kColorBlack)
gfx.lockFocus(maskImage)
gfx.setColor(gfx.kColorWhite)
gfx.fillRoundRect(0, 0, 60, 60, 3)
gfx.unlockFocus()

local listview = playdate.ui.gridview.new(0, 35)
listview:setNumberOfRows(1)
listview:setCellPadding(5, 5, 2, 2)

local function handleParsedItem(parsedItem)
    -- TODO: cache this data, since xml parsing takes forever
    table.insert(episodes, parsedItem)
    listview:setNumberOfRows(#episodes + 1)
end

function Episodes.init(args)
    title, subtitle, feedUrl = args.title, args.subtitle, args.feedUrl
    episodes = {}
    listview:setNumberOfRows(1)
    strippedTitle = StripString(title)
    if file.exists("cache/feeds/" .. strippedTitle .. ".xml") then --todo: check if cached file modtime is recent enough
        xmlHandle = Xml.new("cache/feeds/" .. strippedTitle .. ".xml", "item", handleParsedItem, NUMBER_OF_EPISODES)
    else
        Network.fetch(feedUrl, function()
                xmlHandle = Xml.new("cache/feeds/" .. strippedTitle .. ".xml", "item", handleParsedItem, 2)
            end,
            "cache/feeds/" .. strippedTitle .. ".xml")
    end
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

function Episodes.update()
    if listview.needsDisplay then
        playdate.graphics.clear()
        if image then
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            image:draw(5, 5)
        elseif file.exists("cache/artwork/" .. strippedTitle .. ".pdi") then
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            local image = gfx.image.new("cache/artwork/" .. strippedTitle .. ".pdi")
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
end

local function handleUp()
    listview:selectPreviousRow(false)
end

local function handleDown()
    if not xmlHandle then
        return
    end
    if listview:getSelectedRow() >= #episodes - 2 then
        xmlHandle:setMaxItems(#episodes + 3)
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
    local title = StripString(episode.title or "No title")
    if episode.enclosure then
        local url = episode.enclosure._attr.url
        -- local url = "https://audio.transistor.fm/m/shows/11787/f5eb5f9a729a19122bce1b54a0d1ba14.mp3"
        print(title)
        Sound.stream(url, "cache/audio/" .. title .. ".mp3")
    end
end

function Episodes.BButtonUp()
    Episodes.switchScene("DISCOVER")
    episodes = nil
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
