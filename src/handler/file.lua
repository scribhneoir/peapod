local file <const> = playdate.file
local json <const> = json

FileHandle = {}

local function getExtensionIndex(filename)
    return filename:find(".([^%.]+)$")
end

function FileHandle.new(filepath, temp)
    local self = setmetatable({}, { __index = FileHandle })
    self.filepath = filepath
    local dirpath = string.match(filepath, "(.*/)")
    if dirpath and not file.isdir(dirpath) then
        file.mkdir(dirpath)
    end

    if temp ~= false then
        local extIndex = getExtensionIndex(filepath)
        local ext = extIndex and string.sub(filepath, extIndex) or ""
        local name = string.sub(filepath, 1, extIndex and extIndex - 1 or #filepath)
        self.tempPath = name .. "_temp" .. ext
        if file.exists(self.tempPath) then
            file.delete(self.tempPath)
        end
    else
        self.tempPath = nil
    end

    return self
end

function FileHandle:onData(data)
    local fileHandle, err
    if self.tempPath then
        fileHandle, err = file.open(self.tempPath, file.kFileAppend)
        if err then
            print("Failed to open temp file for writing: " .. self.tempPath, err)
            return
        end
        assert(fileHandle, "Failed to open temp file for writing: " .. self.tempPath)
    else
        fileHandle, err = file.open(self.filepath, file.kFileAppend)
        if err then
            print("Failed to open file for writing: " .. self.filepath, err)
            return
        end
    end
    assert(fileHandle, "Failed to open file for writing: " .. self.filepath)
    fileHandle:write(data)
    fileHandle:close()
end

function FileHandle:onFinish()
    if self.tempPath then
        file.delete(self.filepath)
        file.rename(self.tempPath, self.filepath)
    end
end

function FileHandle:getDataProgress()
    return self:getSize() / self.contentLength
end

function FileHandle:setContentLength(length)
    self.contentLength = length
end

function FileHandle:getSize()
    if self.tempPath and file.exists(self.tempPath) then
        return file.getSize(self.tempPath)
    elseif file.exists(self.filepath) then
        return file.getSize(self.filepath)
    else
        return 0
    end
end

function FileHandle:read(size, offset)
    if string.find(self.filepath, ".json") then
        return json.decodeFile(self.filepath)
    end

    local fileHandle = file.open(self.filepath, file.kFileRead)
    assert(fileHandle, "Failed to open file for reading: " .. self.filepath)
    local size = size or file.getSize(self.filepath)
    if offset then
        fileHandle:seek(offset, playdate.file.kSeekSet)
    end
    local data = fileHandle:read(size)
    fileHandle:close()
    return data
end

function FileHandle:exists()
    return file.exists(self.filepath)
end

function FileHandle:delete()
    if self:exists() then
        file.delete(self.filepath)
    end
end
