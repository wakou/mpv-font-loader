-- font index loading and cache management

local utils = require "mp.utils"
local log = require "mp.msg"
local fc = require "fc"

local M = {}

local IDX_DB_NAME = "fc-subs.db"
local IDX_CACHE_FILE = "~~/font-index"
local REMOTE_IDX_CACHE_FILE = "~~/font-index-remote"

--- Load or build the font index, handling remote dir fallback.
---@param options table script options (fontDir, remoteFontDir)
---@return table fontIndex, string fontDir
function M.load(options, baseCacheDir)
    local fontDir = mp.command_native({ "expand-path", options.fontDir })

    -- if remote font dir is configured and available, use it instead of local
    local idxDbPath = utils.join_path(fontDir, IDX_DB_NAME)
    local fontIndexFile = mp.command_native({ "expand-path", IDX_CACHE_FILE })
    if options.remoteFontDir ~= "" then
        local rdir = mp.command_native({ "expand-path", options.remoteFontDir })
        if utils.file_info(rdir) ~= nil then
            local rdb = utils.join_path(rdir, IDX_DB_NAME)
            if utils.file_info(rdb) ~= nil then
                fontDir = rdir
                idxDbPath = rdb
                fontIndexFile = mp.command_native({ "expand-path", REMOTE_IDX_CACHE_FILE })
                log.info("use remote font dir: " .. rdir)
            end
        else
            log.warn("remote font dir not accessible: " .. rdir .. ", fallback to local")
        end
    end

    local idxFileExist = utils.file_info(fontIndexFile) ~= nil
    local fontIndex

    local idxDbInfo = utils.file_info(idxDbPath)
    local cacheOutdated = false
    if idxFileExist and idxDbInfo then
        local cacheInfo = utils.file_info(fontIndexFile)
        cacheOutdated = idxDbInfo.mtime > cacheInfo.mtime
    end

    local rebuild = not idxFileExist or cacheOutdated

    if rebuild then
        log.info("build index from fc-subs.db")
        fontIndex = fc.buildIndex(idxDbPath)
        log.info("build index end")
        log.info("store font index data to cache file")
        fc.saveIdxToFile(fontIndex, fontIndexFile)
    else
        log.info("load font index data from index cache file [" .. fontIndexFile .. "]")
        fontIndex = fc.loadIdx(fontIndexFile)
        log.info("load font index data from index cache file end")
    end

    return fontIndex, fontDir
end

return M
