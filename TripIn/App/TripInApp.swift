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

/// Custom container with a floating coral pill tab bar.
struct RootTabView: View {
    @State private var selection = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case 0: HomeView(selectTab: { selection = $0 })
                case 1: SearchView()
                case 2: DiaryView()
                case 3: NearMeView()
                default: SavedTripsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Reserve room so scroll content clears the floating tab bar with margin.
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 96) }

            FloatingTabBar(selection: $selection)
        }
    }
}

/// Floating coral capsule with white icons; selected icon sits on a white circle.
struct FloatingTabBar: View {
    @Binding var selection: Int

    private let items: [(tag: Int, icon: String)] = [
        (0, "house.fill"),
        (1, "magnifyingglass"),
        (2, "book.fill"),
        (3, "location.fill"),
        (4, "bookmark.fill")
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.tag) { item in
                Button {
                    selection = item.tag
                } label: {
                    ZStack {
                        if selection == item.tag {
                            Circle().fill(.white).frame(width: 40, height: 40)
                        }
                        Image(systemName: item.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(selection == item.tag ? Theme.coral : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Theme.coralGradient)
        .clipShape(Capsule())
        .shadow(color: Theme.coral.opacity(0.45), radius: 14, y: 7)
        .padding(.horizontal, 22)
        .padding(.bottom, 6)
    }
}
