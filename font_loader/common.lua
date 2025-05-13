local utils = require "mp.utils"
local platfrom = mp.get_property("platform")
local win = platfrom == "windows" and true or false;
local script_path = mp.get_script_directory();

local function createLinkArgsWin(sourceFile, linkFile)
    local sourceFile1 = sourceFile:gsub("/", "\\")
    local linkFile1 = linkFile:gsub("/", "\\")
    return { "cmd", "/c", "mklink", linkFile1, sourceFile1 }
end

local function createLinkArgs(sourceFile, linkFile)
    return { "ln", "-s", sourceFile, linkFile }
end

local function removeLinkArgsWin(linkFile)
    local linkFile1 = linkFile:gsub("/", "\\")
    return { "cmd", "/c", "del", linkFile1 }
end

local function removeLinkArgs(linkFile)
    return { "unlink", linkFile }
end

local function createDirArgsWin(dirPath)
    local dirPath1 = dirPath:gsub("/", "\\")
    return { "cmd", "/c", "mkdir", dirPath1 }
end

local function createDirArgs(dirPath)
    return { "mkdir", "-p", dirPath }
end

local function removeEmptyDirArgsWin(dirPath)
    local dirPath1 = dirPath:gsub("/", "\\")
    return { "cmd", "/c", "rmdir", dirPath1 }
end

local function removeEmptyDirArgs(dirPath)
    return { "rmdir", dirPath }
end

local function createSymbolLink(sourceFile, linkFile)
    local command = win and createLinkArgsWin or createLinkArgs
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = command(sourceFile, linkFile)
    })
end

local function removeEmptyDir(dirPath)
    local command = win and removeEmptyDirArgsWin or removeEmptyDirArgs
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = false,
        detach = true,
        args = command(dirPath)
    })
    return r.status == 0
end

local function removeLinkFile(linkFile)
    local command = win and removeLinkArgsWin or removeLinkArgs
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = command(linkFile)
    })
    return r.status == 0
end

local function createDir(dirPath)
    local command = win and createDirArgsWin or createDirArgs
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        detach = true,
        args = command(dirPath)
    })
    return r.status == 0
end

local charset = {}
do -- [0-9a-zA-Z]
    for c = 48, 57 do table.insert(charset, string.char(c)) end
    for c = 65, 90 do table.insert(charset, string.char(c)) end
end

local function randomString(length)
    if not length or length <= 0 then return '' end
    math.randomseed(os.clock() ^ 5)
    return randomString(length - 1) .. charset[math.random(1, #charset)]
end

local WIN_ICONV_NAME = "iconv.dll"
local WIN_UCHARDET_NAME = "uchardet.dll"
local OSX_ICONV_NAME = "libiconv.dylib"
local OSX_UCHARDET_NAME = "libuchardet.dylib"
local LINUX_ICONV_NAME = "libiconv.so"
local LINUX_UCHARDET_NAME = "libuchardet.so"

local iconvName, uchardetName
if platfrom == "darwin" then
    iconvName = OSX_ICONV_NAME
    uchardetName = OSX_UCHARDET_NAME
elseif platfrom == "windows" then
    iconvName = WIN_ICONV_NAME
    uchardetName = WIN_UCHARDET_NAME
else
    iconvName = LINUX_ICONV_NAME
    uchardetName = LINUX_UCHARDET_NAME
end

local LIB_ICONV_PATH = utils.join_path(script_path, iconvName)
local LIB_UCHARDET_PATH = utils.join_path(script_path, uchardetName)

return {
    link = createSymbolLink,
    unlink = removeLinkFile,
    rmdir = removeEmptyDir,
    mkdir = createDir,
    randomString = randomString,
    LIB_ICONV_PATH = LIB_ICONV_PATH,
    LIB_UCHARDET_PATH = LIB_UCHARDET_PATH
};
