local file <const> = playdate.file
local gfx <const> = playdate.graphics
local keyboard <const> = playdate.keyboard
Discover = {
    switchScene = nil, -- set in ui.lua
}

function StripString(str)
    local stripped = str:gsub("%s+", "_")
    stripped:gsub("[^%w_]", "")
    stripped:gsub("æ", "ae")
    stripped:gsub("ø", "o")
    stripped:gsub("å", "a")
    stripped:gsub(":", "")
    return string.lower(stripped)
end

local function parseSubtitle(title)
    local separatorIndex = string.find(title, "%-") or string.find(title, ":")
    if separatorIndex then
        return string.sub(title, 1, separatorIndex - 1):gsub("%s+$", ""),
            string.sub(title, separatorIndex + 1):gsub("^%s+", "")
    else
        return title, ""
    end
end

local maskImage <const> = gfx.image.new(60, 60, gfx.kColorBlack)
gfx.lockFocus(maskImage)
gfx.setColor(gfx.kColorWhite)
gfx.fillRoundRect(0, 0, 60, 60, 3)
gfx.unlockFocus()


local imagesInMemory = {}
local titles = {}
local subtitles = {}
local feedUrls = {}
local searchTerm = "into the aether";
local oldTerm = nil
local fetched = false
local queuedFetch = false

local NUMBER_OF_RESULTS = 10

