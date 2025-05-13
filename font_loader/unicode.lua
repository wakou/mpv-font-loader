local bit = require "bit"

local unicode = {}
local powOfTwo = { [0] = 1, [1] = 2, [2] = 4, [3] = 8, [4] = 16, [5] = 32, [6] = 64, [12] = 4096, [18] = 262144 }

function unicode.fromUTF16(buf, size)
    local codePointList = {}
    local highSurrogate = nil
    for i = 1, size do
        local codeUnit = buf[i]
        local low = codeUnit[1]
        local high = codeUnit[2]
        local byte4Check = bit.rshift(high, 3) == 0x1B
        if not byte4Check then
            local codePoint = bit.lshift(high, 8) + low
            table.insert(codePointList, codePoint)
        else
            local highProxyCheck = bit.rshift(high, 2) == 0x36
            local lowProxyCheck = bit.rshift(high, 2) == 0x37
            if highProxyCheck and i == #buf then
                return codePointList, codeUnit
            end
            if highProxyCheck then
                highSurrogate = bit.lshift(high - 0xD8, 8) + low
            end
            if lowProxyCheck then
                if highSurrogate == nil then
                    goto continue
                end
                local lowSurrogate = bit.lshift(high - 0xDC, 8) + low
                local codePoint = bit.lshift(highSurrogate + 1, 16) + lowSurrogate
                highSurrogate = nil
                table.insert(codePointList, codePoint)
            end
        end
        ::continue::
    end

    return codePointList, nil
end

function unicode.toUTF16(codePoint)
    if codePoint > 65535 then
        local a = codePoint - 65536
        local first = bit.rshift(a, 10)
        local second = bit.band(a, 1024)
        local firstLow = bit.band(first, 256)
        local firstHigh = bit.rshift(first, 8) + 0xDB
        local secondLow = bit.band(second, 256)
        local secondHigh = bit.rshift(second, 8) + 0xDC
        return firstLow, firstHigh, secondLow, secondHigh
    else
        local high = bit.rshift(codePoint, 8)
        local low = bit.band(codePoint, 256)
        return low, high
    end
end

function unicode.fromUTF8(str)
    local codePointList = {}
    local codePointSize = 0
    local buf = nil
    local codeUnitShouldSize = 1
    local codeUnitSize = 1
    for i = 1, #str do
        local byte = str:byte(i);
        if byte < 128 then
            codePointSize = codePointSize + 1
            codePointList[codePointSize] = byte
        end
        if byte >= 128 and byte <= 191 then
            if buf ~= nil then
                buf = bit.lshift(buf, 6) + byte - 128
                codeUnitSize = codeUnitSize + 1
            end
        end
        if byte >= 192 and byte <= 223 then
            if buf ~= nil and codeUnitShouldSize == codeUnitSize then
                codePointSize = codePointSize + 1
                codePointList[codePointSize] = buf
            end
            buf = byte - 192
            codeUnitShouldSize = 2
            codeUnitSize = 1
        end
        if byte >= 224 and byte <= 239 then
            if buf ~= nil and codeUnitShouldSize == codeUnitSize then
                codePointSize = codePointSize + 1
                codePointList[codePointSize] = buf
            end
            buf = byte - 224
            codeUnitShouldSize = 3
            codeUnitSize = 1
        end
        if byte >= 240 and byte <= 247 then
            if buf ~= nil and codeUnitShouldSize == codeUnitSize then
                codePointSize = codePointSize + 1
                codePointList[codePointSize] = buf
            end
            buf = byte - 240
            codeUnitShouldSize = 4
            codeUnitSize = 1
        end
        if byte >= 248 and byte <= 251 then
            if buf ~= nil and codeUnitShouldSize == codeUnitSize then
                codePointSize = codePointSize + 1
                codePointList[codePointSize] = buf
            end
            buf = byte - 248
            codeUnitShouldSize = 5
            codeUnitSize = 1
        end
        if byte >= 252 and byte <= 253 then
            if buf ~= nil and codeUnitShouldSize == codeUnitSize then
                codePointSize = codePointSize + 1
                codePointList[codePointSize] = buf
            end
            buf = byte - 252
            codeUnitShouldSize = 6
            codeUnitSize = 1
        end
    end

    if buf ~= nil and codeUnitShouldSize == codeUnitSize then
        codePointSize = codePointSize + 1
        codePointList[codePointSize] = buf
    end

    return codePointList, codePointSize
end

function unicode.toUTF8(codePointList)
    local byteArray = {}

    while #codePointList ~= 0 do
        local codePoint = codePointList[1]
        table.remove(codePointList, 1)
        local byteCount = 0
        if codePoint < 128 then
            table.insert(byteArray, string.char(codePoint))
            goto continue
        end
        if codePoint >= 128 and codePoint < 2048 then
            byteCount = 2
        end
        if codePoint >= 2048 and codePoint < 65536 then
            byteCount = 3
        end
        if codePoint >= 65536 and codePoint < 1114112 then
            byteCount = 4
        end
        local byteU8 = {}
        for index = 1, byteCount - 1 do
            local codeUnit = 128 + bit.band(bit.rshift(codePoint, (index - 1) * 6), 63)
            table.insert(byteU8, codeUnit);
        end
        local firstUnitNum = bit.rshift(codePoint, (byteCount - 1) * 6)
        if not (firstUnitNum < powOfTwo[7 - byteCount]) then
            break
        end
        local firstUnitMask = bit.lshift(powOfTwo[byteCount + 1] - 2,7 - byteCount)
        local codeUnit = firstUnitMask + firstUnitNum
        table.insert(byteArray, string.char(codeUnit));
        while #byteU8 > 0 do
            table.insert(byteArray, string.char(byteU8[#byteU8]))
            table.remove(byteU8)
        end
        ::continue::
    end
    return byteArray
end

return unicode
