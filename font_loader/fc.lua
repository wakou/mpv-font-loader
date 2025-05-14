local log = require "mp.msg"
local unicode = require "unicode"
local cbor = require "cbor"

local function byte2uint32(num1, num2, num3, num4)
    return num1 + num2 * 2 ^ 8 + num3 * 2 ^ 16 + num4 * 2 ^ 24
end


local function buildIndex(cacheFile)
    log.info("open font cache db file: " .. cacheFile)
    local cache = assert(io.open(cacheFile, "rb"))

    local headSize = 16
    local b1 = cache:read(headSize)
    local head = { string.byte(b1, 1, 16) }
    local magicNumber = byte2uint32(head[1], head[2], head[3], head[4])
    local fileCount = byte2uint32(head[5], head[6], head[7], head[8])
    local faceCount = byte2uint32(head[9], head[10], head[11], head[12])
    local fileSize = byte2uint32(head[13], head[14], head[15], head[16])
    log.info("db info: [" .. fileCount .. "] font file, [" .. faceCount .. "] font face")
    local block = 3000

    local font = { filepath = nil, filename = nil, ver = nil, type = nil, faces = {} }
    local buf = {}
    local bufIndex = 1;
    local fontIndex = {}
    while true do
        local bytes = cache:read(block)
        if not bytes then break end
        for i = 1, #bytes do
            if i % 2 == 0 then goto continue end
            local low, high = string.byte(bytes, i, i + 1)
            if low == 10 and high == 0 then
                bufIndex = 1
                goto continue
            end
            if low == 0 and high == 0 then
                if bufIndex == 1 then
                    font = { filepath = nil, filename = nil, ver = nil, type = nil, faces = {} }
                    goto continue
                    -- break
                end

                local codePointList = unicode.fromUTF16(buf, bufIndex - 1)
                bufIndex = 1
                local utf8str = table.concat(unicode.toUTF8(codePointList))

                if font.filepath == nil then
                    local t1 = string.find(utf8str, "\\[^\\]*$") or 1
                    font.filename = utf8str:sub(t1 + 1, -1)
                    font.filepath = utf8str:gsub("\\", '/')
                    fontIndex[font.filename] = font
                else
                    -- \tt type
                    if utf8str:byte(1, 2) == 9 and utf8str:byte(2, 3) == 116 then
                        font.type = utf8str:sub(2)
                    else
                        -- \tv version
                        if utf8str:byte(1, 2) == 9 and utf8str:byte(2, 3) == 118 then
                            font.ver = utf8str:sub(2)
                        else
                            -- face
                            local face = utf8str
                            fontIndex[face] = font
                            table.insert(font.faces, face)
                        end
                    end
                end
                goto continue
            end
            buf[bufIndex] = { low, high }
            bufIndex = bufIndex + 1
            ::continue::
        end
    end
    cache:close()
    return fontIndex
end

local function saveIdxToFile(fontIndex, idxFile)
    local fontSet = {}
    local data = {}
    local size = 0
    for key, font in pairs(fontIndex) do
        if fontSet[key] ~= nil then
            goto continue
        end
        size = size + 1
        data[size] = font
        for _, face in pairs(font.faces) do
            fontSet[face] = true
        end
        ::continue::
    end
    assert(cbor)
    local cacheFile = assert(io.open(idxFile, "w"))
    cacheFile:write(cbor.encode(data))
    cacheFile:close()
end

local function loadIdx(idxFile)
    local fontIndex = {}
    local data = cbor.decode_file(io.open(idxFile, "r"))
    local size = 0
    for i = 1, #data do
        local font = data[i]
        local faces = font.faces
        for j = 1, #faces do
            fontIndex[faces[j]] = font
        end
    end
    return fontIndex
end

return {
    buildIndex = buildIndex,
    saveIdxToFile = saveIdxToFile,
    loadIdx = loadIdx
}
