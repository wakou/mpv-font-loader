local iconv = require "iconv"

local line_iter = {}

function line_iter:new(encoding, assFile)
    local iter = {
        cd = nil,
        encoding = 'UTF-8',
        lines = {},
        lines_size = 0,
        index = 0,
        assFile = nil,
        uncompleteLine = '',
        leftBytes = '',
        fileEnd = false,
        lineCount = 0
    }
    setmetatable(iter, { __index = line_iter })

    iter.encoding = encoding
    iter.assFile = assFile
    return iter
end

function line_iter:next()
    local BUFFER_SIZE = 65535
    if self.cd == nil then
        local cd = iconv:new(self.encoding, 'UTF-8', BUFFER_SIZE)
        assert(cd ~= nil)
        if cd == false then
            return
        end
        self.cd = cd
    end
    return function()
        if self.index == self.lines_size then
            if self.fileEnd then
                return nil
            end
            while true do
                local completeStr = self:readData()
                if completeStr then
                    break
                end
            end
        end
        self.index = self.index + 1
        self.lineCount = self.lineCount + 1
        return self.lines[self.index]
    end
end

local function magiclines(str)
    local pos = 1;
    return function()
        if pos == 0 then return nil end
        local p1, p2 = string.find(str, "\r?\n", pos)
        local line
        if p1 then
            line = str:sub(pos, p1 - 1)
            pos = p2 + 1
        else
            line = str:sub(pos)
            pos = 0
        end
        return line
    end
end

function line_iter:readData()
    local INPUT_SIZE = 55000
    local uncompleteLine = self.uncompleteLine
    local toUTF8 = self.cd
    local leftBytes = self.leftBytes
    local str = self.assFile:read(INPUT_SIZE)
    if str == nil then
        table.insert(self.lines, 1, self.uncompleteLine)
        self.lines_size = 1
        self.index = 0
        self.fileEnd = true
        return true
    end
    if leftBytes ~= '' then
        str = leftBytes .. str
    end
    local ret, retStr, leftBytesSize = toUTF8:iconv(str)
    if not ret then
        return
    end
    leftBytes = leftBytesSize == 0 and '' or str:sub(-leftBytesSize, -1)
    local index = retStr:match '^.*()\n'
    local isUncompleteLine = index == nil and true or false
    if isUncompleteLine then
        uncompleteLine = uncompleteLine .. retStr
        return false
    end
    local tmp1 = uncompleteLine
    uncompleteLine = index == #retStr and '' or retStr:sub(index + 1, -1)

    if tmp1 ~= nil then
        retStr = tmp1 .. retStr:sub(1, index)
    end
    local i = 1
    for line in magiclines(retStr) do
        table.insert(self.lines, i, line)
        i = i + 1
    end
    self.index = 0
    self.lines_size = i - 1
    return true
end

function line_iter:close()
    self.assFile:close()
    self.cd:close()
end

return line_iter
