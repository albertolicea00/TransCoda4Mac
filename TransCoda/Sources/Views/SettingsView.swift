import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var queue: JobQueue

    var body: some View {
        Form {
            Section("FFmpeg") {
                LabeledContent("ffmpeg", value: queue.installation?.ffmpeg.path ?? "Not found")
                LabeledContent("ffprobe", value: queue.installation?.ffprobe?.path ?? "Not found")
                LabeledContent("Hardware encoders") {
                    if queue.hardware.encoderNames.isEmpty {
                        Text("None detected")
                    } else {
                        Text(queue.hardware.encoderNames.sorted().joined(separator: ", "))
                    }
                }
            }

            Section {
                Text("TransCoda looks for FFmpeg inside the app bundle, in common Homebrew and MacPorts locations, and on your PATH. Install it with `brew install ffmpeg` if it is missing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
    }
}
