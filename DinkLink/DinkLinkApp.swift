import SwiftData
import SwiftUI

@main
struct DinkLinkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PlayerProfile.self, StoredGameSession.self])
    }
}
