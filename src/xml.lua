local xml2lua = import "libs/xml/xml2lua"
local xmlTree = import "libs/xml/xmlTree"

function ParseXML(data)
    local tree = xmlTree:new()
    local parser = xml2lua.parser(tree)
    parser:parse(data)
    return tree.root.rss.channel.item
end
