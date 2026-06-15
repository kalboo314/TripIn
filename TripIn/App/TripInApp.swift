import SwiftUI
import FirebaseCore

@main
struct TripInApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    RootTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
            .task { authViewModel.startObservingAuthState() }
        }
    }
}

/// Bottom tab bar: Home, Search, Agent, Saved.
struct RootTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView(goToSearch: { selection = 1 })
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)
            AgentChatView()
                .tabItem { Label("Agent", systemImage: "sparkles") }
                .tag(2)
            SavedTripsView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .tag(3)
        }
        .tint(Theme.coral)
    }
}
