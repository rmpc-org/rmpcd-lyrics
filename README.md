Download synced lyrics for the playing song from [LRCLIB](https://lrclib.net).

> [!IMPORTANT]
> Please consider supporting [LRCLIB](https://lrclib.net) if you use this plugin since they
> provide all the lyrics for free.

## Requirements

`rmpc` has to be installed and available on your `$PATH`.

## Installation

```lua
rmpcd.install({ url = "https://github.com/rmpc-org/rmpcd-lyrics.git" })
```

## Configuration

All options are optional, defaults are below.

```lua
---@type LyricsPluginHandle
local lyrics = rmpcd.install({ url = "https://github.com/rmpc-org/rmpcd-lyrics.git" })
lyrics:setup({
    enabled = true,
    -- Should be the same directory as `lyrics_dir` in your rmpc config. Has to be an absolute path,
    -- `~` is not expanded. You can use `util.deserialize_ron` to read your rmpc config to keep the
    -- two values in sync, but expand `~` in it yourself.
    lyrics_dir = os.getenv("HOME") .. "/Music",
    -- Debounce the downloads so they do not spam LRCLIB when quickly changing songs. Set to 0 to
    -- disable.
    debounce_delay = 1000,
})
```

Lyrics are saved under `lyrics_dir` at the song's path with an `.lrc` extension, for example
`artist/album/song.flac` is saved as `<lyrics_dir>/artist/album/song.lrc`.

## Displaying the lyrics

Set [`lyrics_dir`](https://rmpc.mierak.dev/configuration/lyrics/) in your rmpc config to the same
directory and add the `Lyrics` pane to one of your tabs, for example in your `config.ron`:

```rust
lyrics_dir: Some("~/Music"),
tabs: [
    // ...your other tabs
    (
        name: "Lyrics",
        pane: Pane(Lyrics),
    ),
],
```

## Runtime control

Downloading can be turned on and off without restarting rmpcd by sending a message to the
`rmpcd.lyrics` channel, for example with rmpc:

```sh
rmpc sendmessage rmpcd.lyrics disable
rmpc sendmessage rmpcd.lyrics enable
rmpc sendmessage rmpcd.lyrics toggle
```
