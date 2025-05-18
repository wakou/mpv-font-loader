local log = require "mp.msg"
local uchardet = require "uchardet"
local line_iter = require "line_iter"

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

local function trim(s)
    return s:match '^%s*(.*%S)' or ''
end

local function indexOf(array, value, func)
    local fFunc = func or function(t)
        return t
    end
    for i, v in ipairs(array) do
        if fFunc(v) == value then
            return i
        end
    end
    return nil
end

local function split(str, pat)
    local t = {} -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t, cap)
        end
        last_end = e + 1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end

local function getFontListFromAss(filePath)
    log.info("parse sub file: ", filePath)
    local fontList = {}

    local assFile = assert(io.open(filePath, 'rb'))
    local iter = assFile.lines
    local iterParam = assFile

    if uchardet.status then
        local encoding = uchardet.checkEncoding(filePath)
        log.info("check sub file [" .. filePath .. "] encoding: " .. encoding)
        local des = nil
        if encoding ~= 'UTF-8' then
            des = line_iter:new(encoding, assFile)
            iter = des.next
            iterParam = des
        end
    end

    local section = nil
    local styleFontnameIndex = -1
    local eventTextCommaIndex = -1

    for line in iter(iterParam) do
        if string.lower(string.sub(line, 1, 11)) == "[v4 styles]"
            or string.lower(string.sub(line, 1, 12)) == "[v4+ styles]" then
            section = "Styles"
            goto continue
        end

        if string.lower(string.sub(line, 1, 8)) == "[events]" then
            section = "Events"
            goto continue
        end

        if section == "Styles" and starts_with(line, "Format") then
            local lineSplitArr = split(line, "[,:]")
            styleFontnameIndex = indexOf(lineSplitArr, "Fontname", trim) or -1
            if styleFontnameIndex == -1 then
                break;
            end
            goto continue
        end

        if section == "Styles" and starts_with(line, "Style") then
            local fontname = trim(split(line, "[,:]")[styleFontnameIndex])
            if starts_with(fontname, '@') then
                fontname = string.sub(fontname, 2)
            end
            log.debug("found font: " .. fontname)
            table.insert(fontList, fontname)
            goto continue
        end

        if section == "Events" then
            if starts_with(line, "Format") then
                local textFormatIndex = string.find(line, 'Text', 8, true);
                local _, count = string.gsub(string.sub(line, 1, textFormatIndex), ',', "")
                eventTextCommaIndex = count
                -- local fontname=trim(split(line,"[,:]")[styleFontnameIndex])
                -- if starts_with(fontname,'@') then
                --     fontname=string.sub(fontname,2)
                -- end
                -- table.insert(fontList,fontname)
                goto continue
            end

            if starts_with(line, "Dialogue") then
                local index, commaCount = 0, 0
                for c in line:gmatch "." do
                    index = index + 1;
                    if c == "," then
                        commaCount = commaCount + 1
                    end
                    if commaCount == eventTextCommaIndex then break end
                    -- do something with c
                end

                local textStart = index + 1
                local text = string.sub(line, textStart)
                local styleOverride = false
                local prev, prev2char = nil, nil
                local findFont = false
                local fontnameCharArr = {}
                for c in text:gmatch "." do
                    if styleOverride then
                        if findFont and (c == "\\" or c == "}") then
                            findFont = false
                            local fontname = table.concat(fontnameCharArr)
                            fontnameCharArr = {}
                            if starts_with(fontname, '@') then
                                fontname = string.sub(fontname, 2)
                            end
                            table.insert(fontList, fontname)
                            log.debug("found font: " .. fontname)
                        end
                        if findFont and c ~= "\\" then
                            table.insert(fontnameCharArr, c)
                        end
                        if prev2char == "\\" and prev == "f" and c == "n" then
                            findFont = true
                        end
                    end
                    if c == "{" then
                        styleOverride = true
                    end
                    if c == "}" then
                        styleOverride = false
                    end
                    prev, prev2char = c, prev
                end
            end
        end

        ::continue::
    end

    if des ~= nil then
        des:close()
    end
    return fontList
end



return {
    getFontListFromAss = getFontListFromAss
}
