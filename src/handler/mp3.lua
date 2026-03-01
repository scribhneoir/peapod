--- @class Mp3Handle
--- @field filePath string
--- @field player playdate.sound.fileplayer
--- @field offset number
--- @field paused boolean
--- @field fileHandle FileHandle
--- @field updateTimer playdate.timer
--- @field onData fun(self: Mp3Handle, data: string)
--- @field onFinish fun(self: Mp3Handle)
--- @field getDataProgress fun(self: Mp3Handle): number
--- @field setContentLength fun(self: Mp3Handle, length: number)
--- @field getSize fun(self: Mp3Handle): number
--- @field pause fun(self: Mp3Handle)
--- @field resume fun(self: Mp3Handle)

Mp3Handle = {}

local sound <const> = playdate.sound
local timer <const> = playdate.timer
local BUFFER_SIZE <const> = 1024 * 1000 * 3 -- 3MB buffer size before starting playback

function Mp3Handle:onPlaybackEnd()
    if self.paused then return end
    if self.player:didUnderrun() then
        print("Playback ended due to underrun for file:", self.filePath)
    end
    self.player:stop()
    self.player:load(self.filePath)
    if self.player:getLength() > self.offset then
        self.player:setOffset(self.offset)
        local suc, err = self.player:play()
        if err then
            print("Error playing MP3:", err)
        end
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
    print("Creating Mp3Handle for file:", path)
    local self = setmetatable({}, { __index = Mp3Handle })
    self.filePath = path
    self.player = sound.fileplayer.new()
    self.offset = 0
    self.paused = false
    self.finished = false
    self.player:setFinishCallback(function() self:onPlaybackEnd() end)
    self.player:setStopOnUnderrun(true)
    self.fileHandle = FileHandle.new(path, false)
    self.updateTimer = timer.keyRepeatTimer(function() self:update() end, 1000)
    return self
end

function Mp3Handle:onData(data)
    self.fileHandle:onData(data)
    if not self.paused and not self.player:isPlaying() and self.fileHandle:getSize() >= BUFFER_SIZE then
        print("Buffer threshold reached, starting playback for file:", self.filePath)
        self.player:load(self.filePath)
        local suc, err = self.player:play()
        if not suc then
            print("Error playing MP3:", err)
        end
    end
end

function Mp3Handle:onFinish()
    self.finished = true
    self.fileHandle:onFinish()
    if not self.paused and not self.player:isPlaying() then
        self.player:load(self.filePath)
        self.player:setOffset(self.offset)
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

function Mp3Handle:pause()
    if self.player:isPlaying() then
        self.offset = self.player:getOffset()
        self.player:stop()
        self.paused = true
    end
end

function Mp3Handle:resume()
    if self.paused and self.finished then
        self.player:setOffset(self.offset)
        local _, err = self.player:play()
        if err then
            print("Error playing MP3:", err)
        end
        if (_) then
            print("Resuming playback for file:", self.filePath, "from offset:", self.offset)
        end
        self.paused = false
    end
end
