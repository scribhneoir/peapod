function StripString(str)
    local stripped = str:gsub("%s+", "_")
    stripped = stripped:gsub("[^%w_]", "")
    stripped = stripped:gsub("æ", "ae")
    stripped = stripped:gsub("ø", "o")
    stripped = stripped:gsub("å", "a")
    return string.lower(stripped)
end
