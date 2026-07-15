import AppKit
import SwiftUI

struct JobRowView: View {
    @EnvironmentObject private var queue: JobQueue
    @ObservedObject var job: ConversionJob

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: job.settings.format.isAudioOnly ? "waveform" : "film")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(job.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                statusLine
            }

            Spacer(minLength: 12)

            trailingControl
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch job.status {
        case .waiting:
            Text("Waiting")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .probing:
            Text("Preparing…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 8) {
                ProgressView(value: job.progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 280)
                Text(job.progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .completed:
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        case .cancelled:
            Text("Cancelled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch job.status {
        case .waiting, .probing, .running:
            rowButton(systemImage: "xmark.circle.fill", help: "Cancel") {
                queue.cancel(job)
            }
        case .completed:
            rowButton(systemImage: "magnifyingglass.circle.fill", help: "Show in Finder") {
                if let outputURL = job.outputURL {
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                }
            }
        case .failed, .cancelled:
            rowButton(systemImage: "xmark.circle.fill", help: "Remove") {
                queue.remove(job)
            }
        }
    }

    private func rowButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
