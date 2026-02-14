local file <const> = playdate.file
local gfx <const> = playdate.graphics
local keyboard <const> = playdate.keyboard
Discover = {}

local function stripString(str)
    local stripped = str:gsub("%s+", "_")
    stripped:gsub("[^%w_]", "")
    stripped:gsub("æ", "ae")
    stripped:gsub("ø", "o")
    stripped:gsub("å", "a")
    stripped:gsub(":", "")
    stripped:lower()
    return stripped
end


local maskImage <const> = gfx.image.new(60, 60, gfx.kColorBlack)
gfx.lockFocus(maskImage)
gfx.setColor(gfx.kColorWhite)
gfx.fillRoundRect(0, 0, 60, 60, 3)
gfx.unlockFocus()


local imagesInMemory = {}
local titles = {}
local searchTerm = "into the aether";
local oldTerm = nil
local fetched = false
local queuedFetch = false

local NUMBER_OF_RESULTS = 10

local function parseDiscoverData(fileHandle)
    -- print("Fetched discover data:")
    local data = fileHandle:read()
    if (not data) then
        print("Failed to read discover data")
        fileHandle:delete()
        queuedFetch = false
        return
    end
    for key, value in pairs(data.results) do
        local title = value.trackName
        local artworkUrl = value.artworkUrl60
        local strippedTitle = stripString(title)
        if not file.exists("cache/artwork/" .. strippedTitle .. ".pdi") then
            print("Fetching artwork for:", strippedTitle)
            Network.fetch("https://pdi-image-converter.scribhneoir.workers.dev/?url=" .. artworkUrl, function(file)
            end, "cache/artwork/" .. strippedTitle .. ".pdi")
        end
        titles[#titles + 1] = title
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

local titleFont = gfx.font.new('assets/fonts/Quickboot/Quickboot')
titleFont:setTracking(8)

local listview = playdate.ui.gridview.new(0, 70)
listview:setNumberOfRows(NUMBER_OF_RESULTS)
listview:setCellPadding(5, 5, 2, 2)

function listview:drawCell(_, row, _, selected, x, y, width, height)
    if titles[row] then
        local title = titles[row]
        local strippedTitle = stripString(title)
        if selected then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(x, y, width, height, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
            gfx.drawRoundRect(x, y, width, height, 4)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
        gfx.setFont(titleFont)
        gfx.drawTextInRect(title, x + 70, y + 6, width - 75, 32, nil, "...", kTextAlignment.left)
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
    gfx.setDrawOffset(0, 0)
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

function playdate.upButtonUp()
    handleUp()
end

function playdate.downButtonUp()
    handleDown()
end

function playdate.AButtonUp()
    if keyboard.isVisible() then
        return
    end
    local selectedRow = listview:getSelectedRow()
    if titles[selectedRow] then
        print("Selected:", titles[selectedRow])
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

function playdate.cranked(change, acceleratedChange)
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
        elseif searchState == "into_fetch" then
            if searchIndex + framesToAdvance < #search.into_fetch then
                searchIndex += framesToAdvance
            else
                searchState = "fetch"
                searchIndex = 1
            end
        elseif searchState == "fetch" then
            searchIndex = (searchIndex + framesToAdvance) % #search.fetch
        end
    else
        if searchState == "fetch" then
            searchState = "into_search"
            searchIndex = 1
        elseif searchState == "into_search" then
            if searchIndex + framesToAdvance < #search.into_search then
                searchIndex += framesToAdvance
            else
                searchState = "search"
                searchIndex = 1
            end
        end
    end
    local image = search[searchState][math.ceil(searchIndex)]
    assert(image, "No image for search animation" .. searchState .. " index " .. math.ceil(searchIndex))
    image:draw(8, 6)
end

local function renderData()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    if listview:getSelectedRow() == 0 then
        gfx.fillRoundRect(4, 4, 392, 25, 4)
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
    else
        gfx.drawRoundRect(4, 4, 392, 25, 4)
    end
    drawSearch()
    gfx.setFont(titleFont)
    local safeSearchTerm = searchTerm or ""
    gfx.drawTextInRect(safeSearchTerm, 30, 10, 380, 16, nil, "...", kTextAlignment.left)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    listview:drawInRect(0, 32, 400, 208)
end

function Discover.update()
    if not queuedFetch then
        fetchDiscoverData()
    end
    renderData()
end
