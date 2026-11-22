---@meta

---@class LyricsArgs
---@field enabled? boolean Whether lyrics downloading is on when rmpcd starts. Default true.
---@field lyrics_dir? string Absolute path where the `.lrc` files are saved, `~` is not expanded, should be the same as `lyrics_dir` in your rmpc config. Default "$HOME/Music".
---@field debounce_delay? integer Milliseconds to wait after a song change before downloading. Set to 0 to disable. Default 1000.

---@class LyricsPlugin: RmpcdPlugin<LyricsArgs>
---@field enabled boolean
---@field lyrics_dir string
---@field checked_uris table<string, boolean>

---@alias LyricsPluginHandle RmpcdPluginHandle<LyricsArgs>

local M = {}
return M
