-- font loading audit report module
-- writes a structured report of which fonts were loaded, failed, or unused per subtitle file.

local utils = require "mp.utils"

local M = {}

local logFile = nil
local videoWritten = false

--- Write the video file path once per session.
---@param path string
---@param cacheKey string
---@param baseCacheDir string
function M.video(path, cacheKey, baseCacheDir)
    if videoWritten then return end
    videoWritten = true
    if not logFile then
        logFile = utils.join_path(baseCacheDir, "font_loader-" .. cacheKey .. ".log")
    end
    local f = io.open(logFile, "w")
    if f then
        f:write("Video: " .. path .. "\n\n")
        f:close()
    end
end

--- Write one subtitle section from context data.
---@param context table
---@param file string subtitle file path
---@param cacheKey string
---@param baseCacheDir string
function M.subtitle(context, file, cacheKey, baseCacheDir)
    if not logFile then
        logFile = utils.join_path(baseCacheDir, "font_loader-" .. cacheKey .. ".log")
    end
    local info = context.subFiles[file]
    if not info then return end

    -- compute unused fonts
    local unused = {}
    if info.styleFontMap then
        for _, fontname in pairs(info.styleFontMap) do
            if not info.usedSet[fontname] then
                unused[#unused + 1] = fontname
            end
        end
        info.styleFontMap = nil
        info.usedSet = nil
    end

    local f = io.open(logFile, "a")
    if not f then return end
    f:write("Subtitle: " .. file .. "\n")
    f:write("  Required: " .. table.concat(info.required, ", ") .. "\n")
    if #info.loaded > 0 then
        f:write("\n")
        for _, entry in ipairs(info.loaded) do
            f:write("  Loaded: " .. entry .. "\n")
        end
    end
    if #info.failed > 0 then
        f:write("\n  Failed: " .. table.concat(info.failed, ", ") .. "\n")
    end
    if #unused > 0 then
        f:write("\n  Unused: " .. table.concat(unused, ", ") .. "\n")
    end
    f:write("\n")
    f:close()

    context.subFiles[file] = nil
end

return M
