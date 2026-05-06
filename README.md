# WireHack
### Minimal yt-dlp wrapper for macOS

<p align="center">
  <a href="https://github.com/sevmorris/WireHack/releases/latest/download/WireHack-v1.5.0.dmg"><strong>Download Latest (DMG)</strong></a>
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
*   **yt-dlp**: Must be installed at `/opt/homebrew/bin/yt-dlp`.
*   **ffmpeg**: Required by `yt-dlp` for audio extraction and conversion.

---

## Installation
1.  Download the latest [DMG](https://github.com/sevmorris/WireHack/releases/latest).
2.  Drag **WireHack** to your Applications folder.
3.  Ensure you have `yt-dlp` installed via Homebrew: `brew install yt-dlp`.

---

## For Developers
The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to manage the project file.

1.  Clone the repo.
2.  Run `xcodegen generate`.
3.  Open `WireHack.xcodeproj`.

### Releasing
Use the bundled release script to build, sign, and notarize:
```bash
./release.sh 1.0.x
```

---

### License
Copyright © 2026 Seven Morris.
Distributed under the [GNU General Public License v3.0](LICENSE).
