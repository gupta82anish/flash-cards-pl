import SwiftUI
import SwiftData

@main
struct PolishPairsApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                CardsView()
                    .tabItem { Label("Cards", systemImage: "rectangle.stack") }
                ContentView()
                    .tabItem { Label("Scan", systemImage: "doc.viewfinder") }
            }
        }
        .modelContainer(for: Card.self)
    }
}
