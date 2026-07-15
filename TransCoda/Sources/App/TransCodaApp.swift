import SwiftUI

@main
struct TransCodaApp: App {
    @StateObject private var queue = JobQueue()

    var body: some Scene {
        Window("TransCoda", id: "main") {
            ContentView()
                .environmentObject(queue)
        }
        .defaultSize(width: 880, height: 560)

        Settings {
            SettingsView()
                .environmentObject(queue)
        }
    }
}
