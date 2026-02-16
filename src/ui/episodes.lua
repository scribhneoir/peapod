Episodes = {}

local file <const> = playdate.file
local gfx <const> = playdate.graphics


local title
local subtitle
local feedUrl
local episodes
local xmlHandle

local function handleParsedItem(parsedItem)
    for key, value in pairs(parsedItem) do
        print(key, value)
    end
    if not episodes then
        episodes = {}
    end
    table.insert(episodes, parsedItem)
end

function Episodes.init(args)
    title, subtitle, feedUrl = args.title, args.subtitle, args.feedUrl
    if file.exists("cache/feeds/" .. StripString(title) .. ".xml") then --todo: check if cached file modtime is recent enough
        xmlHandle = Xml.new("cache/feeds/" .. StripString(title) .. ".xml", "item", handleParsedItem, 2)
    else
        Network.fetch(feedUrl, function()
                xmlHandle = Xml.new("cache/feeds/" .. StripString(title) .. ".xml", "item", handleParsedItem, 2)
            end,
            "cache/feeds/" .. StripString(title) .. ".xml")
    end
end

local titleFont = gfx.font.new('assets/fonts/Quickboot/Quickboot')
titleFont:setTracking(8)

local subfont = gfx.font.new('assets/fonts/Nontendo/Nontendo-Light')

function Episodes.update()
    gfx.setFont(titleFont)
    gfx.drawText(title, 10, 10, 380)
    if subtitle and subtitle ~= "" then
        gfx.setFont(subfont)
        gfx.drawText(subtitle, 10, 27, 380)
    end
    if xmlHandle then
        xmlHandle:update()
        -- if xmlHandle.itemCount >= xmlHandle.maxItems then
        --     xmlHandle:addItemCount(1)
        -- end
    end
    if episodes then
        for i, episode in ipairs(episodes) do
            gfx.setFont(titleFont)
            gfx.drawText(episode.title, 10, 50 + (i - 1) * 30, 380)
        end
    end
end
