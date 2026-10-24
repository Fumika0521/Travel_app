import SwiftUI
import SwiftData

@main
struct TabiRouteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Trip.self)
    }
}