local function parseDiscoverData(fileHandle)
    local data = fileHandle:read()
    if (not data) then
        print("Failed to read discover data")
        fileHandle:delete()
        queuedFetch = false
        return
    end
    for _, value in pairs(data.results) do
        local title, subtitle = parseSubtitle(value.trackName)
        local artworkUrl = value.artworkUrl60
        local feedUrl = value.feedUrl
        local strippedTitle = StripString(title)
        if not file.exists("cache/artwork/" .. strippedTitle .. ".pdi") then
            print("Fetching artwork for:", strippedTitle)
            Network.fetch("https://pdi-image-converter.scribhneoir.workers.dev/?url=" .. artworkUrl, function(file)
            end, "cache/artwork/" .. strippedTitle .. ".pdi")
        end
        titles[#titles + 1] = title
        subtitles[#subtitles + 1] = subtitle
        feedUrls[#feedUrls + 1] = feedUrl
    end
    fetched = true
end

local function fetchDiscoverData()
    if file.exists("cache/search/" .. searchTerm .. ".json") then --todo: check if cached file modtime is recent enough
        parseDiscoverData(File.new("cache/search/" .. searchTerm .. ".json"))
    else
        Network.fetch("https://itunes.apple.com/search?media=podcast&term=" .. searchTerm:gsub(" ", "+") .. "&limit=" ..
            NUMBER_OF_RESULTS, function(file)
                parseDiscoverData(file)
            end, "cache/search/" .. searchTerm .. ".json")
    end
    queuedFetch = true
end

local subfont = gfx.font.new('assets/fonts/Nontendo/Nontendo-Light')
local titleFont = gfx.font.new('assets/fonts/Quickboot/Quickboot')
titleFont:setTracking(8)

local listview = playdate.ui.gridview.new(0, 70)
listview:setNumberOfRows(NUMBER_OF_RESULTS)
listview:setCellPadding(5, 5, 2, 2)

function listview:drawCell(_, row, _, selected, x, y, width, height)
    if titles[row] then
        local title = titles[row]
        local subtitle = subtitles[row]
        local strippedTitle = StripString(title)
        if selected then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(x, y, width, height, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
            gfx.drawRoundRect(x, y, width, height, 4)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
        gfx.setFont(titleFont)
        if subtitle and subtitle ~= "" then
            gfx.drawTextInRect(title, x + 70, y + 6, width - 75, 16, nil, "...", kTextAlignment.left)
            gfx.setFont(subfont)
            gfx.drawTextInRect(subtitle, x + 70, y + 23, width - 75, 20, nil, "...", kTextAlignment.left)
        else
            gfx.drawTextInRect(title, x + 70, y + 6, width - 75, 32, nil, "...", kTextAlignment.left)
        end
        local image = imagesInMemory[row]
        if image then
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            image:draw(x + 5, y + 5)
        elseif file.exists("cache/artwork/" .. strippedTitle .. ".pdi") then
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            local image = gfx.image.new("cache/artwork/" .. strippedTitle .. ".pdi")
            assert(image, "Failed to load image for " .. title)
            image:setMaskImage(maskImage)
            imagesInMemory[row] = image
            image:draw(x + 5, y + 5)
        else
            gfx.fillRoundRect(x + 5, y + 5, 60, 60, 3)
        end
    else
        gfx.drawRoundRect(x, y, width, height, 4)
    end
end

local function handleUp()
    if keyboard.isVisible() then
        return
    end
    if listview:getSelectedRow() == 0 then
        return
    elseif listview:getSelectedRow() == 1 then
        listview:setSelectedRow(0)
        return
    end
    listview:selectPreviousRow(false)
end

local function handleDown()
    if keyboard.isVisible() then
        return
    end
    listview:selectNextRow(false)
end

function Discover.upButtonUp()
    handleUp()
end

function Discover.downButtonUp()
    handleDown()
end

function Discover.AButtonUp()
    if keyboard.isVisible() then
        return
    end
    local selectedRow = listview:getSelectedRow()
    if titles[selectedRow] then
        Discover.switchScene("EPISODES",
            { title = titles[selectedRow], subtitle = subtitles[selectedRow], feedUrl = feedUrls[selectedRow] })
    elseif selectedRow == 0 then
        oldTerm = searchTerm
        searchTerm = ""
        playdate.display.setRefreshRate(30)
        keyboard.show()
        keyboard.text = ""
    end
end

local clickDegrees <const> = 360 / 15
local degreesSinceClick = 0

function Discover.cranked(change, acceleratedChange)
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

keyboard.textChangedCallback = function()
    searchTerm = keyboard.text
end

keyboard.keyboardWillHideCallback = function(ok)
    if not ok then
        searchTerm = oldTerm or searchTerm
    elseif searchTerm ~= "" then
        searchTerm:gsub('^%s*(.-)%s*$', '%1') -- trim whitespace
        oldTerm = nil
        listview:setSelectedRow(0)
        titles = {}
        subtitles = {}
        feedUrls = {}
        imagesInMemory = {}
        fetched = false
        queuedFetch = false
    end
    playdate.display.setRefreshRate(0)
end
local search = {
    search = gfx.imagetable.new("assets/images/search/search"),
    into_fetch = gfx.imagetable.new("assets/images/search/intoFetch"),
    fetch = gfx.imagetable.new("assets/images/search/fetch"),
    into_search = gfx.imagetable.new("assets/images/search/intoSearch")
}
local searchIndex = 1
local searchState = "search"

local targetFPS = 12

local function drawSearch()
    local framesToAdvance = targetFPS * DeltaTime
    if not fetched then
        if searchState == "search" then
            searchState = "into_fetch"
            searchIndex = 1
            listview.needsDisplay = true
        elseif searchState == "into_fetch" then
            if searchIndex + framesToAdvance < #search.into_fetch then
                searchIndex += framesToAdvance
                listview.needsDisplay = true
            else
                searchState = "fetch"
                searchIndex = 1
                listview.needsDisplay = true
            end
        elseif searchState == "fetch" then
            searchIndex = (searchIndex + framesToAdvance) % #search.fetch
            listview.needsDisplay = true
        end
    else
        if searchState == "fetch" then
            searchState = "into_search"
            searchIndex = 1
            listview.needsDisplay = true
        elseif searchState == "into_search" then
            if searchIndex + framesToAdvance < #search.into_search then
                searchIndex += framesToAdvance
                listview.needsDisplay = true
            else
                searchState = "search"
                searchIndex = 1
            end
        end
    end
end

local function renderData()
    drawSearch()
    if listview.needsDisplay or keyboard.isVisible() then
        playdate.graphics.clear()
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        if listview:getSelectedRow() == 0 then
            gfx.fillRoundRect(4, 4, 392, 25, 4)
            gfx.setImageDrawMode(gfx.kDrawModeInverted)
        else
            gfx.drawRoundRect(4, 4, 392, 25, 4)
        end
        local image = search[searchState][math.ceil(searchIndex)]
        assert(image, "No image for search animation" .. searchState .. " index " .. math.ceil(searchIndex))
        image:draw(8, 6)
        gfx.setFont(titleFont)
        local safeSearchTerm = searchTerm or ""
        gfx.drawTextInRect(safeSearchTerm, 30, 10, 380, 16, nil, "...", kTextAlignment.left)
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        listview:drawInRect(0, 32, 400, 208)
    end
end

function Discover.init(args)
    print("Discover scene initialized with args:", args)
end

function Discover.update()
    if not queuedFetch then
        fetchDiscoverData()
    end
    renderData()
end

function Discover.init(args)
    listview.needsDisplay = true
end
