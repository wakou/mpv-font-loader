local ffi = require "ffi"
local common = require "common"
local LIB_UCHARDET_PATH = common.LIB_UCHARDET_PATH

ffi.cdef [[
    typedef void* uchardet_t;
    uchardet_t uchardet_new(void);
    void uchardet_delete(uchardet_t ud);
    int uchardet_handle_data(uchardet_t ud, const char * data, size_t len);
    void uchardet_data_end(uchardet_t ud);
    void uchardet_reset(uchardet_t ud);
    const char * uchardet_get_charset(uchardet_t ud);
]];
LIB_UCHARDET = ffi.load(LIB_UCHARDET_PATH)

local function checkEncoding(filePath)

    local assFile = assert(io.open(filePath, 'rb'))
    local BUFFER_SIZE = 65535
    local ud = LIB_UCHARDET.uchardet_new()
    while true do
        local data = assFile:read(BUFFER_SIZE)
        if data == nil or #data == 0 then break end
        local buf = ffi.new("char[?]", string.len(data) + 1, data);
        LIB_UCHARDET.uchardet_handle_data(ud, buf, string.len(data))
    end
    LIB_UCHARDET.uchardet_data_end(ud);
    local charset = LIB_UCHARDET.uchardet_get_charset(ud);
    local detRet = ffi.string(charset);
    LIB_UCHARDET.uchardet_delete(ud);
    return detRet == 'ASCII' and 'UTF-8' or detRet
end

return { checkEncoding = checkEncoding }
