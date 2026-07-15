# CLAUDE.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project overview

TransCoda for macOS — a native SwiftUI app that converts video/audio files by
driving an external FFmpeg process. Thin shell around FFmpeg; the app itself
must stay tiny and idle-cheap. Sister project (independent repo, same
architecture on WinUI 3): [TransCoda4Windows](https://github.com/albertolicea00/TransCoda4Windows).

## Build & run

```sh
brew install xcodegen ffmpeg   # one-time
xcodegen                       # regenerates TransCoda.xcodeproj from project.yml
open TransCoda.xcodeproj       # build/run the TransCoda scheme
```

- `TransCoda.xcodeproj` is **generated and gitignored** — never edit or commit
  it. Target/build-setting changes go in `project.yml`, then re-run `xcodegen`.
- Adding a Swift file under `TransCoda/Sources/` requires re-running `xcodegen`
  so the project picks it up.
- Dev builds run unsandboxed (see `project.yml` comment) so the app can spawn
  Homebrew FFmpeg and write next to source files.

## Layout

```
project.yml              XcodeGen project definition (bundle id, entitlements, Info.plist)
TransCoda/Sources/
  App/                   @main entry, Scene setup
  Models/                OutputFormat/VideoCodec/AudioCodec, ConversionSettings, ConversionJob
  Core/                  FFmpegLocator, FFprobe, HardwareCapabilities,
                         FFmpegCommandBuilder, TranscodeEngine, JobQueue
  Views/                 SwiftUI views only — no process logic here
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces interact.

## Hard rules

- **Native only.** SwiftUI/AppKit. No web views, no cross-platform UI layers,
  no SPM dependencies. A PR that adds a dependency needs an extraordinary reason.
- **FFmpeg args are lists, never shell strings.** Everything goes through
  `Process.arguments`. No `sh -c`, no string interpolation of user paths into
  commands.
- **Views stay dumb.** Anything touching `Process`, the filesystem, or FFmpeg
  lives in `Core/`. Views read `JobQueue`/`ConversionJob` observable state.
- **UI state is MainActor.** `JobQueue` and `ConversionJob` are `@MainActor`.
  Engine progress callbacks hop back via `Task { @MainActor in … }` — keep it
  that way.
- Behavior changes (formats, codecs, FFmpeg arguments, queue semantics) should
  stay mirrored with TransCoda4Windows; flag divergence in the PR.

## Gotchas (learned, don't re-litigate)

- FFmpeg's `-progress` line `out_time_ms=` is **microseconds** despite the
  name; `out_time_us=` is preferred when present. Parsing handles both.
- VideoToolbox has **no CRF mode** — quality maps to `-q:v` 1–100 (higher =
  better) in `FFmpegCommandBuilder`.
- stderr must be drained concurrently during an encode or FFmpeg stalls on a
  full pipe buffer (`TranscodeEngine`).
- HEVC in MP4/MOV needs `-tag:v hvc1` or QuickTime won't recognize the track.
- FFmpeg binaries are never committed. Lookup order: bundled → Homebrew/
  MacPorts paths → PATH (`FFmpegLocator`).

## Commits

Conventional Commits, no scope needed (single-platform repo):
`feat: …`, `fix: …`, `docs: …`, `chore: …` — lower case, imperative, no period.
No AI attribution or Co-Authored-By trailers in commit messages.
