# VideoCompressor Agent Context

## Project Snapshot
- Platform: macOS app (`arm64`, macOS 13+), SwiftUI.
- Packaging: SwiftPM app target + custom `.app`/`.dmg` packaging script.
- Core goal: single-file video compression with adjustable parameters + size/time estimate + runtime log visibility.
- Latest release tag (as of this context): `v1.4.5`.

## Key Paths
- App UI: `VideoCompressor/App/ContentView.swift`
- Main ViewModel: `VideoCompressor/ViewModels/CompressionViewModel.swift`
- FFmpeg command assembly: `VideoCompressor/Services/FFmpegCommandBuilder.swift`
- FFmpeg execution/progress parsing: `VideoCompressor/Services/FFmpegExecutor.swift`
- Media probe: `VideoCompressor/Services/MediaProbeService.swift`
- Size estimate: `VideoCompressor/Services/SizeEstimator.swift`
- Time estimate: `VideoCompressor/Services/CompressionTimeEstimator.swift`
- Localization:
  - `VideoCompressor/Resources/zh-Hans.lproj/Localizable.strings`
  - `VideoCompressor/Resources/en.lproj/Localizable.strings`
- Packaging script: `scripts/package_dmg.sh`
- Release workflow: `.github/workflows/release.yml`

## Current Compression Strategy
- Output container: `mp4`
- Video encoder: `h264_videotoolbox` (switched from `libx264` to avoid some first-frame stalls)
- Audio encoder: `aac`
- FFmpeg flags include:
  - `-nostdin`
  - `-stats_period 0.5`
  - `-progress pipe:1`
  - `-fflags +genpts`
  - `-ignore_editlist 1`
- Scale policy:
  - keep aspect ratio in target box
  - force even width/height for encoder compatibility

## Progress / Time Semantics
- Compression progress (%) is calculated from ffmpeg runtime signals:
  - preferred: `out_time_us`, `out_time_ms`, `out_time`, `time=`
  - fallback: `frame=<n>` / output FPS
- Estimated total time is model-based (pre-run heuristic).
- Remaining time during run now prioritizes real-time speed (`speed=x`) when available.
- If real-time signals are missing, remaining may stay in “calculating” state.

## UX Features Already Added
- Drag/drop + file picker input.
- Presets + manual tuning (resolution/fps/quality/audio settings).
- Aspect ratio lock.
- Size estimate + compression ratio estimate.
- Export directory selection + name conflict suffixing.
- Progress bar + cancel.
- Runtime log panel + copy-log button.
- Theme switch + language switch (zh-Hans / en / system).

## Build / Test / Package
- Run tests:
  - `swift test`
- Build DMG:
  - `./scripts/package_dmg.sh`
- Build ZIP after DMG:
  - `ditto -c -k --sequesterRsrc --keepParent dist/VideoCompressor.app dist/VideoCompressor-arm64.zip`
- Verify DMG:
  - `hdiutil verify dist/VideoCompressor-arm64.dmg`

## Release Process
- Push to `main`.
- Create/push semantic tag `vX.Y.Z`.
- GitHub Actions workflow `Release` runs on tag push and uploads:
  - `dist/VideoCompressor-arm64.dmg`
  - `dist/VideoCompressor-arm64.zip`

## Known Troubleshooting Notes
- If user reports “0% no movement”:
  - Ask for runtime log (UI has copy button).
  - Confirm actual command line from log uses latest flags and `h264_videotoolbox`.
  - Check whether `speed=` and/or `frame=` lines update over time.
- If cancellation is reported as error:
  - inspect `FFmpegExecutor` termination/cancel classification.
- If CI mac runner fails Swift version/tooling:
  - verify `Package.swift` tools version compatibility with GitHub runner image.

