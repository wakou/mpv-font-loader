--[[
    This script can auto load font which define in external ass file.

    When open a video, this script search for sub tracks with external flag in the track list;
    Then script parse sub file (must be a ass type sub file), get font name list.
    This script find real font file in font dir accounding font name,
    create a symbol link for font file under a temp dir.

    Finally, script use the path of the temp dir as the value of the property `sub-fonts-dir`,
    libass would load font in the temp dir.

    This script requires a font dir, this dir stores font files.
    The dir path must be passed to the `fontDir` script-opt.

    This script also need other lua module lua-cbor to save index cache to file and load it, because parse fc-subs.db will spent some time, so this script will not use fc-subs.db after first parse.

    The font dir must contain a file called fc-subs.db, the file is generated by a project `FontLoaderSub`.
    In fact, the idea of writing this script came from this project

    FontLoaderSub: https://github.com/yzwduck/FontLoaderSub

    This script also need other lua module lua-cbor to save index cache to file and load it, because parse fc-subs.db will spent some time, so this script will not use fc-subs.db after first parse.

    lua-cbor: https://github.com/Zash/lua-cbor
]]
--

local utils = require "mp.utils"
local log = require "mp.msg"
local fc = require "fc"
local ass = require "ass"
local cbor = require "cbor"
local common = require "common"

local options = {
    fontDir = "",
    idxDbName = "fc-subs.db",
    fontIndexFile = "~~/font-index",
    cacheDir = "~~/fontCache/"
}

require "mp.options".read_options(options, "font_loader")

local fontDir = mp.command_native({ "expand-path", options.fontDir })
local baseCacheDir = mp.command_native({ "expand-path", options.cacheDir })

log.info("create base cache dir: " .. baseCacheDir)
common.mkdir(baseCacheDir)

local fontIndexFile = mp.command_native({ "expand-path", options.fontIndexFile })

local idxFileExist = utils.file_info(fontIndexFile) ~= nil
local fontIndex

if cbor == nil or not idxFileExist then
    local fontIdxDb = utils.join_path(fontDir, options.idxDbName)
    log.info("no fount index cache file, build index from fc-subs.db")
    fontIndex = fc.buildIndex(fontIdxDb)
    log.info("build index end")
end

if cbor ~= nil and idxFileExist then
    log.info("load font index data from index cache file with lua-cbor")
    fontIndex = fc.loadIdx(fontIndexFile)
else
    log.info("store font index data to cache file")
    fc.saveIdxToFile(fontIndex, fontIndexFile)
end

local cacheKey = os.date("%Y%m%d%H%M%S_") .. common.randomString(6)
local fontCacheDir = utils.join_path(baseCacheDir, cacheKey)
log.info("create font cache dir, path is: " .. fontCacheDir)
common.mkdir(fontCacheDir)

local assFileSet = {}
local fontSet = {}
local linkFileList = {}
local linkFileSize = 0

local function scanNewSubFile(trackList)
    local subFileList = {}
    local size = 0
    for _, track in pairs(trackList) do
        if track.type == 'sub' and track.external then
            local path = track["external-filename"]
            if assFileSet[path] == nil then
                size = size + 1
                subFileList[size] = path
            end
        end
    end
    return subFileList, size
end


local function loadFont(_, trackList)
    local subFileList, subFileSize = scanNewSubFile(trackList)
    local newFont = {}
    local newFontSize = 0

    for i = 1, subFileSize do
        local file = subFileList[i]
        assFileSet[file] = false
        local fontList = ass.getFontListFromAss(file) or {}
        for _, font in pairs(fontList) do
            if fontSet[font] == nil then
                local fontFromIdx = fontIndex[font]
                if fontFromIdx ~= nil then
                    newFont[fontFromIdx.filename] = true
                    newFontSize = newFontSize + 1
                    for _, face in pairs(fontFromIdx.faces) do
                        fontSet[face] = true
                    end
                else
                    fontSet[font] = false
                    log.warn("font not find: " .. font)
                end
            end
        end
    end

    for filename, _ in pairs(newFont) do
        local linkFile = utils.join_path(fontCacheDir, filename)
        local sourceFile = utils.join_path(fontDir, filename);
        log.debug("create link file: " .. linkFile)
        common.link(sourceFile, linkFile)
        linkFileSize = linkFileSize + 1
        linkFileList[linkFileSize] = linkFile
    end

    if newFontSize > 0 then
        local sid = mp.get_property_number("sid") or 0
        if sid > 0 then
            mp.set_property_number("sid", 0)
            mp.set_property_number("sid", sid)
        end
    end
end

local function removeCache()
    for i = 1, linkFileSize do
        local linkFile = linkFileList[i]
        log.debug("remove font link file: " .. linkFile)
        common.unlink(linkFile)
    end
    log.debug("remove font cache dir: " .. fontCacheDir)
    common.rmdir(fontCacheDir)
end

local function onFileLoaded(e)
    log.debug("event: " .. e.event)
    local trackList = mp.get_property_native("track-list")
    loadFont(nil, trackList)
end

local function onTrackListProp(e, trackList)
    log.debug("property: " .. e)
    loadFont(e, trackList)
end

mp.set_property("sub-fonts-dir", fontCacheDir)
mp.observe_property("track-list", "native", onTrackListProp)
-- -- mp.register_event("file-loaded", test1)
-- mp.register_event("file-loaded", onFileLoaded)
mp.register_event('shutdown', removeCache)
