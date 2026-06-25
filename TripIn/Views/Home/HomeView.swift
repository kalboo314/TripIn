import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()

    /// Switches the root tab bar (provided by RootTabView).
    var selectTab: (Int) -> Void = { _ in }

    @State private var showProfile = false
    @State private var showAgent = false
    @State private var selectedAttraction: Attraction?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        categoryTiles
                        recommendationsSection
                        savedTripsSection
                    }
                    .padding(.horizontal, Theme.padding)
                    .padding(.top, 8)
                    .padding(.bottom, 90)
                }
                .refreshable { await load() }
            }
            .navigationBarHidden(true)
            .onAppear { Task { await load() } }
            .task { await viewModel.loadRecommended() }
            .sheet(isPresented: $showProfile) {
                ProfileView().environmentObject(authViewModel)
            }
            .sheet(item: $selectedAttraction) { attraction in
                NavigationStack { AttractionDetailView(attraction: attraction) }
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showAgent) {
                AgentChatView().environmentObject(authViewModel)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Hi there" : "Hi, \(name)")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Text(timeGreeting)
                    .font(.largeTitle.bold())
                    .foregroundColor(Theme.navy)
            }
            Spacer()
            Button { showProfile = true } label: { profileAvatar }
        }
    }

    private var profileAvatar: some View {
        ZStack {
            Circle().fill(Theme.coralGradient).frame(width: 44, height: 44)
                .shadow(color: Theme.coral.opacity(0.4), radius: 8, y: 4)
            Text(avatarInitial).font(.headline.bold()).foregroundColor(.white)
        }
    }

    // MARK: - Category tiles

    private var categoryTiles: some View {
        HStack(spacing: 12) {
            categoryTile(icon: "magnifyingglass", title: "Search", tab: 1)
            categoryTile(icon: "camera.fill", title: "Photo", tab: 2)
            categoryTile(icon: "location.fill", title: "Near Me", tab: 3)
            Button { showAgent = true } label: { tileContent(icon: "sparkles", title: "AI Agent") }
                .buttonStyle(.plain)
        }
    }

    private func categoryTile(icon: String, title: String, tab: Int) -> some View {
        Button { selectTab(tab) } label: { tileContent(icon: icon, title: title) }
            .buttonStyle(.plain)
    }

    private func tileContent(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Theme.coral)
                .frame(width: 56, height: 56)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.coral.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            Text(title).font(.caption).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.recommendedCity.isEmpty ? "Recommendations"
                     : "Recommended in \(viewModel.recommendedCity)")
                    .font(.title3.bold()).foregroundColor(Theme.navy)
                Spacer()
                Button { selectTab(1) } label: {
                    Text("See all")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.coral)
                        .padding(.vertical, 6).padding(.leading, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if viewModel.isLoadingRecommended && viewModel.recommendedPlaces.isEmpty {
                ProgressView().tint(Theme.coral).frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if viewModel.recommendedPlaces.isEmpty {
                Text("Couldn't load recommendations right now.")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                ForEach(viewModel.recommendedPlaces) { attraction in
                    Button { selectedAttraction = attraction } label: {
                        AttractionCardView(attraction: attraction)
                            .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Saved trips

    private var savedTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Trips")
                .font(.title3.bold())
                .foregroundColor(Theme.navy)

            if viewModel.isLoading && viewModel.savedTrips.isEmpty {
                ProgressView().tint(Theme.coral).frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if viewModel.savedTrips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: viewModel.errorMessage == nil ? "bookmark" : "wifi.exclamationmark")
                        .font(.title)
                        .foregroundColor(Theme.textSecondary)
                    Text(viewModel.errorMessage ?? "No saved trips yet.\nPlan a day to get started.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.savedTrips) { trip in
                            NavigationLink {
                                ItineraryView(trip: trip, isReadOnly: true)
                            } label: {
                                SavedTripCard(trip: trip).frame(width: 280)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Helpers

    private func load() async {
        guard let uid = authViewModel.currentUser?.id else { return }
        await viewModel.loadSavedTrips(for: uid)
    }

    private var name: String { authViewModel.currentUser?.displayName ?? "" }

    private var avatarInitial: String {
        let email = authViewModel.currentUser?.email ?? ""
        return String(name.first ?? email.first ?? "U").uppercased()
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning!"
        case 12..<17: return "Good afternoon!"
        case 17..<21: return "Good evening!"
        default:       return "Good night!"
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(AuthViewModel())
    }
}
