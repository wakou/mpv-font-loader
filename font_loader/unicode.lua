local unicode = {}

local powOfTwo = { [0] = 1, [1] = 2, [2] = 4, [3] = 8, [4] = 16, [5] = 32, [6] = 64, [12] = 4096, [18] = 262144 }

local function bitRight(num, pos)
    if num > 0xFF then return nil end
    return math.floor(num / powOfTwo[pos])
end

local function bitSubFromEnd(num, start, len)
    local tmp1 = math.floor(num / powOfTwo[start - 1])
    return math.fmod(tmp1, powOfTwo[len])
end


function unicode.fromUTF16(buf, size)
    local codePointList = {}
    local highSurrogate = nil
    for i = 1, size do
        local codeUnit = buf[i]
        local low = codeUnit[1]
        local high = codeUnit[2]
        local byte4Check = bitRight(high, 3) == 0x1B
        if not byte4Check then
            local codePoint = math.floor(high * 256 + low)
            table.insert(codePointList, codePoint)
        else
            local highProxyCheck = bitRight(high, 2) == 0x36
            local lowProxyCheck = bitRight(high, 2) == 0x37
            if highProxyCheck and i == #buf then
                return codePointList, codeUnit
            end
            if highProxyCheck then highSurrogate = math.floor((high - 0xD8) * 256 + low) end
            if lowProxyCheck then
                if highSurrogate == nil then
                    goto continue
                end
                local lowSurrogate = math.floor((high - 0xDC) * 256 + low);
                local codePoint = math.floor((highSurrogate + 1) * 65536 + lowSurrogate)
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
        local first = math.floor(a / 1024)
        local second = math.fmod(a, 1024)
        local firstLow = math.fmod(first, 256)
        local firstHigh = math.floor(first / 256) + 0xDB
        local secondLow = math.fmod(second, 256)
        local secondHigh = math.floor(second / 256) + 0xDC
        return firstLow, firstHigh, secondLow, secondHigh
    else
        local high = math.floor(codePoint / 256)
        local low = math.fmod(codePoint,256)
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
                buf = buf * 64 + byte - 128
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
            local codeUnit = 128 + bitSubFromEnd(codePoint, (index - 1) * 6 + 1, 6)
            table.insert(byteU8, codeUnit);
        end
        local firstUnitNum = math.floor(codePoint / powOfTwo[(byteCount - 1) * 6])
        if not (firstUnitNum < powOfTwo[7 - byteCount]) then
            break
        end
        local firstUnitMask = (powOfTwo[byteCount + 1] - 2) * powOfTwo[7 - byteCount]
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
