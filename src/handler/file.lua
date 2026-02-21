local file <const> = playdate.file
local json <const> = json

File = {}

local function getExtensionIndex(filename)
    return filename:find(".([^%.]+)$")
end

function File.new(filepath, temp)
    local self = setmetatable({}, { __index = File })
    self.filepath = filepath
    self.temp = temp or true
    local dirpath = string.match(filepath, "(.*/)")
    if dirpath and not file.isdir(dirpath) then
        file.mkdir(dirpath)
    end

    local extIndex = getExtensionIndex(filepath)
    local ext = extIndex and string.sub(filepath, extIndex) or ""
    local name = string.sub(filepath, 1, extIndex and extIndex - 1 or #filepath)
    self.tempPath = name .. "_temp" .. ext
    if file.exists(self.tempPath) then
        file.delete(self.tempPath)
    end
    return self
end

function File:download(data)
    local fileHandle, err = file.open(self.tempPath, file.kFileAppend)
    if err then
        print("Failed to open file for writing: " .. self.tempPath, err)
        return
    end
    assert(fileHandle, "Failed to open file for writing: " .. self.filepath)
    fileHandle:write(data)
    fileHandle:close()
end

function File:finishDownload()
    file.delete(self.filepath)
    file.rename(self.tempPath, self.filepath)
end

function File:read(size, offset)
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

function File:exists()
    return file.exists(self.filepath)
end

function File:delete()
    if self:exists() then
        file.delete(self.filepath)
    end
end
