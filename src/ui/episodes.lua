Episodes = {}

local file <const> = playdate.file
local gfx <const> = playdate.graphics


local title
local subtitle
local feedUrl
local episodes = {}
local description

local function onFeedDataFetched(fileHandle)
    local xml = fileHandle:read():gsub("<br>", "")
    local parsedData = ParseXML(xml)
    xml = nil
    local channel = parsedData.channel
    description = channel.description
    episodes = channel.item
end

function Episodes.init(args)
    title, subtitle, feedUrl = args.title, args.subtitle, args.feedUrl
    if file.exists("cache/feeds/" .. StripString(title) .. ".xml") then --todo: check if cached file modtime is recent enough
        onFeedDataFetched(File.new("cache/feeds/" .. StripString(title) .. ".xml"))
    else
        Network.fetch(feedUrl, function(fileHandle) onFeedDataFetched(fileHandle) end,
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
        gfx.drawText(subtitle, 10, 40, 380)
    end
end
