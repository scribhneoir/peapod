local sound <const> = playdate.sound
local timer <const> = playdate.timer

Mp3Handle = {}

local BUFFER_SIZE <const> = 1024 * 1000 * 3 -- 3MB buffer size before starting playback

function Mp3Handle:onPlaybackEnd()
    if self.player:didUnderrun() then
        print("Playback ended due to underrun for file:", self.filePath)
    end
    self.player:load(self.filePath)
    if self.player:getLength() > self.offset then
        self.player:setOffset(self.offset)
        self.player:play()
        print("Resuming playback for file:", self.filePath, "from offset:", self.offset)
    else
        print("Playback finished for file:", self.filePath)
        self.updateTimer:remove()
    end
end

function Mp3Handle:update()
    if self.player:isPlaying() then
        self.offset = self.player:getOffset()
    end
end

function Mp3Handle.new(path)
    local self = setmetatable({}, { __index = Mp3Handle })
    self.filePath = path
    self.player = sound.fileplayer.new()
    self.offset = 0
    self.player:setFinishCallback(function() self:onPlaybackEnd() end)
    self.fileHandle = FileHandle.new(path, false)
    self.updateTimer = timer.keyRepeatTimer(function() self:update() end, 1000)
    return self
end

function Mp3Handle:onData(data)
    self.fileHandle:onData(data)
    if not self.player:isPlaying() and self.fileHandle:getSize() >= BUFFER_SIZE then
        self.player:load(self.filePath)
        local suc, err = self.player:play()
        if not suc then
            print("Error playing MP3:", err)
        end
    end
end

function Mp3Handle:onFinish()
    self.fileHandle:onFinish()
    if not self.player:isPlaying() then
        self.player:load(self.filePath)
        local suc, err = self.player:play()
        if not suc then
            print("Error playing MP3:", err)
        end
    end
end

function Mp3Handle:getDataProgress()
    return self.fileHandle:getDataProgress()
end

function Mp3Handle:setContentLength(length)
    self.fileHandle:setContentLength(length)
end

function Mp3Handle:getSize()
    return self.fileHandle:getSize()
end
