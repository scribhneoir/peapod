local sound <const> = playdate.sound
local file <const> = playdate.file

Sound = {}
local function getExtensionIndex(filename)
    return filename:find(".([^%.]+)$")
end

local BUFFER_SIZE = 1024 * 500 -- 100KB buffer before starting playback

local bufferPlayer = sound.fileplayer.new()
local downloadPlayer = sound.fileplayer.new()
local filePath
local cachePath

local function reset()
    bufferPlayer:stop()
    downloadPlayer:stop()
    bufferPlayer:setVolume(1)
    downloadPlayer:setVolume(0)
    filePath = nil
    cachePath = nil
end

local function crossfadeToDownload()
    print("Crossfading to download player for file:", filePath)
    downloadPlayer:load(filePath)
    local bufferPlayerOffset = bufferPlayer:getOffset()
    downloadPlayer:setOffset(bufferPlayerOffset)
    downloadPlayer:setVolume(1, 1, 0.5) -- Crossfade over 0.5 seconds
    bufferPlayer:setVolume(0, 0, 0.5, function(self, arg)
        self:stop()
    end)
end

function Sound.stream(url, path)
    reset()
    filePath = path

    local extIndex = getExtensionIndex(path)
    local ext = extIndex and string.sub(path, extIndex) or ""
    local name = string.sub(path, 1, extIndex and extIndex - 1 or #path)
    cachePath = name .. "_temp" .. ext


    Network.fetch(url, function(_)
            crossfadeToDownload()
        end,
        filePath,
        10, true
    )
end

function Sound.update()
    if not filePath then
        return
    end

    if downloadPlayer:isPlaying() then
        return
    end

    if not bufferPlayer:isPlaying() and file.exists(cachePath) and (file.getSize(cachePath) or 0) > BUFFER_SIZE then
        print("Buffer player starting for file:", filePath)
        print(file.exists(cachePath))
        bufferPlayer:load(cachePath)
        local suc, err = bufferPlayer:play()
        if not suc then
            print("Error playing buffer player:", err)
        end
        return
    end
end
