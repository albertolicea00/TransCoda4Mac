# TransCoda for macOS

**Fast, tiny, fully native media conversion for macOS.**

TransCoda converts video and audio files with FFmpeg behind a clean, native
SwiftUI interface. No Electron, no web runtime, no bundled browser — it looks,
feels, and performs like it belongs on your Mac: translucent inspector panel,
SF Symbols, native toolbar, drag & drop straight from Finder.

> Looking for the Windows app? See
> [TransCoda4Windows](https://github.com/albertolicea00/TransCoda4Windows) —
> an independent repository with the same architecture built natively on
> WinUI 3.

## Why native?

A media converter spends its resources on one thing: encoding. The UI should
cost almost nothing. Design goals, in order:

1. **Minimal footprint.** Idle RAM in the tens of megabytes, near-zero idle
   CPU, small binary. Every resource the app doesn't use is a resource FFmpeg can.
2. **Platform integration.** Follows the macOS Human Interface Guidelines
   instead of shipping a lowest-common-denominator UI.
3. **Simple, honest engine.** The app is a thin native shell around FFmpeg.
   You can read the exact command each conversion runs.

## Features

- Batch conversion queue with per-file progress, cancel, and reveal in Finder.
- Video containers: MP4, MKV, MOV, WebM.
- Video codecs: H.264/AVC, H.265/HEVC, AV1, VP9.
- Audio-only output: M4A (AAC), MP3, FLAC, Opus, WAV.
- Quality control with a CRF-style slider, resolution limiting, audio bitrate selection.
- **Apple VideoToolbox hardware encoding** (H.264, HEVC), auto-detected from
  the local FFmpeg build — encodes on the media engine at a fraction of the CPU cost.
- Accurate progress from FFmpeg's machine-readable `-progress` stream.
- Output next to the source file or to a folder you choose; never overwrites
  existing files.

## How it works

```
┌─────────────────────────────┐
│  SwiftUI                    │  queue list, drag & drop, inspector settings
├─────────────────────────────┤
│  JobQueue                   │  ordered processing, one encode at a time
│  FFmpegCommandBuilder       │  settings → argument list (no shell involved)
│  TranscodeEngine            │  spawns ffmpeg, parses -progress, cancellation
│  HardwareCapabilities       │  parses `ffmpeg -encoders` once at startup
│  FFprobe                    │  duration probe for progress percentage
│  FFmpegLocator              │  bundled binary → known paths → PATH
└─────────────────────────────┘
            │
            ▼
        ffmpeg / ffprobe  (external processes)
```

FFmpeg binaries are **not** committed to this repository. The app looks for
them in this order: bundled inside the app, Homebrew/MacPorts locations, then
`PATH`.

## Getting FFmpeg

```sh
brew install ffmpeg
```

(or MacPorts: `sudo port install ffmpeg`). AV1 encoding uses `libsvtav1`,
included in the standard Homebrew build.

## Building

Requirements: macOS 14+, Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen            # generates TransCoda.xcodeproj from project.yml
open TransCoda.xcodeproj
```

Build and run the `TransCoda` scheme. The dev build runs unsandboxed so it can
launch a Homebrew-installed FFmpeg and write output next to your source files;
a sandboxed App Store profile is future work.

## Project layout

```
project.yml            XcodeGen project definition
TransCoda/Sources/
  App/                 app entry point
  Models/              formats, codecs, settings, job model
  Core/                locator, prober, command builder, engine, queue
  Views/               SwiftUI views
```

## Roadmap

- Presets (save/load named conversion profiles)
- Subtitle pass-through and burn-in
- HDR metadata pass-through
- Trim / clip range selection
- Sandboxed, notarized releases

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). This project follows the
[Contributor Covenant](CODE_OF_CONDUCT.md) code of conduct and uses
[Conventional Commits](https://www.conventionalcommits.org/).

## License

[MIT](LICENSE) © 2026 Alberto Licea
