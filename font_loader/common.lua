local win = mp.get_property("platform") == "windows" and true or false;

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
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = { "ln", "-s", sourceFile, linkFile }
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
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = { "unlink", linkFile }
    })
    return r.status == 0
end

local function createDir(dirPath)
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        detach = true,
        args = { "mkdir", "-p", dirPath }
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

return {
    link = createSymbolLink,
    unlink = removeLinkFile,
    rmdir = removeEmptyDir,
    mkdir = createDir,
    randomString = randomString
};
