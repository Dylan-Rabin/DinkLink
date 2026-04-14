import SwiftData
import SwiftUI
import UIKit

@main
struct DinkLinkApp: App {
    init() {
        FontDebugger.printAvailableFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            PlayerProfile.self,
            StoredGameSession.self,
            SavedLocation.self,
            SyncQueueItem.self
        ])
    }
}

private enum FontDebugger {
    static func printAvailableFonts() {
        #if DEBUG
        for family in UIFont.familyNames.sorted() {
            let fonts = UIFont.fontNames(forFamilyName: family).sorted()
            guard !fonts.isEmpty else { continue }
            print("FONT FAMILY:", family)
            fonts.forEach { print("  \($0)") }
        }
        #endif
    }
}
