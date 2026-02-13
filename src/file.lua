local file <const> = playdate.file
local json <const> = json

File = {}

function File.new(filepath)
    local self = setmetatable({}, { __index = File })
    self.filepath = filepath
    local dirpath = string.match(filepath, "(.*/)")
    if dirpath and not file.isdir(dirpath) then
        file.mkdir(dirpath)
    end
    if file.exists(filepath .. "_temp") then
        file.delete(filepath .. "_temp")
    end
    return self
end

function File:download(data)
    local fileHandle, err = file.open(self.filepath .. "_temp", file.kFileAppend)
    if err then
        print("Failed to open file for writing: " .. self.filepath .. "_temp", err)
        return
    end
    assert(fileHandle, "Failed to open file for writing: " .. self.filepath)
    fileHandle:write(data)
    fileHandle:close()
end

function File:finishDownload()
    file.delete(self.filepath)
    file.rename(self.filepath .. "_temp", self.filepath)
end

function File:read()
    if string.find(self.filepath, ".json") then
        return json.decodeFile(self.filepath)
    end

    local fileHandle = file.open(self.filepath, file.kFileRead)
    assert(fileHandle, "Failed to open file for reading: " .. self.filepath)
    local size = file.getSize(self.filepath)
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
