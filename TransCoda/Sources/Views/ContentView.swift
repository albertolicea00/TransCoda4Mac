import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var queue: JobQueue
    @State private var showInspector = true
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    if queue.ffmpegMissing {
                        FFmpegMissingBanner()
                    }
                }
                .navigationTitle("TransCoda")
                .toolbar { toolbarContent }
        }
        .inspector(isPresented: $showInspector) {
            OutputSettingsView()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
        }
        .dropDestination(for: URL.self) { urls, _ in
            queue.add(urls: urls)
            return true
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audiovisualContent],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                queue.add(urls: urls)
            }
        }
        .frame(minWidth: 660, minHeight: 420)
    }

    @ViewBuilder
    private var content: some View {
        if queue.jobs.isEmpty {
            DropZoneView { showImporter = true }
        } else {
            List(queue.jobs) { job in
                JobRowView(job: job)
            }
            .listStyle(.inset)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showImporter = true
            } label: {
                Label("Add Files", systemImage: "plus")
            }
            .help("Add media files to the queue")

            Button {
                queue.start()
            } label: {
                Label("Convert", systemImage: "play.fill")
            }
            .disabled(
                queue.isProcessing
                    || queue.installation == nil
                    || !queue.jobs.contains { $0.status == .waiting }
            )
            .help("Start converting the queue")

            Button {
                queue.clearFinished()
            } label: {
                Label("Clear Finished", systemImage: "xmark.bin")
            }
            .disabled(!queue.jobs.contains(where: \.isFinished))
            .help("Remove finished jobs from the queue")

            Button {
                showInspector.toggle()
            } label: {
                Label("Output Settings", systemImage: "slider.horizontal.3")
            }
            .help("Show or hide output settings")
        }
    }
}

private struct FFmpegMissingBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("FFmpeg was not found. Install it with **`brew install ffmpeg`** and relaunch.")
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.12))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
