-- font loading audit log module
-- writes a structured log of which fonts were loaded (or failed) per subtitle file

local utils = require "mp.utils"

local M = {}

local logFile = nil
local videoWritten = false

--- Initialize the log file path. Must be called before any write.
---@param cacheKey string unique session key from main.lua
---@param baseCacheDir string base cache directory path
function M.setup(cacheKey, baseCacheDir)
    logFile = utils.join_path(baseCacheDir, "font_loader-" .. cacheKey .. ".log")
end

--- Append a line to the log file.
---@param msg string
function M.write(msg)
    if not logFile then return end
    local f = io.open(logFile, "a")
    if f then
        f:write(msg .. "\n")
        f:close()
    end
end

--- Write the video file path once per session.
---@param path string
function M.video(path)
    if videoWritten then return end
    videoWritten = true
    M.write("Video: " .. path)
end

--- Write a subtitle section: required, loaded, and failed fonts.
---@param file string subtitle file path
---@param required string[] list of required font names
---@param loaded string[] list of "face -> filepath" entries
---@param failed string[] list of font names that could not be found
function M.subtitle(file, required, loaded, failed)
    M.write("")
    M.write("Subtitle: " .. file)
    M.write("  Required: " .. table.concat(required, ", ") .. '\n')
    if #loaded > 0 then
        for _, entry in ipairs(loaded) do
            M.write("  Loaded: " .. entry)
        end
    end
    if #failed > 0 then
        M.write("\n  Failed: " .. table.concat(failed, ", "))
    end
end

return M
