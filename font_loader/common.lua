local function createSymbolLink(sourceFile, linkFile)
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = { "ln", "-s", sourceFile, linkFile }
    })
end

local function removeEmptyDir(dirPath)
    local r = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = { "rmdir", dirPath }
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
