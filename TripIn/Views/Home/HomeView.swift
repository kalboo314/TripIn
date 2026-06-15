import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()

    /// Switches the root tab bar to Search (provided by RootTabView).
    var goToSearch: () -> Void = {}

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.title.bold())
                                .foregroundColor(.white)
                            Text("Let's plan your next adventure.")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, Theme.padding)

                        searchBar

                        savedTripsSection
                    }
                    .padding(.horizontal, Theme.padding)
                }
                .refreshable { await load() }
            }
            .navigationTitle("TripIn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") { authViewModel.signOut() }
                        .tint(Theme.coral)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard let uid = authViewModel.currentUser?.id else { return }
        await viewModel.loadSavedTrips(for: uid)
    }

    private var searchBar: some View {
        Button(action: goToSearch) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                Text("Where do you want to go?").foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Theme.card)
            .cornerRadius(Theme.buttonRadius)
        }
    }

    private var savedTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Trips")
                .font(.headline)
                .foregroundColor(.white)

            if viewModel.isLoading && viewModel.savedTrips.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if viewModel.savedTrips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: viewModel.errorMessage == nil ? "bookmark" : "wifi.exclamationmark")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.5))
                    Text(viewModel.errorMessage ?? "No saved trips yet.\nPlan a day to get started.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.savedTrips) { trip in
                            NavigationLink {
                                ItineraryView(itinerary: trip, isReadOnly: true)
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

    private var greeting: String {
        let name = authViewModel.currentUser?.displayName ?? ""
        return name.isEmpty ? "Welcome 👋" : "Hi, \(name) 👋"
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(AuthViewModel())
    }
}
