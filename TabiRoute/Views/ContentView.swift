import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                TripListView()
            }
            .tabItem {
                Label("旅ルート", systemImage: "map")
            }

            NavigationStack {
                PackingPlanListView()
            }
            .tabItem {
                Label("持ち物リスト", systemImage: "bag")
            }
        }
    }
}
