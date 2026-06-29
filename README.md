# WireHack
### Minimal yt-dlp wrapper for macOS

<p align="center">
  <a href="https://github.com/sevmorris/WireHack/releases/latest/download/WireHack-v1.10.0.dmg"><strong>Download Latest (DMG)</strong></a>
  ·
  <a href="https://github.com/sevmorris/WireHack/issues">Report Bug</a>
</p>

**WireHack** is a simple, polished macOS utility designed to grab audio or video from URLs (YouTube, Soundcloud, etc.) and download the native source files directly. It provides a clean GUI for `yt-dlp`, removing the need for terminal commands when you just need a quick clip for a mix.

---

## Features
*   **Simple Interface:** Paste a URL and click one button.
*   **Native Formats:** Bypass slow and error-prone `ffmpeg` transcodes by fetching the native `ba` (best audio) or `best` (best video) files from the server.
*   **Destination Selection:** Save directly to Downloads or choose a custom folder.
*   **No Playlist Mode:** Focuses on single clips to prevent accidental bulk downloads.
*   **Native Design:** Built with SwiftUI for a modern macOS feel.

---

## Requirements
*   **yt-dlp**: Must be on disk at one of: `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin`, `~/.local/bin`, or `/usr/bin`. Homebrew (`brew install yt-dlp`) covers Apple Silicon and Intel automatically.
*   **ffmpeg**: Required by `yt-dlp` for audio extraction and conversion.

---

## Installation
1.  Download the latest [DMG](https://github.com/sevmorris/WireHack/releases/latest).
2.  Drag **WireHack** to your Applications folder.
3.  Ensure you have `yt-dlp` installed via Homebrew: `brew install yt-dlp`.

---

### License
Copyright © 2026 Seven Morris.
Distributed under the [GNU General Public License v3.0](LICENSE).
