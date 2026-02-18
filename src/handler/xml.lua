-- read xml data x bytes at a time until an item has been parsed.
-- then convert to table and call callback
local file <const> = playdate.file

local xml2lua = import "../libs/xml/xml2lua"
local xmlTree = import "../libs/xml/xmlTree"

Xml = {
    offset = 0,
    buffer = "",
    itemCount = 0,
}

local CHUNK_SIZE = 512

local parsing = false
local tree
local parser

local function parse(data)
    parsing = true
    tree = xmlTree:new()
    parser = xml2lua.parser(tree)
    parser:parse(data)
end

function Xml.new(filepath, tag, callback, max)
    local self = setmetatable({}, { __index = Xml })
    if file.exists(filepath) then
        self.filepath = filepath
        self.fileHandle = file.open(filepath, file.kFileRead)
        self.callback = callback
        self.maxItems = max or 1
        self.tag = tag or "item"
        self.tagPattern = "<" .. self.tag .. ">(.-)</" .. self.tag .. ">"
    else
        print("File does not exist: " .. filepath)
    end
    return self
end

function Xml:update()
    if parsing then
        local done = parser:update()
        if done then
            parsing = false
            self.callback(tree.root[self.tag])
            self.itemCount = self.itemCount + 1
        end
        return
    end
    if not self.fileHandle then
        return
    end
    if self.itemCount >= self.maxItems then
        self:close()
        return
    end
    self.fileHandle:seek(self.offset, file.kSeekSet)
    local chunk = self.fileHandle:read(CHUNK_SIZE)
    if chunk then
        self.buffer = self.buffer .. chunk
        self.offset = self.offset + CHUNK_SIZE
        local itemStart, itemEnd = string.find(self.buffer, self.tagPattern)
        if itemStart and itemEnd then
            local itemXml = string.sub(self.buffer, itemStart, itemEnd)
            self.buffer = string.sub(self.buffer, itemEnd + 1)
            local parsedItem = parse(itemXml)
        end
    end
end

function Xml:close()
    if self.fileHandle then
        self.fileHandle:close()
        self.fileHandle = nil
    end
end

function Xml:setMaxItems(max)
    if max > self.maxItems then
        self.maxItems = max
        if not self.fileHandle then
            self.fileHandle = file.open(self.filepath, file.kFileRead)
        end
    end
end
