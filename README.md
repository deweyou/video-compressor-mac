# VideoCompressor (ARM macOS)

A SwiftUI macOS app for single-file video compression with tunable parameters.

## Features

- Drag-and-drop or file picker input.
- Language switcher (System / Chinese / English).
- Theme switcher (System / Light / Dark).
- Compression presets + manual controls:
  - Resolution (width/height)
  - Lock aspect ratio while resizing
  - FPS
  - Quality (mapped to target video bitrate)
  - Audio bitrate, sample rate, channels
- Real-time estimated output size:
  - Original size
  - Estimated size
  - Estimated compression ratio
  - Estimated compression time
  - Remaining time countdown during compression
- Export directory selection.
- Auto conflict naming (`-1`, `-2`, ...).
- Compression progress + cancel.
- Custom app icon.

## Tech

- macOS 13+
- SwiftUI
- FFmpeg/FFprobe command execution
- Swift Package (open `Package.swift` in Xcode)

## Important: FFmpeg binaries

This repository includes placeholder scripts at:

- `VideoCompressor/Resources/ffmpeg`
- `VideoCompressor/Resources/ffprobe`

Replace both with real **arm64 executable binaries** before runtime compression/probing.

They must remain executable:

```bash
chmod +x VideoCompressor/Resources/ffmpeg VideoCompressor/Resources/ffprobe
```

## Run

1. Open `Package.swift` in Xcode.
2. Select `VideoCompressor` scheme.
3. Run on macOS.

Or build in terminal:

```bash
swift build --build-system native
```

## Package DMG

```bash
./scripts/package_dmg.sh
```

Output:

- `dist/VideoCompressor-arm64.dmg`

## Notes

- Output format is fixed: `MP4 (H.264 + AAC)`.
- V1 scope is single-file compression only.
- Non-App Store mode (no sandbox bookmark persistence).
- Unit tests require a toolchain that provides `XCTest` or `Testing` (full Xcode recommended).

## Project layout

```text
VideoCompressor/
  App/
  Domain/
  Services/
  ViewModels/
  Resources/
Tests/VideoCompressorTests/
```
