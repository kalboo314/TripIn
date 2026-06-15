import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var savedTrips: [ItineraryDay] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func loadSavedTrips(for userId: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            savedTrips = try await FirestoreService.shared.fetchTrips(for: userId)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not load your trips. Please try again."
        }
    }

    func refresh(for userId: String) async {
        await loadSavedTrips(for: userId)
    }

    func delete(_ trip: ItineraryDay, for userId: String) async {
        do {
            try await FirestoreService.shared.deleteTrip(tripId: trip.id, for: userId)
            savedTrips.removeAll { $0.id == trip.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not delete trip. Please try again."
        }
    }
}
