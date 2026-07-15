import SwiftUI

struct DropZoneView: View {
    var onBrowse: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Drop media files here")
                    .font(.title3.weight(.medium))
                Text("Video and audio files will be added to the conversion queue.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Browse…", action: onBrowse)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(.quaternary)
                .padding(24)
        }
    }
}
