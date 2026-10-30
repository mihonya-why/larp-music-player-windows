# LARP Music Player — Windows

Baka
<img width="498" height="390" alt="anime-tsundere" src="https://github.com/user-attachments/assets/522907f3-1cf0-4a72-a01c-490e553f142c" />

Windows port of [larp-music-player](https://github.com/Raskulchik/larp-music-player).
The original Linux version stays in its own repository; this one is maintained
separately so Windows changes do not affect it.

The player is a terminal UI for Yandex Music, iTunes, SoundCloud, YouTube Music
and local files, with search, playlists, liked tracks, lyrics, listening
statistics, Discord Rich Presence and a CLI.

## What this fork fixes

This is [mihonya-why/larp-music-player-windows](https://github.com/mihonya-why/larp-music-player-windows),
a fork of the Windows port. On top of `v0.4.1` it fixes:

- **The Yandex Music token is no longer deleted.** The daily update check used
  to rewrite `config.json` with an empty `yandex_token`, so a saved token
  silently disappeared after a day and Yandex Music fell back to 30-second
  iTunes previews. The check now only updates its own timestamp.
- **Age-restricted YouTube tracks play** when a cookies file is available
  (`cookies.txt`, see below). Without cookies YouTube refuses every player
  client with `Sign in to confirm your age`.
- **`larp-music-player token <TOKEN>`** saves and validates a Yandex token from
  plain `cmd.exe`, no TUI and no launcher required.
- **`larp-music-player cookies <FILE>`** points the player at a cookies file;
  `%APPDATA%\music-player-tui\cookies.txt` is picked up automatically.
- `save_all_config` no longer overwrites unrelated settings from a stale copy
  of the config.
- The update check follows this fork's releases.

Nothing in the fork depends on a specific terminal: it works in `cmd.exe`,
PowerShell, Windows Terminal, WezTerm or any other console host.


## Requirements

- Windows 10 or newer (Windows 11 recommended)
- `ffmpeg` — required for audio decoding
- `yt-dlp` — required for SoundCloud and YouTube Music playback/downloads
- Python 3 with `ytmusicapi` — optional, improves YouTube Music metadata
- `curl.exe` — included with Windows 10/11

Install with winget:

```powershell
winget install --id Gyan.FFmpeg -e
winget install --id yt-dlp.yt-dlp -e
winget install --id Python.Python.3.13 -e
python -m pip install ytmusicapi
```

Make sure `ffmpeg`, `ffprobe`, `yt-dlp` and `python` are available in `PATH`.
Restart the terminal after installing them.

## Run a release build

1. Download `larp-music-player-windows-x86_64.zip` from the
   [latest release](https://github.com/mihonya-why/larp-music-player-windows/releases/latest).
2. Extract it. Keep `larp-music-player.exe`, `ytmeta.py` and the `scripts`
   folder in the same directory.
3. Run `larp-music-player.exe` without arguments to open the TUI.

### Run it from any terminal (including plain `cmd`)

Nothing needs to be installed into the terminal. Add the extracted folder to
your user `PATH` once:

```bat
setx PATH "%PATH%;C:\path\to\larp-music-player"
```

Open a **new** terminal afterwards, then:

```bat
larp-music-player.exe
```

The token is stored in `%APPDATA%\music-player-tui\config.json` and stays there
between runs, so `cmd.exe`, PowerShell and Windows Terminal all behave the
same. If you prefer not to open the TUI just to log in:

```bat
larp-music-player.exe token <YANDEX_TOKEN>
```

The token is checked against Yandex Music and only saved when it is accepted.
Get one from the
[Yandex OAuth page](https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d).

### Age-restricted YouTube tracks (18+)

YouTube refuses to serve age-restricted audio to anonymous clients, regardless
of the `player_client` used. The player therefore passes a cookies file to
`yt-dlp` when one is configured.

Easiest way: run the helper from the extracted folder (double-click or from
`cmd`/PowerShell):

```bat
scripts\youtube-cookies.cmd
```

It opens Microsoft Edge with a dedicated profile, waits until you close that
window, exports the cookies to
`%APPDATA%\music-player-tui\cookies.txt` and verifies them against an
age-restricted video. Use `-Browser firefox`, `-Browser chrome` or
`-UseExistingProfile` for other setups:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\youtube-cookies.ps1 -Browser chrome
```

The player finds `cookies.txt` automatically. A file elsewhere can be set with:

```bat
larp-music-player.exe cookies "C:\path\to\cookies.txt"
larp-music-player.exe config
```

Cookies expire after a while; re-run the helper when age-restricted tracks stop
working. A dedicated browser profile matters because Chromium-based browsers
lock their cookie database while running.


## Build from source

Install the Rust MSVC toolchain from <https://rustup.rs>, then:

```powershell
git clone https://github.com/mihonya-why/larp-music-player-windows.git
cd larp-music-player-windows
cargo build --release --locked
.\target\release\larp-music-player.exe
```

Run the tests with:

```powershell
cargo test --release --locked
```

The CI workflow builds and tests on `windows-latest`.

## CLI

Run the binary with arguments for CLI mode; run it without arguments to open
the TUI.

```powershell
larp-music-player.exe --help
larp-music-player.exe status
larp-music-player.exe play "Kino - Gruppa Krovi"
larp-music-player.exe volume 40
larp-music-player.exe search "Molchat Doma" -s ytmusic -n 5
larp-music-player.exe stats --top 10
larp-music-player.exe token "y0_AgAAAA..."
larp-music-player.exe cookies "%APPDATA%\music-player-tui\cookies.txt"
```

Playback commands (`status`, `play`, `pause`, `next`, `volume`, ...) talk to a
running TUI. Library and setup commands (`search`, `liked`, `playlists`,
`playlist`, `stats`, `local`, `info`, `config`, `sources`, `token`, `cookies`)
work without a running player.

On Windows the TUI listens on a random `127.0.0.1` port and writes the port plus
an unguessable token to `%LOCALAPPDATA%\music-player-tui\player-control.json`.
The CLI uses that file automatically. The endpoint is not exposed to the
network.

Use `larp-music-player.exe --help` for the full command list and examples.

## Files and configuration

| What | Location |
| --- | --- |
| Config, liked tracks, playlists | `%APPDATA%\music-player-tui\` |
| YouTube cookies (`cookies.txt`) | `%APPDATA%\music-player-tui\` |
| Downloads, PCM cache, control file | `%LOCALAPPDATA%\music-player-tui\` |
| Log | `%TEMP%\music-player-tui.log` |

Yandex Music needs an OAuth token in the config (the TUI prompts for it, or use
`larp-music-player.exe token <TOKEN>`). SoundCloud works without a client ID by
extracting one automatically. A custom SoundCloud client ID, Discord
application ID, Last.fm API key and YouTube cookies path (`ytdlp_cookies`) can
also be set in `config.json`.

## Differences from the Linux version

- MPRIS is not available on Windows.
- The Bluetooth audio-device indicator is Linux-only.
- CLI control uses an authenticated loopback socket instead of a Unix socket.
- Data and config follow Windows conventions (`%APPDATA%`, `%LOCALAPPDATA%`).
- Release artifacts are Windows `.zip` archives.

Discord Rich Presence, mouse input, Unicode titles and all music sources work
on Windows.
