import Foundation

@MainActor
final class ConversionJob: ObservableObject, Identifiable {
    enum Status: Equatable {
        case waiting
        case probing
        case running
        case completed
        case failed(String)
        case cancelled
    }

    nonisolated let id = UUID()
    nonisolated let sourceURL: URL

    @Published var status: Status = .waiting
    @Published var progress: Double = 0

    var settings: ConversionSettings
    var durationSeconds: Double?
    var outputURL: URL?

    init(sourceURL: URL, settings: ConversionSettings) {
        self.sourceURL = sourceURL
        self.settings = settings
    }

    var fileName: String { sourceURL.lastPathComponent }

    var isFinished: Bool {
        switch status {
        case .completed, .failed, .cancelled: true
        case .waiting, .probing, .running: false
        }
    }
}
