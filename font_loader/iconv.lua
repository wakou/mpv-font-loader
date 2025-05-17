local ffi = require "ffi"
local common = require "common"
local utils = require "mp.utils"

local LIB_ICONV_PATH = common.LIB_ICONV_PATH

if utils.file_info(LIB_ICONV_PATH) == nil then
    return { status = false }
end

ffi.cdef [[
    typedef void* iconv_t;
    iconv_t libiconv_open(const char* tocode, const char* fromcode);
    iconv_t libiconv(iconv_t cd,  char** inbuf, size_t *inbytesleft, char** outbuf, size_t *outbytesleft);
    iconv_t libiconv_close(iconv_t cd);
]];

LIB_ICONV = ffi.load(LIB_ICONV_PATH)
local iconv_open = LIB_ICONV.libiconv_open
local iconv_close = LIB_ICONV.libiconv_close
local convert = LIB_ICONV.libiconv

local iconv = { status = true }

function iconv:iconv(str)
    local inLen = string.len(str);
    local insize = ffi.new("size_t[1]", inLen);
    local instr = ffi.new("char[?]", inLen + 1, str);
    local inptr = ffi.new("char*[1]", instr);
    local outstr = ffi.new("char[?]", self.bufferSize);
    local outptr = ffi.new("char*[1]", outstr);
    local outsize = ffi.new("size_t[1]", self.bufferSize);
    local err = convert(self.cd, inptr, insize, outptr, outsize);
    if err == -1 and (not insize[0] > 0) then
        return false, nil, nil
    end
    local out = ffi.string(outstr, self.bufferSize - outsize[0]);
    return true, out, tonumber(insize[0])
end

function iconv:new(from, to, bufferSize)
    bufferSize = bufferSize == nil and 4096 or bufferSize
    local self = { cd = -1, bufferSize = bufferSize }
    setmetatable(self, { __index = iconv })
    self.cd = iconv_open(to, from);
    -- ffi.gc(self._cd, self.close);
    if self.cd == -1 then
        return false;
    end
    return self
end

function iconv:close()
    iconv_close(self.cd);
end

return iconv
