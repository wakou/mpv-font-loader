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

local function getFontListFromAss(filePath, context)
    log.info("parse sub file: ", filePath)
    local fontList = {}

    local assFile = assert(io.open(filePath, 'rb'))
    local iter = assFile.lines
    local iterParam = assFile
    local des = nil

    if uchardet.status then
        local encoding = uchardet.checkEncoding(filePath)
        log.info("check sub file [" .. filePath .. "] encoding: " .. encoding)
        if encoding ~= 'UTF-8' then
            des = line_iter:new(encoding, assFile)
            iter = des.next
            iterParam = des
        end
    end

    local section = nil
    local styleFontnameIndex = -1
    local styleNameIndex = -1
    local styleFontMap = {}
    local fontSet = {}
    local eventTextCommaIndex = -1
    local eventStyleCommaIndex = -1

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
            styleNameIndex = indexOf(lineSplitArr, "Name", trim) or -1
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
            if styleNameIndex ~= -1 then
                local styleName = trim(split(line, "[,:]")[styleNameIndex])
                if starts_with(styleName, "*") then
                    styleName = string.sub(styleName, 2)
                end
                styleFontMap[styleName] = fontname
            end
            log.debug("style font: " .. fontname)
            goto continue
        end

        if section == "Events" then
            if starts_with(line, "Format") then
                local textFormatIndex = string.find(line, 'Text', 8, true);
                local _, textCount = string.gsub(string.sub(line, 1, textFormatIndex), ',', "")
                eventTextCommaIndex = textCount
                local styleFormatIndex = string.find(line, 'Style', 8, true);
                if styleFormatIndex then
                    local _, styleCount = string.gsub(string.sub(line, 1, styleFormatIndex), ',', "")
                    eventStyleCommaIndex = styleCount
                end
                goto continue
            end

            if starts_with(line, "Dialogue") then
                -- extract Style name and add its font
                if eventStyleCommaIndex >= 0 then
                    local styleStart, commaCount = nil, 0
                    for i = 1, #line do
                        local c = line:sub(i, i)
                        if c == "," then
                            commaCount = commaCount + 1
                            if commaCount == eventStyleCommaIndex then
                                styleStart = i + 1
                            elseif commaCount == eventStyleCommaIndex + 1 then
                                local styleName = trim(line:sub(styleStart, i - 1))
                                if starts_with(styleName, '*') then
                                    styleName = styleName:sub(2)
                                end
                                local fn = styleFontMap[styleName]
                                if fn and not fontSet[fn] then
                                    fontSet[fn] = true
                                    fn = starts_with(fn, '@') and string.sub(fn, 2) or fn
                                    log.debug("found font: " .. fn)
                                    table.insert(fontList, fn)
                                end
                                break
                            end
                        end
                    end
                end

                -- find Text field start
                local index, commaCount2 = 0, 0
                for c in line:gmatch "." do
                    index = index + 1;
                    if c == "," then
                        commaCount2 = commaCount2 + 1
                    end
                    if commaCount2 == eventTextCommaIndex then break end
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
                            if not fontSet[fontname] then
                                fontSet[fontname] = true
                                log.debug("found font: " .. fontname)
                                table.insert(fontList, fontname)
                            end
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

    if context ~= nil then
        context.subFiles[filePath] = { styleFontMap = styleFontMap, usedSet = fontSet }
    end

    return fontList
end



return {
    getFontListFromAss = getFontListFromAss
}
