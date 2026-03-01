function StripString(str)
    local stripped = str:gsub("%s+", "_")
    stripped = stripped:gsub("[^%w_]", "")
    stripped = stripped:gsub("æ", "ae")
    stripped = stripped:gsub("ø", "o")
    stripped = stripped:gsub("å", "a")
    return string.lower(stripped)
end

function GetNested(tbl, path)
    local current = tbl
    for key in string.gmatch(path, "[^%.]+") do
        current = current[key]
        if current == nil then
            return nil
        end
    end
    return current
end
