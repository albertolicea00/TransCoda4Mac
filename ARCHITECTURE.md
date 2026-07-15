# Architecture

TransCoda for macOS is a thin native shell around FFmpeg. One window, one
queue, one external process at a time. This document describes the moving
parts and the reasoning behind them.

## Overview

```
┌───────────────────────────────────────────────────────────┐
│ SwiftUI (Views/)                                          │
│   ContentView ── toolbar, drop target, file importer      │
│   JobRowView ── per-job status/progress                   │
│   OutputSettingsView ── inspector panel bound to settings │
└───────────────▲───────────────────────────────────────────┘
                │ @Published state (ObservableObject)
┌───────────────┴───────────────────────────────────────────┐
│ JobQueue (@MainActor)                                     │
│   owns [ConversionJob], ConversionSettings, output dir    │
│   serial processing loop                                  │
└──┬──────────┬──────────────┬──────────────────────────────┘
   │          │              │
   │   FFprobe (duration)    │
   │          │              │
   │   FFmpegCommandBuilder  │  settings → [String] args
   │          │              │
┌──▼──────────▼──────────────▼───────────┐
│ TranscodeEngine                        │  one instance per running job
│   spawns ffmpeg, parses -progress,     │
│   drains stderr, handles cancellation  │
└──────────────────┬─────────────────────┘
                   │ Process
             ffmpeg / ffprobe
   (located once at startup by FFmpegLocator;
    capabilities read once by HardwareCapabilities)
```

## Components

### FFmpegLocator (`Core/FFmpegLocator.swift`)

Finds `ffmpeg`/`ffprobe` once at startup. Order: bundled inside the app
bundle → Homebrew (`/opt/homebrew/bin`, `/usr/local/bin`) → MacPorts →
`/usr/bin` → PATH. GUI apps receive a minimal PATH, which is why the known
locations are checked explicitly. Returns nil when nothing is found; the UI
shows a banner and disables conversion instead of failing later.

### HardwareCapabilities (`Core/HardwareCapabilities.swift`)

Runs `ffmpeg -hide_banner -encoders` once and keeps the set of
`*_videotoolbox` encoder names. `encoder(for:)` answers "is there a hardware
path for this codec" — H.264 and HEVC on Apple hardware; AV1/VP9 always fall
back to software. Detection is data-driven from the actual FFmpeg build rather
than assumed from the OS, so a build without VideoToolbox support degrades
gracefully.

### FFmpegCommandBuilder (`Core/FFmpegCommandBuilder.swift`)

Pure function from `(input, output, settings, hardware)` to `[String]`. The
only place FFmpeg arguments are constructed. Key decisions encoded here:

- Software encoders use CRF (`libx264`/`libx265`: `-crf`, `libsvtav1`:
  `-crf` + `-preset 8`, `libvpx-vp9`: `-crf` + `-b:v 0` + `-row-mt 1`).
- VideoToolbox has no CRF mode; the CRF-style value maps to its `-q:v` 1–100
  scale (higher = better): `q = clamp(100 − 2·crf, 1, 100)`.
- Resolution limiting uses `scale=-2:min(ih\,H)` — `-2` keeps width even
  (encoder requirement), `min()` prevents upscaling.
- HEVC in MP4/MOV gets `-tag:v hvc1` so QuickTime/Apple devices play it.
- MP4/MOV/M4A get `-movflags +faststart`.
- `-progress pipe:1 -nostats -loglevel error` keeps stdout machine-readable
  and stderr small.

### TranscodeEngine (`Core/TranscodeEngine.swift`)

Owns one FFmpeg `Process` for one job. Responsibilities:

- **Progress**: reads stdout line by line; `out_time_us=` (or the misnamed
  `out_time_ms=`, also microseconds) divided by the probed duration gives the
  fraction. Capped at 0.999 until the exit code confirms success.
- **Stall prevention**: stderr is drained concurrently into a 4 KB tail.
  Without this, a chatty encode fills the pipe buffer and FFmpeg blocks.
- **Termination race**: the exit code is delivered through an `AsyncStream`
  whose continuation is installed *before* `run()` — the yield is buffered
  even if the process exits before the engine awaits it.
- **Cancellation**: `cancel()` flips a flag under a lock and terminates the
  process; the run loop then reports `.cancelled` instead of a spurious
  failure, and the queue deletes the partial output file.

### JobQueue (`Core/JobQueue.swift`)

`@MainActor ObservableObject` owning all app state. Processes jobs **serially**:
one FFmpeg encode already saturates the media engine or CPU, and a serial loop
keeps memory flat for arbitrarily large queues. Other behaviors:

- Settings are captured per job at **start time**, so tweaking the inspector
  mid-batch affects the not-yet-started remainder of the queue.
- Output naming: source name with the new extension, in the source folder (or
  a chosen folder); ` 2`, ` 3`… suffixes instead of overwriting. FFmpeg gets
  `-y` because the queue has already guaranteed the path is free.
- Failed/cancelled jobs delete their partial output.
- Duplicate detection: a file already pending is not enqueued twice; finished
  jobs don't block re-adding the same file.

### Models (`Models/`)

`OutputFormat` is the source of truth for container/codec compatibility
(`supportedVideoCodecs`, `supportedAudioCodecs`). `ConversionSettings.normalized()`
clamps any codec choice to the container before a job runs — the UI filters
pickers with the same lists, so normalization is a backstop, not the primary UX.

## Threading model

- Everything UI-visible (`JobQueue`, `ConversionJob`) is `@MainActor`.
- `TranscodeEngine.run` executes in the cooperative pool; progress callbacks
  hop to the main actor via `Task { @MainActor in … }`.
- Short-lived probes (`FFprobe`, `HardwareCapabilities`) run through
  `ProcessRunner`, a continuation-based one-shot process wrapper.

## Deliberate trade-offs

| Decision | Why |
| --- | --- |
| External FFmpeg, not linked libav* | Tiny app, license simplicity, user-upgradable FFmpeg, crash isolation — an encoder crash can't take the app down. |
| Serial queue | Predictable resource usage; parallelism would thrash a single media engine. A concurrency limit is on the roadmap. |
| Unsandboxed dev build | Sandbox blocks spawning Homebrew binaries and writing next to sources. A sandboxed profile with bundled FFmpeg is future work. |
| No persistence | Queue is session-scoped by design; presets/persistence are roadmap items. |
| Settings captured at job start | Least surprising batch behavior: what you see in the inspector is what the next job gets. |
