import SwiftUI

struct SavedTripsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()

    private var userId: String? { authViewModel.currentUser?.id }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.savedTrips.isEmpty {
                    ProgressView("Loading your trips…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.savedTrips.isEmpty {
                    InfoStateView(icon: "wifi.exclamationmark",
                                  title: "Couldn't load trips",
                                  message: error,
                                  tint: Theme.coral,
                                  actionTitle: "Retry",
                                  action: { Task { await load() } })
                } else if viewModel.savedTrips.isEmpty {
                    InfoStateView(icon: "bookmark",
                                  title: "No saved trips yet",
                                  message: "Plan a day and tap Save Trip to keep it here.")
                } else {
                    list
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Saved Trips")
            .onAppear { Task { await load() } }
            .alert("Couldn't delete trip",
                   isPresented: Binding(
                    get: { viewModel.errorMessage != nil && !viewModel.savedTrips.isEmpty },
                    set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.savedTrips) { trip in
                ZStack {
                    SavedTripCard(trip: trip)
                    NavigationLink {
                        ItineraryView(trip: trip, isReadOnly: true)
                    } label: { EmptyView() }
                    .opacity(0)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: Theme.padding, bottom: 6, trailing: Theme.padding))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await delete(trip) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .refreshable { await load() }
    }

    private func load() async {
        guard let userId else { return }
        await viewModel.loadSavedTrips(for: userId)
    }

    private func delete(_ trip: Trip) async {
        guard let userId else { return }
        await viewModel.delete(trip, for: userId)
    }
}

/// Reusable saved-trip card (used here and in the Home carousel).
struct SavedTripCard: View {
    let trip: Trip

    private var stopCount: Int { trip.days.reduce(0) { $0 + $1.slots.count } }
    private var condition: String { trip.days.first?.weather.condition ?? "" }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.coral.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: weatherIcon(condition))
                    .foregroundColor(Theme.coral)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.city).font(.headline).foregroundColor(Theme.navy)
                Text("\(trip.startDate) · \(trip.numberOfDays) day\(trip.numberOfDays > 1 ? "s" : "")")
                    .font(.caption).foregroundColor(.secondary)
                Text("\(stopCount) stops · \(trip.totalTripCost)")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .padding(Theme.padding)
        .background(Theme.card)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private func weatherIcon(_ condition: String) -> String {
        switch condition {
        case "Sunny": return "sun.max.fill"
        case "Rainy": return "cloud.rain.fill"
        case "Snowy": return "snowflake"
        default:       return "cloud.fill"
        }
    }
}

struct SavedTripsView_Previews: PreviewProvider {
    static var previews: some View {
        SavedTripsView().environmentObject(AuthViewModel())
    }
}
