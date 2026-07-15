import AppKit
import SwiftUI

struct OutputSettingsView: View {
    @EnvironmentObject private var queue: JobQueue

    var body: some View {
        Form {
            Section("Format") {
                Picker("Container", selection: $queue.settings.format) {
                    Section("Video") {
                        ForEach(OutputFormat.videoFormats) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    Section("Audio only") {
                        ForEach(OutputFormat.audioFormats) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                }
            }

            if !queue.settings.format.isAudioOnly {
                Section("Video") {
                    Picker("Codec", selection: $queue.settings.videoCodec) {
                        ForEach(queue.settings.format.supportedVideoCodecs) { codec in
                            Text(codec.displayName).tag(codec)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Quality", value: "CRF \(queue.settings.quality)")
                        Slider(value: qualityBinding, in: 14...38, step: 1)
                        HStack {
                            Text("Better")
                            Spacer()
                            Text("Smaller")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Picker("Resolution", selection: $queue.settings.maxHeight) {
                        Text("Original").tag(Int?.none)
                        ForEach([2160, 1440, 1080, 720, 480], id: \.self) { height in
                            Text("\(height)p").tag(Int?.some(height))
                        }
                    }

                    Toggle("Hardware acceleration", isOn: $queue.settings.useHardwareAcceleration)
                }
            }

            Section("Audio") {
                Picker("Codec", selection: $queue.settings.audioCodec) {
                    ForEach(queue.settings.format.supportedAudioCodecs) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }
                if queue.settings.audioCodec.supportsBitrate {
                    Picker("Bitrate", selection: $queue.settings.audioBitrateKbps) {
                        ForEach([96, 128, 160, 192, 256, 320], id: \.self) { kbps in
                            Text("\(kbps) kbps").tag(kbps)
                        }
                    }
                }
            }

            Section("Destination") {
                LabeledContent("Save to") {
                    Text(queue.outputDirectory?.lastPathComponent ?? "Same folder as source")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack {
                    Button("Choose Folder…", action: chooseFolder)
                    if queue.outputDirectory != nil {
                        Button("Reset") { queue.outputDirectory = nil }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: queue.settings.format) {
            queue.settings = queue.settings.normalized()
        }
    }

    private var qualityBinding: Binding<Double> {
        Binding(
            get: { Double(queue.settings.quality) },
            set: { queue.settings.quality = Int($0) }
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            queue.outputDirectory = panel.url
        }
    }
}
