local LRCLIB_URL = "https://lrclib.net/api/get"
local USER_AGENT = "rmpcd-lyrics (https://github.com/rmpc-org/rmpcd-lyrics)"
local REQUEST_TIMEOUT_MS = 10000

---@type LyricsPlugin
---@diagnostic disable-next-line: missing-fields
local M = {}

local rmpc_found = false

---@param level "info" | "warn" | "error"
---@param message string
local function show_status(level, message)
    process.spawn({ "rmpc", "remote", "status", "--level", level, message })
end

---@param lyrics_dir string
---@param uri string
---@return string
local function lrc_path_for(lyrics_dir, uri)
    local lrc_path = uri:gsub("%.[^./]*$", "") .. ".lrc"
    if lrc_path:sub(1, 1) == "/" then
        return lrc_path
    end
    return lyrics_dir .. "/" .. lrc_path
end

---@param self LyricsPlugin
---@param song Song
local function download(self, song)
    if song.file:find("://", 1, true) then
        log.warn("'" .. song.file .. "' is a either stream or song outside MPD's music directory, skipping")
        return
    end

    if self.checked_uris[song.file] then
        log.debug("Lyrics for '" .. song.file .. "' were already checked, skipping")
        return
    end
    self.checked_uris[song.file] = true

    local lrc_path = lrc_path_for(self.lyrics_dir, song.file)
    if fs.exists(lrc_path) then
        log.debug("Lyrics already exist at '" .. lrc_path .. "', skipping")
        return
    end

    if song.artist == nil or song.title == nil then
        log.warn("Missing artist or title, cannot fetch lyrics for '" .. song.file .. "'")
        show_status("warn", "Cannot download lyrics for '" .. song.file .. "' due to incomplete metadata")
        return
    end

    local params = {
        artist_name = song.artist:first(),
        track_name = song.title:first(),
    }

    local duration_secs = math.floor(song.duration / 1000 + 0.5)
    if duration_secs >= 1 and duration_secs <= 3600 then
        params.duration = tostring(duration_secs)
    end
    if song.album ~= nil then
        params.album_name = song.album:first()
    end

    local name = song.artist .. " - " .. song.title
    log.info("Fetching lyrics for '" .. name .. "'")
    local response = http.get(LRCLIB_URL, {
        timeout_ms = REQUEST_TIMEOUT_MS,
        headers = { ["User-Agent"] = USER_AGENT },
        params = params,
    })

    if response.code == 404 then
        log.info("Lyrics for '" .. name .. "' not found")
        show_status("warn", "Lyrics for '" .. name .. "' not found")
        return
    end

    if response.error ~= nil or response.code ~= 200 then
        local reason = response.error or ("HTTP " .. tostring(response.code))
        log.error("Failed to fetch lyrics for '" .. name .. "': " .. reason)
        show_status("error", "Failed to download lyrics")

        -- Try again next time, this could be a temporary network error
        self.checked_uris[song.file] = nil
        return
    end

    local ok, body = pcall(response.json, response)
    if not ok or type(body) ~= "table" then
        log.error("Invalid response from LRCLIB for '" .. name .. "': " .. tostring(body))
        show_status("error", "Failed to download lyrics")
        self.checked_uris[song.file] = nil
        return
    end

    local synced_lyrics = body.syncedLyrics
    if util.nil_or_null(synced_lyrics) or synced_lyrics == "" then
        log.info("Synced lyrics for '" .. name .. "' not found")
        show_status("warn", "Synced lyrics for '" .. name .. "' not found")
        return
    end

    local lrc = "[ar:" .. song.artist .. "]\n"
    if song.album ~= nil then
        lrc = lrc .. "[al:" .. song.album .. "]\n"
    end
    lrc = lrc .. "[ti:" .. song.title .. "]\n" .. synced_lyrics

    log.info("Saving lyrics to '" .. lrc_path .. "'")
    local _, err = fs.create_dir_all(lrc_path:match("^(.*)/"))
    if err == nil then
        _, err = fs.write_str(lrc_path, lrc)
    end
    if err ~= nil then
        log.error("Failed to save lyrics to '" .. lrc_path .. "': " .. err)
        show_status("error", "Failed to save lyrics")
        return
    end

    process.spawn({ "rmpc", "remote", "indexlrc", "--path", lrc_path })
end

---@param _self LyricsPlugin
---@param _song Song
local function download_debounced(_self, _song) end

M.setup = function(self, args)
    if not args then
        args = {}
    end
    self.enabled = args.enabled ~= false
    self.lyrics_dir = args.lyrics_dir or (os.getenv("HOME") .. "/Music")
    if self.lyrics_dir:sub(1, 1) ~= "/" then
        error("lyrics_dir has to be an absolute path, '~' is not expanded: '" .. self.lyrics_dir .. "'")
    end
    self.checked_uris = {}

    rmpc_found = util.which("rmpc")
    if not rmpc_found then
        log.error("rmpc not found in PATH, disabling lyrics plugin")
        self.enabled = false
    end

    local debounce_delay = args.debounce_delay or 1000
    if debounce_delay <= 0 then
        download_debounced = download
    else
        download_debounced = sync.debounce(debounce_delay, download)
    end
end

M.song_change = function(self, _old_song, new_song)
    if not self.enabled then
        return
    end

    if new_song == nil then
        return
    end

    download_debounced(self, new_song)
end

---@param plugin LyricsPlugin
---@param enabled boolean
local function set_enabled(plugin, enabled)
    if enabled and not rmpc_found then
        log.warn("rmpc not found in PATH, lyrics plugin stays disabled")
        return
    end

    log.info((enabled and "Enabling" or "Disabling") .. " lyrics plugin")
    plugin.enabled = enabled
end

M.subscribed_channels = { "rmpcd.lyrics" }
M.message = function(self, _channel, message)
    if message == "enable" then
        set_enabled(self, true)
    elseif message == "disable" then
        set_enabled(self, false)
    elseif message == "toggle" then
        set_enabled(self, not self.enabled)
    end
end

return M
