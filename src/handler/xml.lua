local store <const> = playdate.datastore
local file <const> = playdate.file

local xml2lua = import "../libs/xml/xml2lua"
local xmlTree = import "../libs/xml/xmlTree"

-- we can keep track of latest pubdate in data
-- store episode order table in episode index file
-- use uuid for episode files
local function parseRFC822(date)
    local pattern = "(%a+), (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) ([+-]%d%d%d%d)"
    local dayOfWeek, day, month, year, hour, min, sec, tz = date:match(pattern)
    if not dayOfWeek then
        print("Failed to parse date:", date)
        return nil
    end

    local monthMap = {
        Jan = 1,
        Feb = 2,
        Mar = 3,
        Apr = 4,
        May = 5,
        Jun = 6,
        Jul = 7,
        Aug = 8,
        Sep = 9,
        Oct = 10,
        Nov = 11,
        Dec = 12
    }
    local monthNum = monthMap[month]
    return year .. "_" .. monthNum .. "_" .. day .. "_" .. hour .. "_" .. min .. "_" .. sec
end


XmlHandle = {}

function XmlHandle:parse(data)
    if self.parsing then return end
    self.parsing = true
    self.tree = xmlTree:new()
    self.parser = xml2lua.parser(self.tree)
    self.parser:parse(data)
end

local function parseNow(data, tag)
    local tree = xmlTree:new()
    local parser = xml2lua.parser(tree)
    parser:parse(data)
    return tree.root[tag]
end

function XmlHandle.new(headerTagMap, itemTag, itemSubTagMap, path, itemPath)
    local self = setmetatable({}, { __index = XmlHandle })
    self.itemData = {}
    self.headerData = {}
    self.headerTagMap = headerTagMap
    self.itemTag = itemTag or "item"
    self.itemSubTagMap = itemSubTagMap
    self.path = path
    self.itemPath = itemPath or "items"
    self.buffer = ""
    self.index = 1
    self.oldData = false
    if not file.isdir(self.path .. "/" .. self.itemPath .. "/xml") then
        file.mkdir(self.path .. "/" .. self.itemPath .. "/xml")
    end
    if file.exists(self.path .. "data.json") then
        self.headerData = store.read(self.path .. "data") or {}
        for assignment, _ in ipairs(self.headerData) do
            if not self.headerTagMap[assignment] then
                self.headerTagMap[assignment] = assignment
                break
            end
        end
    end
    return self
end

function XmlHandle:onData(data)
    if self.oldData then return end
    self.buffer = self.buffer .. data

    if not self.foundAllHeaderTags then
        local allFound = true
        for assignment, tag in pairs(self.headerTagMap) do
            if not self.headerData[assignment] then
                local index = self.buffer:find("<" .. tag .. ">(.-)</" .. tag .. ">")
                if not index then
                    allFound = false
                    break
                else
                    self.headerData[assignment] = parseNow(self.buffer:match("<" .. tag .. ">(.-)</" .. tag .. ">"), tag)
                end
            end
        end
        if allFound then
            store.write(self.headerData, self.path .. "data")
            self.foundAllHeaderTags = true
        end
    end
    local itemStart, itemEnd = string.find(self.buffer, "<" .. self.itemTag .. ">(.-)</" .. self.itemTag .. ">")
    while itemStart do
        local itemXml = string.sub(self.buffer, itemStart, itemEnd)
        print("Parsed XML:", itemXml:len())
        self.buffer = string.sub(self.buffer, itemEnd + 1)
        print("Remaining buffer:", self.buffer:len())

        local handle = file.open(self.path .. "/" .. self.itemPath .. "/xml/" .. self.index .. ".xml", file.kFileWrite)
        assert(handle,
            "Failed to open file for writing: " .. self.path .. "/" .. self.itemPath .. "/xml/" .. self.index .. ".xml")
        handle:write(itemXml)
        handle:close()
        self.index = self.index + 1
        itemStart, itemEnd = string.find(self.buffer, "<" .. self.itemTag .. ">(.-)</" .. self.itemTag .. ">")
    end
end

function XmlHandle:onFinish()
    if self.buffer:len() > 0 then
        print("Warning: Unprocessed XML data remaining after parsing.")
    end
    print("Finished parsing XML. Total items parsed: " .. (self.index - 1))
end

function XmlHandle:getDataProgress()
    return 0
end

function XmlHandle:setContentLength()
end

function XmlHandle:getSize()
    return 0
end

function XmlHandle:update()
    if self.parsing then
        local done = self.parser:update()
        if done then
            self.parsing = false
            local data = {}
            for assignment, tag in pairs(self.itemSubTagMap) do
                data[assignment] = GetNested(self.tree.root[self.itemTag], tag)
            end
            local pubDate = parseRFC822(data.pubDate)
            local path = self.path .. "/" .. self.itemPath .. "/" .. pubDate
            if file.exists(path .. ".json") then
                print("Episode already exists, skipping:", path)
                self.oldData = true
                return
            end
            store.write(data, self.path .. "/" .. self.itemPath .. "/" .. pubDate)
        end
        return
    end

    local files = file.listFiles(self.path .. "/" .. self.itemPath .. "/xml")
    if files and #files > 0 then
        local fileName = files[1]
        local path = self.path .. "/" .. self.itemPath .. "/xml/" .. fileName
        local handle = file.open(path, file.kFileRead)
        assert(handle, "Failed to open file for reading: " .. path)
        local xmlData = handle:read(file.getSize(path))
        handle:close()
        self:parse(xmlData)
        file.delete(path)
    end
end
